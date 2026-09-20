# frozen_string_literal: true

module PlConnect
  # ReadStateService
  #
  # Owns the per-member read position of a conversation.
  #
  # The read state lives on the membership row
  # (PlConnectChatItemJoinUser#last_read_message_uuid / #last_read_at /
  # #unread_count) rather than in a separate read-receipt table. A chat
  # produces one read event per member per visit, so a dedicated table would
  # grow as fast as the message table itself while only ever being queried for
  # its newest row per member.
  #
  # Writes go through update_all rather than save_element on purpose: these are
  # pure counters with no business logic and no audit value, and a history row
  # per read event would dwarf the history of the actual content.
  class ReadStateService
    def initialize(c:, user:)
      @c = c
      @user = user
    end

    # Marks everything up to and including `message_uuid` as read.
    # Without a uuid the whole conversation is marked as read.
    def mark_read(chat_item:, message_uuid: nil)
      return _failure("Conversation not found.") if chat_item.blank?

      membership = chat_item.membership_for(@user)
      return _failure("You are not a member of this conversation.") if membership.blank?

      message = _resolve_message(chat_item, message_uuid) || PlConnectChatMessageItem.for_chat(chat_item.id).last
      read_at = Time.current

      PlConnectChatItemJoinUser.where(id: membership.id).update_all(
        last_read_message_uuid: message&.uuid,
        last_read_at: read_at,
        unread_count: _remaining_unread(chat_item, message),
        updated_at: read_at
      )

      _mark_mentions_read(chat_item: chat_item, until_message: message, read_at: read_at)
      ChatBroadcaster.read(chat_item: chat_item, user: @user, message_uuid: message&.uuid, read_at: read_at)

      { successful: true, successful_text: nil, element: membership.reload }
    rescue StandardError => e
      Rails.logger.error "PlConnect::ReadStateService#mark_read: #{e.class}: #{e.message}"
      _failure("The read state could not be saved.")
    end

    # Total unread messages across all conversations — drives the badge in the
    # main navigation.
    def total_unread
      PlConnectChatItemJoinUser
        .where(user_id: @user.id, del_flag: false, left_at: nil)
        .sum(:unread_count)
        .to_i
    end

    def unread_mentions
      PlConnectChatMentionItem.unread_for_user(@user).count
    end

    # Read receipts of one message: who has read at least up to it.
    # Only used for small conversations; the client hides it above a threshold.
    def readers_of(chat_item:, message:)
      return [] if chat_item.blank? || message.blank? || message.sent_at.blank?

      chat_item.active_memberships
               .where.not(user_id: message.sender_user_id)
               .where("last_read_at >= ?", message.sent_at)
               .includes(:user)
               .filter_map { |membership| membership.user&.uuid }
    end

    private

    def _resolve_message(chat_item, uuid)
      return nil if uuid.blank?

      PlConnectChatMessageItem.find_by(uuid: uuid, chat_item_id: chat_item.id, del_flag: false)
    end

    # Messages after the read marker that were not written by the reader.
    # Recomputed instead of decremented, so a lost broadcast or a race can
    # never leave a permanently wrong badge.
    def _remaining_unread(chat_item, message)
      scope = PlConnectChatMessageItem
              .where(chat_item_id: chat_item.id, del_flag: false)
              .where.not(sender_user_id: @user.id)

      scope = scope.where("sent_at > ?", message.sent_at) if message&.sent_at.present?
      scope.count
    end

    def _mark_mentions_read(chat_item:, until_message:, read_at:)
      scope = PlConnectChatMentionItem
              .where(chat_item_uuid: chat_item.uuid, mentioned_user_id: @user.id, read_at: nil, del_flag: false)

      if until_message&.sent_at.present?
        scope = scope.where(
          message_uuid: PlConnectChatMessageItem
            .where(chat_item_id: chat_item.id)
            .where(sent_at: ..until_message.sent_at)
            .select(:uuid)
        )
      end

      scope.update_all(read_at: read_at, updated_at: read_at)
    end

    def _failure(text)
      { successful: false, successful_text: text, element: nil }
    end
  end
end
