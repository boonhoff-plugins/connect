# frozen_string_literal: true

module PlConnect
  # MentionExtractor
  #
  # Extracts mentions from a message body and turns them into
  # PlConnectChatMentionItem rows.
  #
  # Mentions are produced by the composer as anchor-like spans carrying
  # data attributes, e.g.
  #
  #   <span data-mention-type="user" data-mention-uuid="...">@alice</span>
  #
  # Only these two attributes survive MessageSanitizer, so the extractor can
  # trust the *shape* of the markup — but never the *content*: the uuid is
  # always re-resolved against the database and, for user mentions, against the
  # membership of the conversation. A sender must not be able to make an
  # arbitrary user "mentioned" in a conversation that user is not part of, as
  # that would leak the existence of the conversation through the mention badge.
  module MentionExtractor
    MENTION_TYPES = %w[user role group all].freeze

    # Textual mentions that address everybody in the conversation.
    ALL_KEYWORDS = %w[@all @channel @everyone].freeze

    module_function

    # Parses the body and returns an array of hashes describing the mentions.
    # Does not touch the database except for resolving/validating references.
    #
    # @param html [String] sanitised message body
    # @param chat_item [PlConnectChatItem] conversation the message belongs to
    # @return [Array<Hash>] entries with :f_type and the matching reference keys
    def extract(html:, chat_item:)
      return [] if html.blank? || chat_item.blank?

      fragment = Nokogiri::HTML5.fragment(html.to_s)
      member_uuids = chat_item.active_memberships.pluck(:user_uuid).compact

      mentions = fragment.css("[data-mention-type]").filter_map do |node|
        _build_mention(node: node, member_uuids: member_uuids)
      end

      mentions << { f_type: "all" } if _addresses_everyone?(fragment.text)

      mentions.uniq
    end

    # Persists the extracted mentions for a message.
    #
    # @return [Integer] number of mention rows written
    def persist(c:, message:, chat_item:)
      mentions = extract(html: message.body, chat_item: chat_item)
      return 0 if mentions.empty?

      written = 0

      mentions.each do |mention|
        result = PlConnectChatMentionItem.new.save_element(c: c, element: mention.merge(
          message_id: message.id,
          message_uuid: message.uuid,
          chat_item_uuid: chat_item.uuid,
          tenant_id: chat_item.tenant_id,
          tenant_uuid: chat_item.tenant_uuid
        ))

        if result[:successful]
          written += 1
        else
          # A failed mention must not abort sending the message itself — the
          # message is the payload, the mention is only a notification hint.
          Rails.logger.warn "PlConnect::MentionExtractor: mention not stored (#{result[:successful_text]})"
        end
      end

      written
    end

    # --- internal helpers ----------------------------------------------------

    def _build_mention(node:, member_uuids:)
      type = node["data-mention-type"].to_s
      uuid = node["data-mention-uuid"].to_s
      return nil unless MENTION_TYPES.include?(type)
      return { f_type: "all" } if type == "all"
      return nil if uuid.blank?

      case type
      when "user"
        # Reject mentions of users who are not in this conversation, see the
        # class comment above.
        return nil unless member_uuids.include?(uuid)

        user = User.find_by(uuid: uuid, del_flag: false)
        return nil if user.blank?

        { f_type: "user", mentioned_user_id: user.id, mentioned_user_uuid: user.uuid }
      when "role"
        role = Role.find_by(uuid: uuid, del_flag: false)
        role.present? ? { f_type: "role", mentioned_role_uuid: role.uuid } : nil
      when "group"
        group = Group.find_by(uuid: uuid, del_flag: false)
        group.present? ? { f_type: "group", mentioned_group_uuid: group.uuid } : nil
      end
    end

    def _addresses_everyone?(text)
      downcased = text.to_s.downcase
      ALL_KEYWORDS.any? { |keyword| downcased.include?(keyword) }
    end
  end
end
