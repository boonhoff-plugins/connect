# frozen_string_literal: true

# PlConnectChatReactionItem
#
# One emoji reaction of one user on one message.
#
# Reactions are toggled far more often than any other record in this plugin. To
# avoid flooding pl_connect_chat_reaction_item_histories with one history row
# per click, un-reacting hard-deletes the row (`destroy`) instead of setting
# `del_flag`. A unique index on (message_uuid, user_uuid, emoji) guarantees a
# user cannot react twice with the same emoji.
class PlConnectChatReactionItem < ApplicationRecord
  include AssociationOriginalModelConcern

  # Reasonable upper bound for a single emoji including ZWJ sequences and skin
  # tone modifiers. Anything longer is not an emoji but pasted text.
  MAX_EMOJI_LENGTH = 40

  belongs_to :message, class_name: "PlConnectChatMessageItem", foreign_key: "message_id", optional: true, inverse_of: false
  belongs_to :user, foreign_key: "user_id", optional: true, inverse_of: false

  validates :emoji, length: { maximum: MAX_EMOJI_LENGTH }, allow_blank: true

  def self.for_message(message_id)
    where(message_id: message_id, del_flag: false)
  end
end
