# frozen_string_literal: true

module PlConnect
  # ConversationResolver
  #
  # Central read gate for conversations. Every controller, channel and service
  # that turns a client supplied uuid into a PlConnectChatItem must go through
  # here.
  #
  # == Why not UserVisibilityConcern#visible_to_user
  # That concern treats a record without any join rows as public — the right
  # default for a navigation link, and exactly the wrong one for a private
  # conversation. A single conversation that lost its membership rows would
  # become readable by everybody. Access here is therefore always an explicit,
  # positive membership check.
  class ConversationResolver
    def initialize(c:, user:)
      @c = c
      @user = user
    end

    # Resolves a uuid to a conversation the user is an active member of.
    # Returns nil for "does not exist" and for "exists but you are not a
    # member" alike — the caller must not be able to tell the two apart, since
    # that would confirm the existence of a foreign conversation.
    def find(uuid)
      return nil if uuid.blank? || @user.blank?

      PlConnectChatItem.for_user(@user).find_by(uuid: uuid)
    end

    # Sidebar list. `archived` selects between the normal list and the archive.
    def list(archived: false, limit: 200)
      scope = PlConnectChatItem.for_user(@user)
      scope = archived ? scope.where.not(archived_at: nil) : scope.where(archived_at: nil)
      scope.ordered_for_sidebar.limit(limit)
    end

    # Opens (or creates) the 1:1 conversation with another user.
    #
    # The partner is looked up by uuid and must be an active, non-deleted user
    # of the same tenant. Cross tenant chats are rejected: tenants are the
    # isolation boundary of this application, and a chat crossing it would
    # leak the existence of users of another tenant.
    def open_direct(partner_uuid:)
      return _failure("User not found.") if partner_uuid.blank?

      partner = User.find_by(uuid: partner_uuid, del_flag: false, active: true)
      return _failure("User not found.") if partner.blank?
      return _failure("User not found.") unless _same_tenant?(partner)
      return _failure("You cannot start a chat with yourself.") if partner.id == @user.id

      PlConnectChatItem.find_or_create_direct(c: @c, user_a: @user, user_b: partner)
    end

    # Creates a group conversation with the given members. The creator always
    # becomes owner and is added regardless of the member list.
    def create_group(title:, member_uuids: [])
      clean_title = title.to_s.strip
      return _failure("A title is required.") if clean_title.blank?

      members = _resolve_members(member_uuids)

      result = PlConnectChatItem.new.save_element(c: @c, element: {
        f_type: "group",
        state: "active",
        name: "group_#{SecureRandom.hex(8)}",
        title: clean_title,
        tenant_id: @user.tenant_id,
        message_count: 0
      })
      return result unless result[:successful]

      chat = result[:element]

      chat.add_member(c: @c, user: @user, membership_role: "owner")
      members.each { |member| chat.add_member(c: @c, user: member, membership_role: "member") }

      result
    end

    # Candidate users for starting a chat or adding to a group. Restricted to
    # the caller's tenant and never returns more than `limit` rows, so the
    # endpoint cannot be used to enumerate the whole user table.
    def searchable_users(term:, limit: 20)
      scope = User.where(del_flag: false, active: true).where.not(id: @user.id)
      scope = scope.where(tenant_id: @user.tenant_id) if @user.tenant_id.present?

      clean_term = term.to_s.strip
      if clean_term.present?
        # LIKE with an escaped, bound pattern — portable across MySQL,
        # PostgreSQL and SQLite, unlike ILIKE or REGEXP.
        pattern = "%#{_escape_like(clean_term)}%"
        scope = scope.where("LOWER(login) LIKE LOWER(:p) OR LOWER(email) LIKE LOWER(:p)", p: pattern)
      end

      scope.order(:login).limit(limit)
    end

    # Resolves a uuid to a user this account may add to a call/conversation -
    # active, non-deleted, same tenant, not the caller. Unlike #find_by-through-
    # membership lookups, this deliberately does NOT require the candidate to
    # already be a member of anything - it is the safe resolution path for
    # CallService#invite's tenant-wide "ring in a colleague" search, where the
    # whole point is that the target is not a member yet.
    def find_addable_user(uuid:)
      return nil if uuid.blank?

      candidate = User.find_by(uuid: uuid, del_flag: false, active: true)
      return nil if candidate.blank? || candidate.id == @user.id
      return nil unless _same_tenant?(candidate)

      candidate
    end

    private

    def _resolve_members(member_uuids)
      uuids = Array(member_uuids).map(&:to_s).reject(&:blank?).uniq
      return [] if uuids.empty?

      scope = User.where(uuid: uuids, del_flag: false, active: true).where.not(id: @user.id)
      scope = scope.where(tenant_id: @user.tenant_id) if @user.tenant_id.present?
      scope.to_a
    end

    def _same_tenant?(partner)
      return true if @user.tenant_id.blank?

      partner.tenant_id == @user.tenant_id
    end

    # Neutralises the LIKE wildcards so a search term of "%" does not turn into
    # "match everything".
    def _escape_like(term)
      term.gsub("\\", "\\\\\\\\").gsub("%", "\\%").gsub("_", "\\_")
    end

    def _failure(text)
      { successful: false, successful_text: text, element: nil }
    end
  end
end
