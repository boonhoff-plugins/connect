# frozen_string_literal: true

# PlConnectChatChannel
#
# Real time stream of one conversation. A client subscribes with the
# conversation uuid:
#
#   consumer.subscriptions.create({ channel: "PlConnectChatChannel", chat_uuid: "..." })
#
# == Authorization
# Membership is verified at subscribe time with a direct SQL existence check
# and re-verified on every incoming action. Subscribe-time-only checks are not
# enough: a long lived socket would keep streaming after the user was removed
# from the conversation.
#
# The check deliberately does NOT use PlConnectChatItem#member? or
# User#has_role?. Both eventually reach User#check_rights, which runs a series
# of heavy callbacks (set_all_link_item_ids, set_all_documentation_item_ids,
# ...) that are unsafe in ActionCable's threaded context — the subscription
# then fails silently and the client ends up in a reconnect loop. The same
# lesson is documented on EventLogChannel.
#
# == Events sent to the client
# See PlConnect::ChatBroadcaster. All payloads share the envelope
# { event:, chat_uuid:, ... }.
class PlConnectChatChannel < ApplicationCable::Channel
  def subscribed
    chat_uuid = params[:chat_uuid].to_s

    if chat_uuid.present? && member?(chat_uuid)
      @chat_uuid = chat_uuid
      stream_from "pl_connect_chat_#{chat_uuid}"
    else
      reject
    end
  rescue StandardError => e
    Rails.logger.error "PlConnectChatChannel#subscribed: #{e.class}: #{e.message}"
    reject
  end

  def unsubscribed
    # Leaving the conversation view must clear the typing indicator, otherwise
    # a user who closes the tab mid-sentence stays "typing" for everybody else
    # until the next reload.
    broadcast_typing(false)
  end

  # Typing indicator. Deliberately not persisted anywhere: it is worthless a
  # second after it was sent and would otherwise be a continuous record of when
  # someone was writing.
  def typing(data)
    return unless @chat_uuid.present? && member?(@chat_uuid)

    broadcast_typing(data["active"] ? true : false)
  rescue StandardError => e
    Rails.logger.error "PlConnectChatChannel#typing: #{e.class}: #{e.message}"
  end

  private

  def broadcast_typing(active)
    return if @chat_uuid.blank?

    ActionCable.server.broadcast("pl_connect_chat_#{@chat_uuid}", {
      event: "typing",
      chat_uuid: @chat_uuid,
      user_uuid: current_user.uuid,
      user_login: current_user.login,
      active: active
    })
  rescue StandardError => e
    Rails.logger.error "PlConnectChatChannel#broadcast_typing: #{e.class}: #{e.message}"
  end

  # Single joined existence query: is there an active, non-deleted membership
  # of this user in a conversation with that uuid? Returns false for a uuid
  # that does not exist at all, so a caller cannot distinguish "no such
  # conversation" from "not your conversation".
  def member?(chat_uuid)
    PlConnectChatItemJoinUser
      .where(user_id: current_user.id, del_flag: false, left_at: nil)
      .where(
        "pl_connect_chat_item_uuid IN (SELECT uuid FROM pl_connect_chat_items WHERE uuid = ? AND del_flag = ?)",
        chat_uuid, false
      )
      .exists?
  rescue StandardError => e
    Rails.logger.error "PlConnectChatChannel#member?: #{e.class}: #{e.message}"
    false
  end
end
