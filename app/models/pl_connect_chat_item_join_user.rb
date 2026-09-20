# frozen_string_literal: true

# PlConnectChatItemJoinUser
#
# Membership of one user in one conversation. Besides being the sole source of
# access control it carries the complete per-user state of that conversation:
# read position, unread counter, pinning, muting and notification level.
#
# Leaving a conversation sets `left_at` instead of deleting the row, so the
# read state and the audit trail survive a re-join.
class PlConnectChatItemJoinUser < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_chat_item, optional: true
  belongs_to :user, optional: true

  validates :membership_role, inclusion: { in: PlConnectChatItem::MEMBERSHIP_ROLES }, allow_blank: true
  validates :notification_level, inclusion: { in: PlConnectChatItem::NOTIFICATION_LEVELS }, allow_blank: true

  def self.active
    where(del_flag: false, left_at: nil)
  end

  def active?
    left_at.blank? && !del_flag
  end

  def muted?
    muted_until.present? && muted_until > Time.current
  end

  # Whether a new message in this conversation should raise a notification for
  # this member. `mentions_only` is evaluated by the caller, which knows if the
  # member was mentioned.
  def notify?(mentioned: false)
    return false if muted?

    case notification_level
    when "none" then false
    when "mentions" then mentioned
    else true
    end
  end
end
