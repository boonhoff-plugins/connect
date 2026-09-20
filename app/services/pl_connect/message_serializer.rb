# frozen_string_literal: true

module PlConnect
  # MessageSerializer
  #
  # Builds the JSON representation of a message. Used by both the REST feed and
  # the ActionCable broadcast so the client only ever has to understand one
  # shape and can reuse the same render function for both.
  #
  # Everything that is not the already sanitised `body` is emitted as raw text
  # and must be inserted client side via textContent, never innerHTML.
  module MessageSerializer
    module_function

    # @param message [PlConnectChatMessageItem]
    # @param viewer [User, nil] the user the payload is rendered for; used to
    #   mark own messages and own reactions without a second round trip
    def as_json(message:, viewer: nil)
      {
        id: message.id,
        uuid: message.uuid,
        f_type: message.f_type,
        chat_uuid: message.chat_item_uuid,
        parent_uuid: message.parent_uuid,
        reply_to_uuid: message.reply_to_uuid,
        sender_uuid: message.sender_user_uuid,
        sender_login: message.sender&.login,
        own: viewer.present? && message.sender_user_id == viewer.id,
        body: message.body.to_s,
        body_plain: message.body_plain.to_s,
        sent_at: message.sent_at&.iso8601,
        edited_at: message.edited_at&.iso8601,
        thread_reply_count: message.thread_reply_count.to_i,
        attachment_count: message.attachment_count.to_i,
        system_event_key: message.system_event_key,
        system_event_data: message.system_message? ? message.system_event_data : nil,
        call_uuid: message.call_item_uuid,
        reactions: reactions_json(message: message, viewer: viewer),
        attachments: attachments_json(message: message)
      }
    end

    # Reactions collapsed per emoji so the client can render "👍 3" directly.
    def reactions_json(message:, viewer: nil)
      message.reactions.group_by(&:emoji).map do |emoji, rows|
        {
          emoji: emoji,
          count: rows.size,
          user_uuids: rows.map(&:user_uuid),
          reacted: viewer.present? && rows.any? { |row| row.user_uuid == viewer.uuid }
        }
      end
    end

    def attachments_json(message:)
      message.attachments.map do |attachment|
        {
          uuid: attachment.uuid,
          f_type: attachment.f_type,
          file_name: attachment.file_name.to_s,
          content_type: attachment.content_type.to_s,
          byte_size: attachment.byte_size.to_i,
          human_size: attachment.human_byte_size,
          width: attachment.width,
          height: attachment.height,
          inline: attachment.inline_renderable?
        }
      end
    end

    # Sidebar entry for one conversation, rendered from the viewer's
    # perspective (title, unread counter and pin state are per member).
    def conversation_as_json(chat:, viewer:, membership: nil)
      membership ||= chat.membership_for(viewer)

      {
        uuid: chat.uuid,
        f_type: chat.f_type,
        title: chat.display_title_for(viewer),
        last_message_at: chat.last_message_at&.iso8601,
        last_message_preview: chat.last_message_preview.to_s,
        last_message_user_uuid: chat.last_message_user_uuid,
        message_count: chat.message_count.to_i,
        archived: chat.archived?,
        read_only: chat.read_only?,
        call_active: chat.call_active?,
        unread_count: membership&.unread_count.to_i,
        pinned: membership&.pinned ? true : false,
        muted: membership&.muted? ? true : false,
        notification_level: membership&.notification_level,
        membership_role: membership&.membership_role,
        partner_uuid: chat.f_type == "direct" ? chat.partner_for(viewer)&.uuid : nil
      }
    end
  end
end
