# frozen_string_literal: true

# PlConnectChatMentionItem
#
# One resolved mention inside a message. Mentions are extracted from the
# message body when it is saved, so the notification and badge queries never
# have to parse HTML.
#
# `f_type` decides which reference column is filled:
#   * "user"  — mentioned_user_id / mentioned_user_uuid
#   * "role"  — mentioned_role_uuid
#   * "group" — mentioned_group_uuid
#   * "all"   — @channel / @all, no reference column is set
class PlConnectChatMentionItem < ApplicationRecord
  include AssociationOriginalModelConcern

  F_TYPES = %w[user role group all].freeze

  belongs_to :message, class_name: "PlConnectChatMessageItem", foreign_key: "message_id", optional: true, inverse_of: false
  belongs_to :mentioned_user, class_name: "User", foreign_key: "mentioned_user_id", optional: true, inverse_of: false

  validates :f_type, inclusion: { in: F_TYPES }, allow_blank: true

  def self.for_message(message_id)
    where(message_id: message_id, del_flag: false)
  end

  # Unacknowledged mentions of one user, newest first. Drives the mention badge
  # in the workspace shell.
  def self.unread_for_user(user)
    return none if user.blank?

    where(mentioned_user_id: user.id, read_at: nil, del_flag: false).order(created_at: :desc)
  end
end
