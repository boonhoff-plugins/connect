# frozen_string_literal: true

module PlConnect
  # MessageComposer
  #
  # The single write path for chat messages. Controllers and background jobs
  # must go through here instead of calling save_element on
  # PlConnectChatMessageItem directly, because sending a message is never just
  # one insert — it also has to:
  #
  #   1. verify the sender is an active member and may post
  #   2. sanitise the body (see MessageSanitizer)
  #   3. extract and persist mentions
  #   4. maintain the denormalised conversation counters used by the sidebar
  #   5. raise the unread counter of every *other* member
  #   6. broadcast the result to the conversation stream
  #
  # Steps 4 and 5 are deliberately denormalised: the sidebar is rendered on
  # every page load and must not run an aggregate over the whole message table.
  #
  # Every public method returns a save_element style result hash
  # ({ successful:, successful_text:, element: }) so callers can treat it like
  # any other model write in this codebase.
  class MessageComposer
    def initialize(c:, chat_item:, user:)
      @c = c
      @chat_item = chat_item
      @user = user
    end

    # Creates a normal user message.
    #
    # @param body [String] raw HTML from the composer
    # @param parent_uuid [String, nil] uuid of the message opening the thread
    # @param reply_to_uuid [String, nil] uuid of a quoted message
    def create(body:, parent_uuid: nil, reply_to_uuid: nil)
      return _failure("Conversation not found.") if @chat_item.blank?
      return _failure("You are not a member of this conversation.") unless @chat_item.member?(@user)
      return _failure("This conversation is read only.") unless @chat_item.may_post?(@user)

      clean_body = MessageSanitizer.clean(body)
      plain = MessageSanitizer.to_plain_text(clean_body)
      return _failure("The message is empty.") if plain.blank?

      parent = _resolve_sibling(parent_uuid)
      reply_to = _resolve_sibling(reply_to_uuid)

      result = PlConnectChatMessageItem.new.save_element(c: @c, element: _base_attributes.merge(
        f_type: "message",
        body: clean_body,
        body_plain: plain,
        parent_id: parent&.id,
        parent_uuid: parent&.uuid,
        reply_to_id: reply_to&.id,
        reply_to_uuid: reply_to&.uuid
      ))
      return result unless result[:successful]

      message = result[:element]

      MentionExtractor.persist(c: @c, message: message, chat_item: @chat_item)
      _bump_thread_counter(parent)
      _touch_conversation(message)
      _raise_unread_counters(message)
      ChatBroadcaster.message_created(chat_item: @chat_item, message: message)
      _notify_members(message)

      result
    rescue StandardError => e
      _handle_exception(e, "create")
    end

    # Writes a system message ("X joined", "call started", ...). System
    # messages carry no user body; the client renders them from the event key
    # so the text follows each reader's locale.
    #
    # @param event_key [String] stable key, e.g. "member.joined"
    # @param payload [Hash] data needed to render the sentence
    def create_system(event_key:, payload: {}, call_item_uuid: nil)
      return _failure("Conversation not found.") if @chat_item.blank?

      result = PlConnectChatMessageItem.new.save_element(c: @c, element: _base_attributes.merge(
        f_type: call_item_uuid.present? ? "call_event" : "system",
        system_event_key: event_key,
        system_event_payload: payload.to_json,
        call_item_uuid: call_item_uuid,
        body: nil,
        body_plain: nil
      ))
      return result unless result[:successful]

      message = result[:element]
      _touch_conversation(message)
      ChatBroadcaster.message_created(chat_item: @chat_item, message: message)

      result
    rescue StandardError => e
      _handle_exception(e, "create_system")
    end

    # Edits an existing message. Only the author may edit, and only real user
    # messages — system and call events are an audit trail and stay immutable.
    def update(message:, body:)
      return _failure("Message not found.") if message.blank?
      return _failure("You may only edit your own messages.") unless message.sender_user_id == @user.id
      return _failure("System messages cannot be edited.") unless message.f_type == "message"

      clean_body = MessageSanitizer.clean(body)
      plain = MessageSanitizer.to_plain_text(clean_body)
      return _failure("The message is empty.") if plain.blank?

      result = message.save_element(c: @c, element: {
        body: clean_body,
        body_plain: plain,
        edited_at: Time.current
      })
      return result unless result[:successful]

      updated = result[:element]

      # Mentions are re-derived from scratch: an edit can add new ones and drop
      # existing ones, and reconciling both directions is more error prone than
      # replacing the small set outright.
      PlConnectChatMentionItem.where(message_id: updated.id).destroy_all
      MentionExtractor.persist(c: @c, message: updated, chat_item: @chat_item)

      _refresh_preview_if_last(updated)
      ChatBroadcaster.message_updated(chat_item: @chat_item, message: updated)

      result
    rescue StandardError => e
      _handle_exception(e, "update")
    end

    # Soft-deletes a message. The row is kept so thread structure and the
    # history trail survive; the client renders a tombstone.
    #
    # Authors may delete their own messages, owners and moderators may delete
    # any message in the conversation (moderation).
    def destroy(message:)
      return _failure("Message not found.") if message.blank?
      return _failure("You may not delete this message.") unless _may_delete?(message)

      result = message.save_element(c: @c, element: { del_flag: true, state: "deleted" })
      return result unless result[:successful]

      _bump_thread_counter(message.parent_uuid.present? ? _resolve_sibling(message.parent_uuid) : nil)
      _recount_conversation
      ChatBroadcaster.message_deleted(chat_item: @chat_item, message: result[:element])

      result
    rescue StandardError => e
      _handle_exception(e, "destroy")
    end

    private

    def _base_attributes
      {
        chat_item_id: @chat_item.id,
        chat_item_uuid: @chat_item.uuid,
        sender_user_id: @user&.id,
        sender_user_uuid: @user&.uuid,
        sent_at: Time.current,
        state: "sent",
        tenant_id: @chat_item.tenant_id,
        tenant_uuid: @chat_item.tenant_uuid,
        extension_item_id: @chat_item.extension_item_id,
        extension_item_uuid: @chat_item.extension_item_uuid
      }
    end

    # Resolves a uuid coming from the client to a message *inside this
    # conversation*. Scoping by chat_item_id is the security relevant part: it
    # prevents threading a reply onto a message of a foreign conversation,
    # which would otherwise expose that message's uuid as a valid parent.
    def _resolve_sibling(uuid)
      return nil if uuid.blank?

      PlConnectChatMessageItem.find_by(uuid: uuid, chat_item_id: @chat_item.id, del_flag: false)
    end

    # Authors may always delete their own messages.
    #
    # Owners and moderators may additionally delete foreign messages, but only
    # in group conversations, teams and channels — that is moderation of a
    # shared space. A direct chat is explicitly excluded: both participants are
    # created as "owner" there, so without this guard either side could delete
    # the other's messages from a private one-to-one conversation.
    def _may_delete?(message)
      return true if message.sender_user_id == @user.id
      return false if @chat_item.f_type == "direct"

      membership = @chat_item.membership_for(@user)
      membership.present? && %w[owner moderator].include?(membership.membership_role)
    end

    # Keeps the denormalised sidebar fields in sync with the newest message.
    def _touch_conversation(message)
      @chat_item.save_element(c: @c, element: {
        last_message_at: message.sent_at,
        last_message_preview: MessageSanitizer.preview(message.body).presence || message.system_event_key.to_s,
        last_message_user_uuid: message.sender_user_uuid,
        message_count: PlConnectChatMessageItem.where(chat_item_id: @chat_item.id, del_flag: false).count
      })
    end

    # After a delete the preview may point at a message that no longer exists.
    def _recount_conversation
      newest = PlConnectChatMessageItem.for_chat(@chat_item.id).last

      @chat_item.save_element(c: @c, element: {
        last_message_at: newest&.sent_at,
        last_message_preview: newest ? MessageSanitizer.preview(newest.body) : "",
        last_message_user_uuid: newest&.sender_user_uuid,
        message_count: PlConnectChatMessageItem.where(chat_item_id: @chat_item.id, del_flag: false).count
      })
    end

    def _refresh_preview_if_last(message)
      return unless @chat_item.last_message_at.present? && message.sent_at.present?
      return unless message.sent_at >= @chat_item.last_message_at

      @chat_item.save_element(c: @c, element: { last_message_preview: MessageSanitizer.preview(message.body) })
    end

    def _bump_thread_counter(parent)
      return if parent.blank?

      parent.save_element(c: @c, element: {
        thread_reply_count: PlConnectChatMessageItem.where(parent_id: parent.id, del_flag: false).count
      })
    end

    # Raises unread_count for everybody except the sender.
    #
    # Uses a single UPDATE instead of save_element on each membership on
    # purpose: this runs on every message, the columns touched are pure
    # counters with no business logic attached, and writing a history row per
    # member per message would grow the history table by O(members × messages).
    # The statement is written with bind parameters only, so it stays portable
    # across MySQL, PostgreSQL and SQLite.
    def _raise_unread_counters(message)
      return if message.sender_user_id.blank?

      PlConnectChatItemJoinUser
        .where(pl_connect_chat_item_id: @chat_item.id, del_flag: false, left_at: nil)
        .where.not(user_id: message.sender_user_id)
        .update_all("unread_count = COALESCE(unread_count, 0) + 1")
    end

    def _failure(text)
      { successful: false, successful_text: text, element: nil }
    end

    # Pushes a sidebar hint to every other member's personal stream.
    #
    # This is what makes the unread badge appear for members who are logged in
    # but currently looking at a different conversation — they are not
    # subscribed to this conversation's stream, so the ChatBroadcaster event
    # above never reaches them. Only the preview is sent, never the full body:
    # the client fetches the message itself once the conversation is opened,
    # and a user who has muted the conversation should not receive its content
    # pushed to them.
    def _notify_members(message)
      recipients = @chat_item.active_memberships.where.not(user_id: message.sender_user_id)

      recipients.find_each do |membership|
        next if membership.user_uuid.blank?

        PlConnectPresenceChannel.notify(
          user_uuid: membership.user_uuid,
          event: "conversation.activity",
          payload: {
            chat_uuid: @chat_item.uuid,
            title: @chat_item.title.to_s,
            preview: membership.muted? ? "" : MessageSanitizer.preview(message.body, limit: 120),
            sender_login: @user&.login,
            unread_count: membership.reload.unread_count.to_i,
            muted: membership.muted?
          }
        )
      end
    rescue StandardError => e
      Rails.logger.error "PlConnect::MessageComposer#_notify_members: #{e.class}: #{e.message}"
    end

    # Message bodies may contain personal data, so the exception is logged with
    # its class and message only — never with the payload (GDPR Art. 5 (1) c).
    def _handle_exception(error, context)
      Rails.logger.error "PlConnect::MessageComposer##{context}: #{error.class}: #{error.message}"
      _failure("The message could not be processed.")
    end
  end
end
