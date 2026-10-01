# frozen_string_literal: true

# CreatePlConnectUserSettings
#
# A single, global, persisted preference per user: their manually chosen chat
# status (see PlConnect::PresenceService#display_states_for /
# pl_connect_presence_controller.js). This is deliberately NOT stored in
# PresenceService's cache (that is for the high-frequency, ephemeral
# online/away heartbeat - see that class's own GDPR reasoning) - a manually
# chosen "Do not disturb"/"Away"/"Offline" status is an explicit user
# preference, not a behavioural signal, so it belongs in a durable row the
# same way any other user setting would, and must survive a page reload /
# a different device/browser (an explicit requirement here), which a cache
# entry cannot guarantee.
#
# Deliberately a lean table, not a full create_plugin-generated one: no admin
# UI/PageItem exists or is needed for this (it is only ever read/written by
# Connect's own services), so the generic creator/updater/tenant/
# extension_item/history columns are skipped - SaveOriginalModelConcern checks
# column_names.include?(...) before touching any of them, so save_element
# still works correctly without them. create_history: false is passed on every
# save_element call for the same reason (no history table exists).
class CreatePlConnectUserSettings < ActiveRecord::Migration[8.1]
  TABLE = "pl_connect_user_settings"
  EXTENSION_FOLDER = "../extensions/plugins/connect/"

  def up
    @c = ControllerHelper.init_tenant(:default, {}, false, true)

    mysql = connection.adapter_name.to_s.downcase.include?("mysql")
    ascii = mysql ? { charset: "latin1", collation: "latin1_general_ci" } : {}
    uuid_size = 54 + TABLE.size

    unless data_source_exists?(TABLE)
      create_table(TABLE, options: "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;", &:timestamps)
    end

    add_column(TABLE, :uuid, :string, limit: uuid_size, comment: "Universally Unique Identifier of this element", **ascii) unless column_exists?(TABLE, :uuid)
    add_column(TABLE, :user_id, :unsigned_integer, comment: "The user this chat status belongs to") unless column_exists?(TABLE, :user_id)
    add_column(TABLE, :user_uuid, :string, limit: 54 + "users".size, comment: "Uuid of the user this chat status belongs to", **ascii) unless column_exists?(TABLE, :user_uuid)
    add_column(TABLE, :chat_status, :string, limit: 20, comment: "Manually chosen status override: away / dnd / offline, blank = automatic", **ascii) unless column_exists?(TABLE, :chat_status)
    add_column(TABLE, :active, :boolean, default: true, comment: "Is this data set active") unless column_exists?(TABLE, :active)
    add_column(TABLE, :del_flag, :boolean, default: false, comment: "Is this data set logically deleted") unless column_exists?(TABLE, :del_flag)

    add_index(TABLE, :uuid, unique: true) unless index_exists?(TABLE, :uuid)
    add_index(TABLE, :user_id, unique: true, name: "idx_plc_user_settings_user") unless index_exists?(TABLE, :user_id, name: "idx_plc_user_settings_user")

    extension_item = ExtensionItem.find_by(extension_folder: EXTENSION_FOLDER, parent_id: nil, del_flag: false, active: true)
    return puts "  [WARN] Connect ExtensionItem not found - skipping TableItem generation." if extension_item.blank?

    begin
      TableItemHelper.generate_models(c: @c, update_attributes: false,
                                      extension_item_id: extension_item.id,
                                      extension_item_uuid: extension_item.uuid,
                                      tables: [ TABLE ])
    rescue StandardError => e
      puts "  [WARN] TableItemHelper.generate_models: #{e.message}"
    end

    puts "  [OK] #{TABLE} created."
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
    TableItem.where(table_name: TABLE).delete_all
    drop_table(TABLE) if data_source_exists?(TABLE)
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}#down: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end
end
