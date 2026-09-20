# frozen_string_literal: true

module PlConnect
  # AttachmentService
  #
  # Stores chat attachments and hands them back out again.
  #
  # == Storage
  # Files go into a DataItem, which encrypts (AES-256) and compresses the bytes
  # into the `data` column. This application does not use ActiveStorage, so
  # there is no public blob URL: every byte has to pass through a controller
  # action, which is precisely what makes per-conversation access control
  # possible in the first place.
  #
  # PlConnectChatAttachmentItem is the join between a message and its DataItem
  # and additionally carries the display metadata (original file name, size,
  # image dimensions) so the message list can be rendered without touching the
  # blob at all.
  #
  # == Trust boundary
  # The browser supplied content type is stored for display but is never
  # trusted for the download response. See `download_content_type`.
  class AttachmentService
    DEFAULT_MAX_BYTES = 25 * 1024 * 1024

    # Content types that may be sent back with disposition "inline", i.e. that
    # the browser is allowed to render in place. Everything else is forced to
    # "attachment", which prevents an uploaded .html or .svg from executing in
    # the application's own origin (stored XSS via file upload).
    #
    # image/svg+xml is intentionally absent: SVG is an XML document that can
    # carry <script>.
    INLINE_CONTENT_TYPES = %w[
      image/png image/jpeg image/gif image/webp image/avif
      audio/mpeg audio/ogg audio/wav audio/webm
      video/mp4 video/webm video/ogg
      application/pdf
    ].freeze

    def initialize(c:, user:)
      @c = c
      @user = user
    end

    # Attaches an uploaded file to an existing message.
    #
    # @param chat_item [PlConnectChatItem]
    # @param message [PlConnectChatMessageItem]
    # @param uploaded_file [ActionDispatch::Http::UploadedFile]
    def attach(chat_item:, message:, uploaded_file:)
      return _failure("Conversation not found.") if chat_item.blank?
      return _failure("Message not found.") if message.blank?
      return _failure("You are not a member of this conversation.") unless chat_item.member?(@user)
      return _failure("You may only attach files to your own messages.") unless message.sender_user_id == @user.id
      return _failure("No file received.") if uploaded_file.blank?

      byte_size = uploaded_file.size.to_i
      return _failure("The file is empty.") if byte_size.zero?
      return _failure("The file exceeds the allowed size.") if byte_size > max_bytes

      data_result = _store_blob(uploaded_file: uploaded_file, chat_item: chat_item)
      return data_result unless data_result[:successful]

      data_item = data_result[:element]
      declared_type = uploaded_file.content_type.to_s.presence || "application/octet-stream"

      result = PlConnectChatAttachmentItem.new.save_element(c: @c, element: {
        message_id: message.id,
        message_uuid: message.uuid,
        chat_item_uuid: chat_item.uuid,
        data_item_id: data_item.id,
        data_item_uuid: data_item.uuid,
        f_type: PlConnectChatAttachmentItem.f_type_for(declared_type),
        # The DataItem writer already stripped path components and non-word
        # characters from the name; reuse that value instead of the raw one.
        file_name: data_item.name.to_s,
        content_type: declared_type,
        byte_size: byte_size,
        tenant_id: chat_item.tenant_id,
        tenant_uuid: chat_item.tenant_uuid
      })
      return result unless result[:successful]

      _refresh_attachment_counter(message)
      ChatBroadcaster.message_updated(chat_item: chat_item, message: message.reload)

      result
    rescue StandardError => e
      Rails.logger.error "PlConnect::AttachmentService#attach: #{e.class}: #{e.message}"
      _failure("The file could not be stored.")
    end

    # Resolves an attachment for download and verifies that the caller is a
    # member of the conversation the attachment belongs to. Returns nil in both
    # the "unknown" and the "not allowed" case so the two are indistinguishable.
    def find_for_download(uuid)
      return nil if uuid.blank?

      attachment = PlConnectChatAttachmentItem.find_by(uuid: uuid, del_flag: false)
      return nil if attachment.blank?

      chat = PlConnectChatItem.for_user(@user).find_by(uuid: attachment.chat_item_uuid)
      return nil if chat.blank?

      attachment
    end

    def binary_for(attachment)
      data_item = DataItem.find_by(uuid: attachment.data_item_uuid)
      return nil if data_item.blank?

      DataItemHelper.get_plain_data_field(element: data_item)
    end

    # The content type actually used in the download response.
    #
    # Anything not on the inline allow list is served as
    # application/octet-stream with disposition "attachment". Combined with
    # X-Content-Type-Options: nosniff on the response, this stops the browser
    # from interpreting an uploaded file as HTML or SVG inside this
    # application's origin.
    def download_content_type(attachment)
      declared = attachment.content_type.to_s.split(";").first.to_s.strip.downcase
      INLINE_CONTENT_TYPES.include?(declared) ? declared : "application/octet-stream"
    end

    def download_disposition(attachment)
      INLINE_CONTENT_TYPES.include?(download_content_type(attachment)) ? "inline" : "attachment"
    end

    # Configurable via the LookupItem max_attachment_size_mb.
    def max_bytes
      configured = PLUGIN&.dig(:pl_connect_chat_item, :max_attachment_size_mb).to_i
      configured.positive? ? configured * 1024 * 1024 : DEFAULT_MAX_BYTES
    end

    private

    def _store_blob(uploaded_file:, chat_item:)
      data_item = DataItem.new
      data_item.uploaded_file = uploaded_file

      data_item.save_element(c: @c, element: {
        f_type: "attachment",
        # "internal" keeps the blob out of any public DataItem listing; the
        # only intended way in is through this plugin's download action.
        visibility: "internal",
        reference_model: "PlConnectChatItem",
        reference_uuid: chat_item.uuid,
        tenant_id: chat_item.tenant_id,
        tenant_uuid: chat_item.tenant_uuid,
        # Carry over the values the writer derived from the upload; they are
        # not part of the element hash otherwise and would be lost.
        name: data_item.name,
        content_type: data_item.content_type,
        data: data_item.data,
        compressed: true,
        encrypted: true
      })
    end

    def _refresh_attachment_counter(message)
      message.save_element(c: @c, element: {
        attachment_count: PlConnectChatAttachmentItem.where(message_id: message.id, del_flag: false).count
      })
    end

    def _failure(text)
      { successful: false, successful_text: text, element: nil }
    end
  end
end
