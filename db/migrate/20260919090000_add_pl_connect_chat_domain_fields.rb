# frozen_string_literal: true

# AddPlConnectChatDomainFields
#
# Adds the domain specific columns to all Connect chat/call tables. The
# `create_plugin` generator only produces the generic RRB column set (uuid,
# tenant, creator, f_type, state, name, title, ...). Everything that actually
# makes a chat a chat is added here.
#
# The migration is adapter neutral (MySQL, PostgreSQL, SQLite):
#   * latin1 charset/collation is only applied on MySQL and only to columns
#     that can never hold anything but ASCII (uuids, hash keys, enum-like keys).
#   * `emoji` is deliberately NOT latin1 — emoji require utf8mb4.
#
# After the schema change TableItemHelper.generate_models creates the missing
# TableItem attribute rows (mandatory, otherwise save_element raises schema
# errors) and the descriptions are filled in explicitly afterwards.
class AddPlConnectChatDomainFields < ActiveRecord::Migration[8.1]
  EXTENSION_FOLDER = "../extensions/plugins/connect/"

  # uuid column widths follow the repository convention:
  # "<36 char uuid>--<table name>--<14 char timestamp>" => 54 + table name size.
  UUID_CHAT      = 54 + "pl_connect_chat_items".size
  UUID_MESSAGE   = 54 + "pl_connect_chat_message_items".size
  UUID_CALL      = 54 + "pl_connect_call_items".size
  UUID_DATA_ITEM = 54 + "data_items".size
  UUID_USER      = 54 + "users".size
  UUID_ROLE      = 54 + "roles".size
  UUID_GROUP     = 54 + "groups".size

  def up
    ActiveRecord::Base.transaction do
      @c = ControllerHelper.init_tenant(:default, {}, false, true)

      _column_definitions.each do |base_table, columns|
        [ base_table, _history_table(base_table) ].each do |table_name|
          next unless data_source_exists?(table_name)

          columns.each do |name, type, options|
            next if column_exists?(table_name, name)

            add_column(table_name, name, type, **_resolve_options(options))
          end
        end
      end

      _add_indexes

      extension_item = ExtensionItem.find_by(extension_folder: EXTENSION_FOLDER, parent_id: nil, del_flag: false, active: true)
      raise "ExtensionItem with extension_folder '#{EXTENSION_FOLDER}' not found." if extension_item.blank?

      tables = _column_definitions.keys.flat_map { |t| [ t, _history_table(t) ] }

      begin
        TableItemHelper.generate_models(c: @c, update_attributes: false,
                                        extension_item_id: extension_item.id,
                                        extension_item_uuid: extension_item.uuid,
                                        tables: tables)
        TableItemHelper.set_create_static_parameters
      rescue StandardError => e
        puts "  [WARN] TableItemHelper.generate_models: #{e.message}"
      end

      _apply_table_item_descriptions(tables)
    end
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  def down
    _indexes.each do |table_name, _columns, index_name|
      remove_index(table_name, name: index_name) if data_source_exists?(table_name) && index_exists?(table_name, name: index_name)
    end

    _column_definitions.each do |base_table, columns|
      [ base_table, _history_table(base_table) ].each do |table_name|
        next unless data_source_exists?(table_name)

        columns.each do |name, _type, _options|
          remove_column(table_name, name) if column_exists?(table_name, name)
        end
      end
    end

    _column_definitions.each do |base_table, columns|
      TableItem.where(table_name: [ base_table, _history_table(base_table) ],
                      name: columns.map { |name, _t, _o| name.to_s }).delete_all
    end
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}#down: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  private

  def _mysql?
    connection.adapter_name.to_s.downcase.include?("mysql")
  end

  def _history_table(table_name)
    "#{table_name.singularize}_histories"
  end

  # Expands the :ascii marker into MySQL specific charset/collation options and
  # strips it on every other adapter.
  def _resolve_options(options)
    options = (options || {}).dup
    ascii = options.delete(:ascii)

    return options unless ascii && _mysql?

    options.merge(charset: "latin1", collation: "latin1_general_ci")
  end

  # rubocop:disable Metrics/MethodLength
  def _column_definitions
    @_column_definitions ||= {
      # ---------------------------------------------------------------------
      # Conversations: direct chats, group chats, team channels
      # ---------------------------------------------------------------------
      "pl_connect_chat_items" => [
        [ :direct_key, :string, { limit: 64, ascii: true, comment: "SHA256 of the two sorted participant uuids; makes 1:1 chats idempotent" } ],
        [ :last_message_at, :datetime, { comment: "Timestamp of the newest message; drives the sidebar ordering" } ],
        [ :last_message_preview, :string, { limit: 255, comment: "Plain text excerpt of the newest message for the sidebar" } ],
        [ :last_message_user_uuid, :string, { limit: UUID_USER, ascii: true, comment: "Author uuid of the newest message" } ],
        [ :message_count, :integer, { default: 0, comment: "Denormalised total number of messages in this conversation" } ],
        [ :archived_at, :datetime, { comment: "Timestamp the conversation was archived; blank means active" } ],
        [ :read_only, :boolean, { default: false, comment: "When enabled only moderators and owners may post" } ],
        [ :avatar_data_item_uuid, :string, { limit: UUID_DATA_ITEM, ascii: true, comment: "DataItem uuid of the conversation avatar image" } ],
        [ :retention_days, :integer, { comment: "Conversation specific retention in days; blank falls back to the plugin default" } ],
        [ :call_active, :boolean, { default: false, comment: "True while a call is running in this conversation" } ],
        [ :call_item_uuid, :string, { limit: UUID_CALL, ascii: true, comment: "Uuid of the currently running PlConnectCallItem" } ]
      ],

      # ---------------------------------------------------------------------
      # Membership: per user state inside a conversation
      # ---------------------------------------------------------------------
      "pl_connect_chat_item_join_users" => [
        [ :membership_role, :string, { limit: 30, ascii: true, default: "member", comment: "owner / moderator / member / guest" } ],
        [ :last_read_message_uuid, :string, { limit: UUID_MESSAGE, ascii: true, comment: "Uuid of the last message this user has read" } ],
        [ :last_read_at, :datetime, { comment: "Timestamp the user last read this conversation" } ],
        [ :unread_count, :integer, { default: 0, comment: "Denormalised number of unread messages for this user" } ],
        [ :muted_until, :datetime, { comment: "Notifications are suppressed until this timestamp" } ],
        [ :pinned, :boolean, { default: false, comment: "User pinned this conversation to the top of the sidebar" } ],
        [ :hidden_at, :datetime, { comment: "User hid the conversation; it reappears on the next message" } ],
        [ :notification_level, :string, { limit: 30, ascii: true, default: "all", comment: "all / mentions / none" } ],
        [ :joined_at, :datetime, { comment: "Timestamp the user joined the conversation" } ],
        [ :left_at, :datetime, { comment: "Timestamp the user left; blank means still a member" } ]
      ],

      # ---------------------------------------------------------------------
      # Messages
      # ---------------------------------------------------------------------
      "pl_connect_chat_message_items" => [
        [ :chat_item_id, :unsigned_integer, { comment: "Conversation this message belongs to" } ],
        [ :chat_item_uuid, :string, { limit: UUID_CHAT, ascii: true, comment: "Conversation uuid this message belongs to" } ],
        [ :sender_user_id, :unsigned_integer, { comment: "Author of the message" } ],
        [ :sender_user_uuid, :string, { limit: UUID_USER, ascii: true, comment: "Author uuid of the message" } ],
        [ :sent_at, :datetime, { comment: "Timestamp the message was sent; primary sort key" } ],
        [ :edited_at, :datetime, { comment: "Timestamp of the last edit; blank means never edited" } ],
        [ :body, :text, { comment: "Message body as sanitised HTML" } ],
        [ :body_plain, :text, { comment: "Plain text version of the body, used for search and previews" } ],
        [ :reply_to_id, :unsigned_integer, { comment: "Message this one is a direct reply to (quote)" } ],
        [ :reply_to_uuid, :string, { limit: UUID_MESSAGE, ascii: true, comment: "Uuid of the message this one replies to" } ],
        [ :thread_reply_count, :integer, { default: 0, comment: "Number of replies in the thread below this message" } ],
        [ :attachment_count, :integer, { default: 0, comment: "Denormalised number of attachments on this message" } ],
        [ :system_event_key, :string, { limit: 60, ascii: true, comment: "Key of a system message (member_added, topic_changed, ...)" } ],
        [ :system_event_payload, :text, { comment: "JSON payload with the details of a system message" } ],
        [ :call_item_uuid, :string, { limit: UUID_CALL, ascii: true, comment: "Call this message reports about (call_event messages)" } ]
      ],

      # ---------------------------------------------------------------------
      # Reactions
      # ---------------------------------------------------------------------
      "pl_connect_chat_reaction_items" => [
        [ :message_id, :unsigned_integer, { comment: "Message that was reacted to" } ],
        [ :message_uuid, :string, { limit: UUID_MESSAGE, ascii: true, comment: "Uuid of the message that was reacted to" } ],
        [ :chat_item_uuid, :string, { limit: UUID_CHAT, ascii: true, comment: "Conversation uuid, denormalised for fast cleanup" } ],
        [ :user_id, :unsigned_integer, { comment: "User who reacted" } ],
        [ :user_uuid, :string, { limit: UUID_USER, ascii: true, comment: "Uuid of the user who reacted" } ],
        # No latin1 here: emoji need utf8mb4.
        [ :emoji, :string, { limit: 40, comment: "The emoji character(s) of the reaction" } ]
      ],

      # ---------------------------------------------------------------------
      # Attachments (files are stored encrypted in DataItem, not in this table)
      # ---------------------------------------------------------------------
      "pl_connect_chat_attachment_items" => [
        [ :message_id, :unsigned_integer, { comment: "Message this attachment belongs to" } ],
        [ :message_uuid, :string, { limit: UUID_MESSAGE, ascii: true, comment: "Uuid of the message this attachment belongs to" } ],
        [ :chat_item_uuid, :string, { limit: UUID_CHAT, ascii: true, comment: "Conversation uuid, denormalised for access checks" } ],
        [ :data_item_id, :unsigned_integer, { comment: "DataItem holding the encrypted file content" } ],
        [ :data_item_uuid, :string, { limit: UUID_DATA_ITEM, ascii: true, comment: "DataItem uuid holding the encrypted file content" } ],
        [ :file_name, :string, { limit: 255, comment: "Original file name as uploaded by the user" } ],
        [ :content_type, :string, { limit: 150, ascii: true, comment: "MIME type of the uploaded file" } ],
        [ :byte_size, :bigint, { comment: "Size of the uploaded file in bytes" } ],
        [ :width, :integer, { comment: "Pixel width for image and video attachments" } ],
        [ :height, :integer, { comment: "Pixel height for image and video attachments" } ],
        [ :thumbnail_data_item_uuid, :string, { limit: UUID_DATA_ITEM, ascii: true, comment: "DataItem uuid of the generated preview image" } ]
      ],

      # ---------------------------------------------------------------------
      # Mentions
      # ---------------------------------------------------------------------
      "pl_connect_chat_mention_items" => [
        [ :message_id, :unsigned_integer, { comment: "Message containing the mention" } ],
        [ :message_uuid, :string, { limit: UUID_MESSAGE, ascii: true, comment: "Uuid of the message containing the mention" } ],
        [ :chat_item_uuid, :string, { limit: UUID_CHAT, ascii: true, comment: "Conversation uuid, denormalised for notification queries" } ],
        [ :mentioned_user_id, :unsigned_integer, { comment: "Mentioned user (f_type user)" } ],
        [ :mentioned_user_uuid, :string, { limit: UUID_USER, ascii: true, comment: "Uuid of the mentioned user" } ],
        [ :mentioned_role_uuid, :string, { limit: UUID_ROLE, ascii: true, comment: "Uuid of the mentioned role (f_type role)" } ],
        [ :mentioned_group_uuid, :string, { limit: UUID_GROUP, ascii: true, comment: "Uuid of the mentioned group (f_type group)" } ],
        [ :notified_at, :datetime, { comment: "Timestamp the mention notification was delivered" } ],
        [ :read_at, :datetime, { comment: "Timestamp the mentioned user acknowledged the mention" } ]
      ],

      # ---------------------------------------------------------------------
      # Calls
      # ---------------------------------------------------------------------
      "pl_connect_call_items" => [
        [ :chat_item_id, :unsigned_integer, { comment: "Conversation this call takes place in" } ],
        [ :chat_item_uuid, :string, { limit: UUID_CHAT, ascii: true, comment: "Conversation uuid this call takes place in" } ],
        [ :room_key, :string, { limit: 64, ascii: true, comment: "Random signalling room key; used as the ActionCable stream name" } ],
        [ :initiator_user_id, :unsigned_integer, { comment: "User who started the call" } ],
        [ :initiator_user_uuid, :string, { limit: UUID_USER, ascii: true, comment: "Uuid of the user who started the call" } ],
        [ :started_at, :datetime, { comment: "Timestamp the first participant connected" } ],
        [ :ended_at, :datetime, { comment: "Timestamp the last participant disconnected" } ],
        [ :duration_seconds, :integer, { comment: "Call duration in seconds, computed when the call ends" } ],
        [ :recording_data_item_uuid, :string, { limit: UUID_DATA_ITEM, ascii: true, comment: "DataItem uuid of the call recording, if one was made" } ],
        [ :max_participants, :integer, { default: 2, comment: "Upper participant limit; the WebRTC mesh does not scale far beyond four" } ]
      ],

      # ---------------------------------------------------------------------
      # Call participants
      # ---------------------------------------------------------------------
      "pl_connect_call_item_join_users" => [
        [ :joined_at, :datetime, { comment: "Timestamp this participant joined the call" } ],
        [ :left_at, :datetime, { comment: "Timestamp this participant left the call" } ],
        [ :peer_id, :string, { limit: 64, ascii: true, comment: "Signalling peer id of this participant's browser tab" } ],
        [ :audio_active, :boolean, { default: true, comment: "Participant's microphone is currently unmuted" } ],
        [ :video_active, :boolean, { default: false, comment: "Participant's camera is currently on" } ],
        [ :screen_active, :boolean, { default: false, comment: "Participant is currently sharing their screen" } ],
        [ :connection_state, :string, { limit: 30, ascii: true, default: "invited", comment: "invited / connecting / connected / disconnected / failed / closed" } ]
      ]
    }
  end
  # rubocop:enable Metrics/MethodLength

  # [table, columns, index name, unique]
  def _indexes
    [
      [ "pl_connect_chat_items", [ :direct_key ], "idx_plc_chat_direct_key", true ],
      [ "pl_connect_chat_items", [ :last_message_at ], "idx_plc_chat_last_message_at", false ],
      [ "pl_connect_chat_item_join_users", [ :user_id, :left_at ], "idx_plc_chat_j_user_active", false ],
      [ "pl_connect_chat_message_items", [ :chat_item_id, :sent_at ], "idx_plc_msg_chat_sent", false ],
      [ "pl_connect_chat_message_items", [ :parent_id, :sent_at ], "idx_plc_msg_thread_sent", false ],
      [ "pl_connect_chat_message_items", [ :chat_item_id, :f_type, :sent_at ], "idx_plc_msg_chat_type_sent", false ],
      [ "pl_connect_chat_reaction_items", [ :message_uuid, :user_uuid, :emoji ], "idx_plc_reaction_unique", true ],
      [ "pl_connect_chat_attachment_items", [ :message_id ], "idx_plc_attachment_message", false ],
      [ "pl_connect_chat_mention_items", [ :mentioned_user_id, :read_at ], "idx_plc_mention_user_read", false ],
      [ "pl_connect_chat_mention_items", [ :message_id ], "idx_plc_mention_message", false ],
      [ "pl_connect_call_items", [ :room_key ], "idx_plc_call_room_key", true ],
      [ "pl_connect_call_items", [ :chat_item_id, :started_at ], "idx_plc_call_chat_started", false ]
    ]
  end

  def _add_indexes
    _indexes.each do |table_name, columns, index_name, unique|
      next unless data_source_exists?(table_name)
      next if index_exists?(table_name, name: index_name)

      add_index(table_name, columns, name: index_name, unique: unique)
    end
  end

  # TableItemHelper creates the attribute rows with an empty description. The
  # column comments defined above are the single source of truth, so they are
  # copied over into the TableItem description here.
  def _apply_table_item_descriptions(tables)
    descriptions = {}

    _column_definitions.each_value do |columns|
      columns.each do |name, _type, options|
        comment = options && options[:comment]
        descriptions[name.to_s] ||= comment if comment.present?
      end
    end

    TableItem.where(table_name: tables, name: descriptions.keys, del_flag: false).find_each do |table_item|
      description = descriptions[table_item.name]
      next if description.blank?

      result = table_item.save_element(c: @c, element: { description: description })
      puts "  [WARN] TableItem '#{table_item.table_name}.#{table_item.name}': #{result[:successful_text]}" unless result[:successful]
    end
  end
end
