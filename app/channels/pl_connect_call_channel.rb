# frozen_string_literal: true

# PlConnectCallChannel
#
# Real time signalling for one call. A client subscribes once it has already
# been accepted into the call (see PlConnect::CallService#start/#accept):
#
#   consumer.subscriptions.create({ channel: "PlConnectCallChannel", call_uuid: "..." })
#
# == What this channel is (and is not) for
# Only WebRTC signalling and its accompanying presence events (peer joined /
# peer left) travel here. It never writes to the database — see
# PlConnect::CallService#update_media_state for why persisted state changes go
# through the REST API instead, where a properly built controller context
# (`c`) is available. This mirrors PlConnectChatChannel, which does not persist
# the typing indicator either.
#
# == Authorization
# Membership is re-derived on every subscribe with a direct SQL existence
# check against pl_connect_call_item_join_users - never through
# PlConnectCallItem#member?-style helpers that might reach User#check_rights.
# See PlConnectChatChannel for the full rationale (unsafe callbacks in
# ActionCable's threaded context).
#
# == Addressing
# A call can have more than two participants (see PlConnect::CallService and
# PlConnectCallItem::MESH_PARTICIPANT_LIMIT), so "signal" messages carry an
# optional target_user_uuid identifying which single peer an SDP offer/answer
# or ICE candidate is meant for - every event is still broadcast to the whole
# room (ActionCable has no per-subscriber addressing), the client simply
# ignores anything not addressed to its own uuid. "peer-joined"/"peer-left"
# have no target_user_uuid: they are meant for everyone already in the room.
#
# == Events sent to the client
#   { event: "peer-joined", call_uuid:, user_uuid: }
#   { event: "peer-left",   call_uuid:, user_uuid: }
#   { event: "signal",      call_uuid:, user_uuid:, target_user_uuid:, type:, data: }
#   { event: "media_state", call_uuid:, user_uuid:, audio_active:, video_active:, screen_active: }
#     (media_state is broadcast from PlConnect::CallService#update_media_state,
#     not from this channel - see above)
class PlConnectCallChannel < ApplicationCable::Channel
  def subscribed
    call = _resolve(params[:call_uuid].to_s)

    if call.present?
      @call_item = call
      stream_from @call_item.stream_name
      _broadcast(event: "peer-joined", user_uuid: current_user.uuid)
    else
      reject
    end
  rescue StandardError => e
    Rails.logger.error "PlConnectCallChannel#subscribed: #{e.class}: #{e.message}"
    reject
  end

  def unsubscribed
    return if @call_item.blank?

    _broadcast(event: "peer-left", user_uuid: current_user.uuid)
  rescue StandardError => e
    Rails.logger.error "PlConnectCallChannel#unsubscribed: #{e.class}: #{e.message}"
  end

  # Relays one piece of WebRTC signalling data (SDP offer/answer or an ICE
  # candidate) to a single specific peer. The payload is opaque to the server
  # - it is never inspected or stored, only forwarded.
  #
  # data: { "type" => "offer"|"answer"|"ice-candidate", "target_user_uuid" => "...", "data" => <opaque JSON> }
  def signal(data)
    return if @call_item.blank?

    _broadcast(
      event: "signal",
      user_uuid: current_user.uuid,
      target_user_uuid: data["target_user_uuid"].to_s.presence,
      type: data["type"].to_s,
      data: data["data"]
    )
  rescue StandardError => e
    Rails.logger.error "PlConnectCallChannel#signal: #{e.class}: #{e.message}"
  end

  private

  # Single joined existence query: does the current user have a non-deleted
  # participant row for a call with that uuid? Returns false (not "reject with
  # a reason") for a uuid that does not exist at all, so this cannot be used to
  # probe which call uuids are valid.
  def _resolve(call_uuid)
    return nil if call_uuid.blank?

    PlConnectCallItem
      .joins(:pl_connect_call_item_join_users)
      .where(uuid: call_uuid, del_flag: false)
      .where(pl_connect_call_item_join_users: { user_id: current_user.id, del_flag: false })
      .first
  end

  def _broadcast(payload)
    ActionCable.server.broadcast(@call_item.stream_name, { call_uuid: @call_item.uuid }.merge(payload))
  rescue StandardError => e
    Rails.logger.error "PlConnectCallChannel#_broadcast: #{e.class}: #{e.message}"
  end
end
