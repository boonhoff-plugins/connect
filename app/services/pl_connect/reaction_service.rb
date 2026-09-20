# frozen_string_literal: true

module PlConnect
  # ReactionService
  #
  # Toggles emoji reactions on a message.
  #
  # == Why un-reacting hard-deletes
  # Reactions are toggled far more often than any other record in this plugin —
  # a single message can collect dozens of clicks. Every save_element writes a
  # row into pl_connect_chat_reaction_item_histories, so soft-deleting via
  # del_flag would fill the history table with noise that has no audit value.
  # Removing a reaction therefore calls destroy. Adding one still goes through
  # save_element, so the normal uuid/tenant/creator handling applies.
  class ReactionService
    # Upper bound for the stored emoji. Long enough for ZWJ sequences and skin
    # tone modifiers, short enough that the field cannot be abused to store
    # arbitrary text (which would then be rendered next to the message).
    MAX_EMOJI_LENGTH = PlConnectChatReactionItem::MAX_EMOJI_LENGTH

    def initialize(c:, user:)
      @c = c
      @user = user
    end

    # Adds the reaction if the user has not used this emoji on the message yet,
    # removes it otherwise.
    #
    # @return [Hash] save_element style result; :element is the message
    def toggle(chat_item:, message:, emoji:)
      return _failure("Conversation not found.") if chat_item.blank?
      return _failure("Message not found.") if message.blank?
      return _failure("You are not a member of this conversation.") unless chat_item.member?(@user)

      clean_emoji = _clean(emoji)
      return _failure("Invalid reaction.") if clean_emoji.blank?

      existing = PlConnectChatReactionItem.find_by(
        message_uuid: message.uuid,
        user_uuid: @user.uuid,
        emoji: clean_emoji
      )

      if existing.present?
        existing.destroy
      else
        result = PlConnectChatReactionItem.new.save_element(c: @c, element: {
          message_id: message.id,
          message_uuid: message.uuid,
          chat_item_uuid: chat_item.uuid,
          user_id: @user.id,
          user_uuid: @user.uuid,
          emoji: clean_emoji,
          tenant_id: chat_item.tenant_id,
          tenant_uuid: chat_item.tenant_uuid
        })
        return result unless result[:successful]
      end

      message.reload
      ChatBroadcaster.reaction_changed(chat_item: chat_item, message: message)

      { successful: true, successful_text: nil, element: message }
    rescue StandardError => e
      Rails.logger.error "PlConnect::ReactionService#toggle: #{e.class}: #{e.message}"
      _failure("The reaction could not be saved.")
    end

    private

    # Strips whitespace and anything that is not a single short grapheme
    # cluster sequence. The value is rendered back into the DOM, so nothing
    # that could carry markup may pass.
    def _clean(emoji)
      value = emoji.to_s.strip
      return nil if value.blank? || value.length > MAX_EMOJI_LENGTH
      return nil if value.match?(/[<>&"'\\]/)
      return nil if value.match?(/\A[[:alnum:][:space:]]+\z/)

      value
    end

    def _failure(text)
      { successful: false, successful_text: text, element: nil }
    end
  end
end
