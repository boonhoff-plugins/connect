# frozen_string_literal: true

module PlConnect
  # ChatBroadcaster
  #
  # Every real time event of the chat leaves the server through this module.
  # Keeping the payload construction in one place means the client only has to
  # implement one envelope:
  #
  #   { event: "message.created", chat_uuid: "...", ...event specific keys }
  #
  # == Why ActionCable.server.broadcast and not Turbo Streams
  # Turbo Streams push rendered HTML for a fixed DOM target. The chat needs the
  # same event to be handled differently depending on what the receiving client
  # is currently showing (open conversation → append; other conversation →
  # only raise the sidebar badge). That decision can only be made on the
  # client, so the server sends data and the client renders.
  #
  # == Fan-out
  # Broadcasting is fire and forget. If ActionCable is unavailable the rescue
  # swallows the error: a failed broadcast must never roll back a message that
  # was already persisted — the client would recover it on the next feed load.
  module ChatBroadcaster
    module_function

    def message_created(chat_item:, message:)
      _publish(chat_item, "message.created", message: MessageSerializer.as_json(message: message))
    end

    def message_updated(chat_item:, message:)
      _publish(chat_item, "message.updated", message: MessageSerializer.as_json(message: message))
    end

    # A deleted message is announced by uuid only. Sending the body again would
    # push content to clients that the user just asked to remove.
    def message_deleted(chat_item:, message:)
      _publish(chat_item, "message.deleted", message_uuid: message.uuid, parent_uuid: message.parent_uuid)
    end

    def reaction_changed(chat_item:, message:)
      _publish(chat_item, "reaction.changed",
               message_uuid: message.uuid,
               reactions: MessageSerializer.reactions_json(message: message))
    end

    # Typing indicators are pure signalling and are never persisted.
    def typing(chat_item:, user:, active:)
      _publish(chat_item, "typing", user_uuid: user.uuid, user_login: user.login, active: active ? true : false)
    end

    # Announces that a member moved their read marker, so other clients can
    # show read receipts.
    def read(chat_item:, user:, message_uuid:, read_at:)
      _publish(chat_item, "read", user_uuid: user.uuid, message_uuid: message_uuid, read_at: read_at&.iso8601)
    end

    def member_changed(chat_item:, user:, action:)
      _publish(chat_item, "member.changed", user_uuid: user.uuid, user_login: user.login, action: action)
    end

    def call_state(chat_item:, call_item:, action:, extra: {})
      _publish(chat_item, "call.#{action}", {
        call_uuid: call_item&.uuid,
        room_key: call_item&.room_key,
        state: call_item&.state
      }.merge(extra))
    end

    def _publish(chat_item, event, payload = {})
      return if chat_item.blank?

      ActionCable.server.broadcast(
        chat_item.stream_name,
        { event: event, chat_uuid: chat_item.uuid }.merge(payload)
      )
    rescue StandardError => e
      Rails.logger.error "PlConnect::ChatBroadcaster(#{event}): #{e.class}: #{e.message}"
    end
  end
end
