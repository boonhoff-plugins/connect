# frozen_string_literal: true

# CreatePlConnectRemainingJoinTables
#
# Creates the identity join tables that `rails g boonhoff:create_all_identity_join`
# could not generate for this plugin. The generator aborts after the first join
# table because it tries to inject `include UserVisibilityConcern` into
# `system/app/models/<model>.rb` — but plugin models live under
# `extensions/plugins/connect/app/models/`, so that file does not exist there.
#
# Tables created here (each with its history counterpart):
#   * pl_connect_chat_item_join_groups   — conversation visible/assignable to a group
#   * pl_connect_chat_item_join_roles    — conversation visible/assignable to a role
#   * pl_connect_chat_item_join_tenants  — conversation assigned to a tenant
#   * pl_connect_call_item_join_users    — participants of a call
#
# `pl_connect_chat_item_join_users` is created by the generated migration
# 20260919080051_create_pl_connect_chat_item_join_users.rb and is therefore
# not repeated here.
#
# Unlike the generator output this migration is adapter neutral (MySQL,
# PostgreSQL and SQLite) and ships a working `down` method.
class CreatePlConnectRemainingJoinTables < ActiveRecord::Migration[8.1]
  EXTENSION_FOLDER = "../extensions/plugins/connect/"

  # [join_table_prefix, first_prefix, first_table, second_prefix, second_table]
  JOIN_DEFINITIONS = [
    [ "pl_connect_chat_item_join_groups",  "pl_connect_chat_item", "pl_connect_chat_items", "group",  "groups" ],
    [ "pl_connect_chat_item_join_roles",   "pl_connect_chat_item", "pl_connect_chat_items", "role",   "roles" ],
    [ "pl_connect_chat_item_join_tenants", "pl_connect_chat_item", "pl_connect_chat_items", "tenant", "tenants" ],
    [ "pl_connect_call_item_join_users",   "pl_connect_call_item", "pl_connect_call_items", "user",   "users" ]
  ].freeze

  def up
    ActiveRecord::Base.transaction do
      @c = ControllerHelper.init_tenant(:default, {}, false, true)

      extension_item = ExtensionItem.find_by(extension_folder: EXTENSION_FOLDER, parent_id: nil, del_flag: false, active: true)
      raise "ExtensionItem with extension_folder '#{EXTENSION_FOLDER}' not found. Please create it first." if extension_item.blank?

      touched_tables = []

      JOIN_DEFINITIONS.each do |join_table, first_prefix, first_table, second_prefix, second_table|
        join_history_table = "#{join_table.singularize}_histories"

        _create_join_table(join_table, first_prefix, first_table, second_prefix, second_table)
        _create_join_history_table(join_history_table, join_table, first_prefix, first_table, second_prefix, second_table)

        touched_tables << join_table << join_history_table
      end

      begin
        TableItemHelper.generate_models(c: @c, update_attributes: false,
                                        extension_item_id: extension_item.id,
                                        extension_item_uuid: extension_item.uuid,
                                        tables: touched_tables)
        TableItemHelper.set_create_static_parameters
      rescue StandardError => e
        puts "  [WARN] TableItemHelper.generate_models: #{e.message}"
      end
    end
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  def down
    tables = JOIN_DEFINITIONS.flat_map do |join_table, _fp, _ft, _sp, _st|
      [ join_table, "#{join_table.singularize}_histories" ]
    end

    TableItem.where(table_name: tables).delete_all

    tables.each { |table_name| drop_table(table_name) if data_source_exists?(table_name) }
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}#down: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  private

  # MySQL needs explicit utf8mb4 table options; PostgreSQL and SQLite must not
  # receive them or `create_table` raises. Returning nil keeps the call portable.
  def _table_options
    return nil unless _mysql?

    "CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
  end

  # latin1 collation/charset is a MySQL-only storage optimisation for columns
  # that only ever hold ASCII (uuids, keys). On other adapters it must be nil.
  def _latin1
    return { collation: nil, charset: nil } unless _mysql?

    { collation: "latin1_general_ci", charset: "latin1" }
  end

  def _mysql?
    connection.adapter_name.to_s.downcase.include?("mysql")
  end

  # uuid column width follows the repository convention: the uuid is built as
  # "<36 char uuid>--<table name>--<14 char timestamp>", hence 54 + table name.
  def _uuid_limit(table_name)
    54 + table_name.size
  end

  def _create_join_table(join_table, first_prefix, first_table, second_prefix, second_table)
    create_table(join_table, options: _table_options, &:timestamps) unless data_source_exists?(join_table)

    latin1 = _latin1

    _add_reference_columns(join_table, first_prefix, first_table, second_prefix, second_table, latin1)
    _add_common_columns(join_table, _uuid_limit(join_table), latin1)

    add_index join_table, :uuid, unique: true unless index_exists?(join_table, :uuid)
    unless index_exists?(join_table, [ "#{first_prefix}_id", "#{second_prefix}_id" ])
      add_index join_table, [ "#{first_prefix}_id", "#{second_prefix}_id" ], name: "idx_#{_index_token(join_table)}_pair"
    end
  end

  def _create_join_history_table(join_history_table, join_table, first_prefix, first_table, second_prefix, second_table)
    create_table(join_history_table, options: _table_options, &:timestamps) unless data_source_exists?(join_history_table)

    latin1 = _latin1

    _add_reference_columns(join_history_table, first_prefix, first_table, second_prefix, second_table, latin1)
    _add_common_columns(join_history_table, _uuid_limit(join_history_table), latin1)

    # History specific mirror columns: they keep the reference values as they
    # were at the time the history row was written.
    unless column_exists?(join_history_table, "history_#{first_prefix}_id")
      add_column(join_history_table, "history_#{first_prefix}_id", :unsigned_integer)
    end
    unless column_exists?(join_history_table, "history_#{first_prefix}_uuid")
      add_column(join_history_table, "history_#{first_prefix}_uuid", :string, limit: _uuid_limit(first_table), **latin1)
    end
    unless column_exists?(join_history_table, "history_#{second_prefix}_id")
      add_column(join_history_table, "history_#{second_prefix}_id", :unsigned_integer)
    end
    unless column_exists?(join_history_table, "history_#{second_prefix}_uuid")
      add_column(join_history_table, "history_#{second_prefix}_uuid", :string, limit: _uuid_limit(second_table), **latin1)
    end

    unless column_exists?(join_history_table, :history_uuid)
      add_column(join_history_table, :history_uuid, :string, limit: _uuid_limit(join_history_table), **latin1,
                                                    comment: "Contains the Universally Unique Identifier of this history element")
    end
    unless column_exists?(join_history_table, :history_info)
      add_column(join_history_table, :history_info, :text, limit: 16.megabytes,
                                                    comment: "This field contains json object change information (reference to the original data set, which fields have changed, last value of these fields).")
    end
    unless column_exists?(join_history_table, :history_date)
      add_column(join_history_table, :history_date, :datetime, comment: "History datetime when this data set was saved.")
    end
    unless column_exists?(join_history_table, :history_user_id)
      add_column(join_history_table, :history_user_id, :unsigned_integer, comment: "user id who saved this data set (changed the original).")
    end
    unless column_exists?(join_history_table, :history_user_uuid)
      add_column(join_history_table, :history_user_uuid, :string, limit: 58, **latin1,
                                                         comment: "user id who saved this data set (changed the original).")
    end
    unless column_exists?(join_history_table, :original_id)
      add_column(join_history_table, :original_id, :bigint, comment: "id of the data set in the original table")
    end
    unless column_exists?(join_history_table, :original_uuid)
      add_column(join_history_table, :original_uuid, :string, limit: _uuid_limit(join_table), **latin1,
                                                     comment: "id of the data set in the original table")
    end

    add_index join_history_table, :uuid, unique: true unless index_exists?(join_history_table, :uuid)
    unless index_exists?(join_history_table, :original_id)
      add_index join_history_table, :original_id, name: "idx_#{_index_token(join_history_table)}_original"
    end
  end

  def _add_reference_columns(table_name, first_prefix, first_table, second_prefix, second_table, latin1)
    unless column_exists?(table_name, "#{first_prefix}_id")
      add_column(table_name, "#{first_prefix}_id", :unsigned_integer)
    end
    unless column_exists?(table_name, "#{first_prefix}_uuid")
      add_column(table_name, "#{first_prefix}_uuid", :string, limit: _uuid_limit(first_table), **latin1)
    end
    unless column_exists?(table_name, "#{second_prefix}_id")
      add_column(table_name, "#{second_prefix}_id", :unsigned_integer)
    end
    unless column_exists?(table_name, "#{second_prefix}_uuid")
      add_column(table_name, "#{second_prefix}_uuid", :string, limit: _uuid_limit(second_table), **latin1)
    end
  end

  def _add_common_columns(table_name, uuid_limit, latin1)
    unless column_exists?(table_name, :uuid)
      add_column(table_name, :uuid, :string, limit: uuid_limit, **latin1,
                                    comment: "Contains the Universally Unique Identifier of this element")
    end
    unless column_exists?(table_name, :hierarchy_name)
      add_column(table_name, :hierarchy_name, :string, limit: 2000, comment: "displayed hierarchy name")
    end
    unless column_exists?(table_name, :tenant_id)
      add_column(table_name, :tenant_id, :unsigned_integer)
    end
    unless column_exists?(table_name, :tenant_uuid)
      add_column(table_name, :tenant_uuid, :string, limit: 61, **latin1,
                                           comment: "reference field which could contain a reference to a tenant")
    end
    unless column_exists?(table_name, :creator_id)
      add_column(table_name, :creator_id, :unsigned_integer, comment: "This field contains the user id of the creator of these element.")
    end
    unless column_exists?(table_name, :creator_uuid)
      add_column(table_name, :creator_uuid, :string, limit: 58, **latin1,
                                            comment: "This field contains the user id of the creator of these element.")
    end
    unless column_exists?(table_name, :updater_id)
      add_column(table_name, :updater_id, :unsigned_integer, comment: "This field contains the user id of the user who has changed this data set.")
    end
    unless column_exists?(table_name, :updater_uuid)
      add_column(table_name, :updater_uuid, :string, limit: 58, **latin1,
                                            comment: "This field contains the user id of the user who has changed this data set.")
    end
    unless column_exists?(table_name, :active)
      add_column(table_name, :active, :boolean, default: true, comment: "Is these data set active")
    end
    unless column_exists?(table_name, :del_flag)
      add_column(table_name, :del_flag, :boolean, default: false, comment: "Is these data set logical deleted")
    end
  end

  # MySQL limits index names to 64 characters. The join table names here are
  # long, so the index name is derived from a shortened token.
  def _index_token(table_name)
    table_name.sub(/\Apl_connect_/, "plc_").sub("_join_", "_j_").sub(/_histories\z/, "_h")
  end
end
