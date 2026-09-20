# frozen_string_literal: true

# PlConnectPresenceChannel
#
# Per-user notification and presence stream. Every logged in user subscribes
# exactly once, to their own stream:
#
#   "pl_connect_user_<user uuid>"
#
# == What it is for
#   * heartbeat for PlConnect::PresenceService (online/away/busy)
#   * events that are not tied to one open conversation: a new message in a
#     conversation the user is currently not looking at, a mention, an
#     incoming call
#
# == Authorization
# The stream name is derived from current_user on the server. A client cannot
# pass a uuid, so it is impossible to subscribe to somebody else's stream.
class PlConnectPresenceChannel < ApplicationCable::Channel
  def subscribed
    stream_from self.class.stream_name_for(current_user.uuid)
    PlConnect::PresenceService.touch(user: current_user) if PlConnect::PresenceService.active?
  rescue StandardError => e
    Rails.logger.error "PlConnectPresenceChannel#subscribed: #{e.class}: #{e.message}"
    reject
  end

  def unsubscribed
    PlConnect::PresenceService.clear(user: current_user)
  rescue StandardError => e
    Rails.logger.error "PlConnectPresenceChannel#unsubscribed: #{e.class}: #{e.message}"
  end

  # Periodic heartbeat from the client. Refreshes the cache TTL; if the client
  # stops sending it, the entry expires on its own and the user goes offline.
  def heartbeat(data)
    return unless PlConnect::PresenceService.active?

    PlConnect::PresenceService.touch(user: current_user, state: data["state"].to_s.presence || "online")
  rescue StandardError => e
    Rails.logger.error "PlConnectPresenceChannel#heartbeat: #{e.class}: #{e.message}"
  end

  def self.stream_name_for(user_uuid)
    "pl_connect_user_#{user_uuid}"
  end

  # Pushes an event to one specific user, regardless of which conversation they
  # currently have open. Used for sidebar badges, mentions and call invites.
  def self.notify(user_uuid:, event:, payload: {})
    return if user_uuid.blank?

    ActionCable.server.broadcast(stream_name_for(user_uuid), { event: event }.merge(payload))
  rescue StandardError => e
    Rails.logger.error "PlConnectPresenceChannel.notify(#{event}): #{e.class}: #{e.message}"
  end
end
