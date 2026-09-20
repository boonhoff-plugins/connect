# frozen_string_literal: true

# PlConnectChatItem
#
# A conversation. Four shapes are distinguished via `f_type`:
#   * "team"    — top level container, holds channels as children (parent_id)
#   * "channel" — a channel inside a team
#   * "group"   — an ad-hoc group chat with an explicit member list
#   * "direct"  — a 1:1 chat between exactly two users
#
# Visibility and membership both run through pl_connect_chat_item_join_users.
# IMPORTANT: unlike LinkItem, a conversation without any join rows is NOT
# public. Access is always an explicit membership, which is why the read paths
# use `for_user` / `member?` and never UserVisibilityConcern#visible_to_user.
class PlConnectChatItem < ApplicationRecord
  include UserVisibilityConcern
  include AssociationOriginalModelConcern

  # Provides the has_many :pl_connect_chat_item_join_users/groups/roles/tenants
  # associations plus the :users/:groups/:roles/:tenants through associations.
  configure_user_visibility

  F_TYPES = %w[team channel group direct].freeze
  STATES  = %w[active archived].freeze

  # Membership roles, ordered from most to least privileged.
  MEMBERSHIP_ROLES = %w[owner moderator member guest].freeze

  # Notification levels a member can choose per conversation.
  NOTIFICATION_LEVELS = %w[all mentions none].freeze

  has_many :messages, -> { where(del_flag: false).order(:sent_at, :id) },
           class_name: "PlConnectChatMessageItem", foreign_key: "chat_item_id", dependent: :destroy, inverse_of: false

  has_many :calls, -> { order(started_at: :desc) },
           class_name: "PlConnectCallItem", foreign_key: "chat_item_id", dependent: :destroy, inverse_of: false

  validates :f_type, inclusion: { in: F_TYPES }, allow_blank: true
  validates :state, inclusion: { in: STATES }, allow_blank: true

  # ---------------------------------------------------------------------------
  # Scopes
  # ---------------------------------------------------------------------------

  # All conversations the user is an active member of. `left_at IS NULL` keeps
  # former members out without deleting their membership history.
  #
  # No `distinct` here on purpose: there is at most one active membership row
  # per (conversation, user), and MySQL rejects `SELECT DISTINCT ... ORDER BY`
  # on a joined column that is not in the select list (error 3065), which
  # `ordered_for_sidebar` relies on.
  def self.for_user(user)
    return none if user.blank?

    joins(:pl_connect_chat_item_join_users)
      .where(del_flag: false)
      .where(pl_connect_chat_item_join_users: { user_id: user.id, del_flag: false, left_at: nil })
  end

  # Sidebar ordering: pinned conversations first, then by recency. The
  # `pinned` flag lives on the membership row, so this scope must be chained
  # onto `for_user`.
  #
  # COALESCE is required for portability: MySQL sorts NULL last on DESC while
  # PostgreSQL sorts it first, which would push conversations that never had
  # the pinned flag written to the top.
  def self.ordered_for_sidebar
    order(Arel.sql("COALESCE(pl_connect_chat_item_join_users.pinned, FALSE) DESC"))
      .order(Arel.sql("COALESCE(pl_connect_chat_items.last_message_at, pl_connect_chat_items.created_at) DESC"))
  end

  def self.active_only
    where(archived_at: nil)
  end

  # ---------------------------------------------------------------------------
  # Direct (1:1) conversations
  # ---------------------------------------------------------------------------

  # Deterministic key for a 1:1 conversation. Sorting the two uuids before
  # hashing makes the key independent of who opened the chat, which is what
  # makes `find_or_create_direct` idempotent. A unique index on `direct_key`
  # additionally prevents duplicates under concurrency.
  def self.direct_key_for(uuid_a, uuid_b)
    Digest::SHA256.hexdigest([ uuid_a.to_s, uuid_b.to_s ].sort.join("|"))
  end

  # Returns the existing 1:1 conversation between the two users or creates it.
  # Returns a save_element style result hash so callers can report errors
  # consistently.
  def self.find_or_create_direct(c:, user_a:, user_b:)
    return { successful: false, successful_text: "Both users are required.", element: nil } if user_a.blank? || user_b.blank?
    return { successful: false, successful_text: "A direct chat needs two different users.", element: nil } if user_a.id == user_b.id

    key = direct_key_for(user_a.uuid, user_b.uuid)
    existing = find_by(direct_key: key, del_flag: false)
    return { successful: true, successful_text: nil, element: existing } if existing.present?

    tenant = c[:current_tenant]

    result = new.save_element(c: c, element: {
      f_type: "direct",
      state: "active",
      name: "direct_#{key[0, 16]}",
      title: "#{user_a.login} / #{user_b.login}",
      direct_key: key,
      tenant_id: tenant&.id || user_a.tenant_id,
      message_count: 0
    })
    return result unless result[:successful]

    chat = result[:element]

    [ user_a, user_b ].each do |user|
      member_result = chat.add_member(c: c, user: user, membership_role: "owner")
      return member_result unless member_result[:successful]
    end

    { successful: true, successful_text: nil, element: chat }
  end

  # ---------------------------------------------------------------------------
  # Membership
  # ---------------------------------------------------------------------------

  def memberships
    pl_connect_chat_item_join_users.where(del_flag: false)
  end

  def active_memberships
    memberships.where(left_at: nil)
  end

  def membership_for(user)
    return nil if user.blank?

    active_memberships.find_by(user_id: user.id)
  end

  def member?(user)
    membership_for(user).present?
  end

  # A member may post unless the conversation is read only; in that case only
  # owners and moderators may post.
  def may_post?(user)
    membership = membership_for(user)
    return false if membership.blank?
    return true unless read_only?

    %w[owner moderator].include?(membership.membership_role)
  end

  # Adds a user or reactivates a membership the user had left before.
  def add_member(c:, user:, membership_role: "member")
    return { successful: false, successful_text: "User is required.", element: nil } if user.blank?

    membership = pl_connect_chat_item_join_users.find_by(user_id: user.id) || PlConnectChatItemJoinUser.new

    membership.save_element(c: c, element: {
      pl_connect_chat_item_id: id,
      pl_connect_chat_item_uuid: uuid,
      user_id: user.id,
      user_uuid: user.uuid,
      tenant_id: tenant_id,
      tenant_uuid: tenant_uuid,
      membership_role: membership_role,
      notification_level: "all",
      joined_at: Time.current,
      left_at: nil,
      del_flag: false
    })
  end

  # Soft-leaves the conversation: the membership row is kept so the read state
  # and the audit trail survive, but the user no longer sees the conversation.
  def remove_member(c:, user:)
    membership = membership_for(user)
    return { successful: true, successful_text: nil, element: nil } if membership.blank?

    membership.save_element(c: c, element: { left_at: Time.current })
  end

  # ---------------------------------------------------------------------------
  # Display
  # ---------------------------------------------------------------------------

  # A 1:1 conversation has no meaningful own title — it is always shown as the
  # name of the other participant.
  def display_title_for(user)
    return title.to_s unless f_type == "direct"

    partner_for(user)&.login.presence || title.to_s
  end

  def partner_for(user)
    return nil if user.blank? || f_type != "direct"

    active_memberships.where.not(user_id: user.id).first&.user
  end

  def archived?
    archived_at.present?
  end

  # The ActionCable stream name for this conversation.
  def stream_name
    "pl_connect_chat_#{uuid}"
  end

  # ---------------------------------------------------------------------------
  # Calls
  # ---------------------------------------------------------------------------

  # The call currently ringing or active in this conversation, if any. Used to
  # make starting a call idempotent (PlConnect::CallService#start) and to let a
  # client that opens the conversation after a reload rejoin instead of seeing
  # a stale "call" button.
  def running_call
    calls.merge(PlConnectCallItem.running).first
  end
end
