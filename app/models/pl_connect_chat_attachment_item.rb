# frozen_string_literal: true

# PlConnectChatAttachmentItem
#
# Metadata of a file attached to a chat message. The file content itself is NOT
# stored here — it lives encrypted and deflated in a DataItem, referenced via
# `data_item_uuid`. That keeps the attachment table small and reuses the
# existing encryption-at-rest handling of DataItem.
#
# Downloads must always be gated on conversation membership; `chat_item_uuid`
# is denormalised onto this row so that check needs no extra join.
class PlConnectChatAttachmentItem < ApplicationRecord
  include AssociationOriginalModelConcern

  F_TYPES = %w[image file audio video recording].freeze

  # MIME type prefixes that are safe to render inline in the message list.
  # Everything else is offered as a download only.
  INLINE_CONTENT_TYPE_PREFIXES = %w[image/ audio/ video/].freeze

  belongs_to :message, class_name: "PlConnectChatMessageItem", foreign_key: "message_id", optional: true, inverse_of: false
  belongs_to :data_item, foreign_key: "data_item_id", optional: true, inverse_of: false

  validates :f_type, inclusion: { in: F_TYPES }, allow_blank: true

  def self.for_message(message_id)
    where(message_id: message_id, del_flag: false).order(:decimal_position, :id)
  end

  # Derives the f_type bucket from the MIME type of the uploaded file.
  def self.f_type_for(content_type)
    case content_type.to_s
    when %r{\Aimage/} then "image"
    when %r{\Aaudio/} then "audio"
    when %r{\Avideo/} then "video"
    else "file"
    end
  end

  def image?
    f_type == "image"
  end

  def inline_renderable?
    INLINE_CONTENT_TYPE_PREFIXES.any? { |prefix| content_type.to_s.start_with?(prefix) }
  end

  # Human readable size for the message list.
  def human_byte_size
    return nil if byte_size.blank?

    ActiveSupport::NumberHelper.number_to_human_size(byte_size)
  end
end
