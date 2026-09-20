# frozen_string_literal: true

# CreatePluginPlConnectCallItem202609190755
class CreatePluginPlConnectCallItem202609190755 < ActiveRecord::Migration[8.1]
  def up
    # --- ---------------- ---
    # --- create variables ---
    # --- ---------------- ---
    c = ControllerHelper.init_tenant(:default, {}, false, true)
    admin_role = Role.find_by(name: 'admin')
    model = 'PlConnectCallItem'
    title = 'CallItem'

    parent_extension_item = ExtensionItem.where(active: true, del_flag: false, parent_uuid: nil, parent_id: nil, extension_folder: '../extensions/plugins/connect/').first

    user_id = 1
    user_uuid = 'e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458'

    tenant_id = 1
    tenant_uuid = '43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652'

    extension_type = 'plugin'
    extension_folder = '../extensions/plugins/connect/'

    table_name = 'pl_connect_call_items'
    f_model_name = 'PlConnectCallItem'
    h_table_name = 'pl_connect_call_item_histories'
    h_f_model_name = 'PlConnectCallItemHistory'

    min_uuid_size = 54
    uuid_size = min_uuid_size + table_name.size
    h_uuid_size = uuid_size + 9

    if connection.adapter_name.to_s.downcase.include?("mysql")
      charset = 'utf8mb4'
      collation = 'utf8mb4_unicode_ci'
      charset_latin1 = 'latin1'
      collation_latin1 = 'latin1_general_ci'
      options = "CHARACTER SET #{charset} COLLATE #{collation};"
    else
      charset = nil
      collation = nil
      charset_latin1 = nil
      collation_latin1 = nil
      options = nil
    end


  SYSTEM[:server] ||= {}
  SYSTEM[:server][:default] ||= {}
  SYSTEM[:server][:default][:enable_strong_parameter_filtering] = false


    # --- ------------------- ---
    # --- generate main table ---
    # --- ------------------- ---

    unless data_source_exists?(table_name)
      create_table(table_name, id: false, primary_key: :id, options:)  do |t|
        t.primary_key :id, :unsigned_integer, null: false, auto_increment: true
        t.timestamps
      end
    end

    add_column(table_name, :uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: uuid_size, comment: 'contains the universally unique identifier of this element') unless column_exists?(table_name, :uuid)

    add_column(table_name, :tenant_id, :unsigned_integer, comment: 'reference field which could contain a reference to a tenant (by default the main tenant of the user)') unless column_exists?(table_name, :tenant_id)
    add_column(table_name, :tenant_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 61, comment: 'reference field which could contain a reference to a tenant (by default the main tenant of the user)') unless column_exists?(table_name, :tenant_uuid)

    add_column(table_name, :extension_item_id, :unsigned_integer, comment: 'this field contains the user id of the user who has locked this data set.') unless column_exists?(table_name, :extension_item_id)
    add_column(table_name, :extension_item_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 68, comment: 'this field contains the user id of the user who has locked this data set.') unless column_exists?(table_name, :extension_item_uuid)

    add_column(table_name, :parent_id, :unsigned_integer, comment: 'can be used to reference to an parent element of the same table') unless column_exists?(table_name, :parent_id)

    add_column(table_name, :parent_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: uuid_size, comment: 'contains the universally unique identifier of the parent element') unless column_exists?(table_name, :parent_uuid)
    add_column(table_name, :parent_version, :double, precision: 10, scale: 2, comment: 'this field contains an integer of the data set version of the parent data set') unless column_exists?(table_name, :parent_version)
    add_column(table_name, :decimal_position, :double, precision: 10, scale: 2, comment: 'can be used to sort elements with the same parent_id') unless column_exists?(table_name, :decimal_position)

    add_column(table_name, :reference_model, :string, collation: collation_latin1, charset: charset_latin1, limit: 255, comment: 'generic attribute which can contain a ruby model class, which this data set is referenced (need reference_id)') unless column_exists?(table_name, :reference_model)
    add_column(table_name, :reference_id, :unsigned_integer, comment: 'generic attribute which can contain a id, which this data set is referenced (for 1:1-Relation, need reference_model)') unless column_exists?(table_name, :reference_id)
    add_column(table_name, :reference_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 150, comment: 'contains the universally unique identifier of the reference element') unless column_exists?(table_name, :reference_uuid)
    add_column(table_name, :reference_version, :double, precision: 10, scale: 2, comment: 'this field contains an integer of the data set version of the reference data set') unless column_exists?(table_name, :reference_version)
    add_column(table_name, :reference_parent_id, :unsigned_integer, comment: 'generic attribute which can contain a id, which this data set is referenced (for 1:n-Relation,need reference_model)') unless column_exists?(table_name, :reference_parent_id)
    add_column(table_name, :reference_parent_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 150, comment: 'contains the universally unique identifier of the reference element') unless column_exists?(table_name, :reference_parent_uuid)
    add_column(table_name, :reference_parent_version, :double, precision: 10, scale: 2, comment: 'this field contains an integer of the data set version of the parent reference data set') unless column_exists?(table_name, :reference_version)

    add_column(table_name, :active, :boolean, default: 1, comment: 'Is these data set active') unless column_exists?(table_name, :active)
    add_column(table_name, :del_flag, :boolean, default: 0, comment: 'Is these data set logical deleted') unless column_exists?(table_name, :del_flag)

    add_column(table_name, :creator_id, :unsigned_integer, comment: 'this field contains the user id of the creator of these element.') unless column_exists?(table_name, :creator_id)
    add_column(table_name, :updater_id, :unsigned_integer, comment: 'this field contains the user id of the user who has changed this data set.') unless column_exists?(table_name, :updater_id)
    add_column(table_name, :lock_user_id, :unsigned_integer, comment: 'this field contains the user id of the user who has locked this data set.') unless column_exists?(table_name, :lock_user_id)

    add_column(table_name, :creator_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'this field contains the user id of the creator of these element.') unless column_exists?(table_name, :creator_uuid)
    add_column(table_name, :updater_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'this field contains the user id of the user who has changed this data set.') unless column_exists?(table_name, :updater_uuid)
    add_column(table_name, :lock_user_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'this field contains the user id of the user who has locked this data set.') unless column_exists?(table_name, :lock_user_uuid)

    add_column(table_name, :locked_at, :datetime, comment: 'datetime when this data set was locked.') unless column_exists?(table_name, :locked_at)
    add_column(table_name, :save_info, :text, collation:, charset:, limit: 16.megabytes, comment: 'this field contains json object change information (reference to the history data set, which fields have change, last value of the field, quick changes.') unless column_exists?(table_name, :save_info)
    add_column(table_name, :version, :double, precision: 10, scale: 2, comment: 'this field contains an integer of the data set version of this data set') unless column_exists?(table_name, :version)
    add_column(table_name, :tenant_independent, :boolean, default: false, comment: 'When true, this record is accessible across all tenants regardless of tenant restriction.') unless column_exists?(table_name, :tenant_independent)

    add_column(table_name, :f_type, :string, collation: collation_latin1, charset: charset_latin1, limit: 100, comment: 'can be used to group this data set') unless column_exists?(table_name, :f_type)
    add_column(table_name, :state, :string, collation: collation_latin1, charset: charset_latin1, limit: 100, comment: 'can be used to give a data set a state') unless column_exists?(table_name, :state)
    add_column(table_name, :tags, :text, collation: collation_latin1, charset: charset_latin1, limit: 65_535, comment: 'can contain some tags for a search/filter') unless column_exists?(table_name, :tags)
    add_column(table_name, :name, :string, collation:, charset:, limit: 150, comment: 'unique/shortcut name of an data set (example MPLS-004M)') unless column_exists?(table_name, :name)

    add_column(table_name, :hierarchy_name, :text, collation:, charset:, limit: 65_535, comment: 'displayed hierarchy name') unless column_exists?(table_name, :hierarchy_name)
    add_column(table_name, :yaml_key, :text, collation:, charset:, limit: 65_535, comment: 'yaml key with with this name and parent names point separated like parent_name.name  ') unless column_exists?(table_name, :yaml_key)
    add_column(table_name, :language, :string, default: I18n.locale, collation: collation_latin1, charset: charset_latin1, limit: 2, comment: 'default language of this data set') unless column_exists?(table_name, :language)

    add_column(table_name, :title, :string, collation:, charset:, limit: 150, comment: 'title of an data set (example: Multiconnect 4 Megabyte) ') unless column_exists?(table_name, :title)
    add_column(table_name, :description, :text, collation:, charset:, limit: 65_535, comment: 'Data set of an data set (example: this is a Multiconnect 4 Megabyte) ') unless column_exists?(table_name, :description)

    add_foreign_key(table_name, table_name, column: :parent_id, primary_key: :id, on_delete: :cascade) unless index_exists?(table_name, :parent_id)
    # add_foreign_key(table_name, table_name, column: :parent_uuid, primary_key: :uuid, on_delete: :cascade) unless index_exists?(table_name, :parent_uuid)

    add_foreign_key(table_name, :tenants, column: :tenant_id, primary_key: :id, on_delete: :nullify) unless index_exists?(table_name, :tenant_id)
    add_foreign_key(table_name, :tenants, column: :tenant_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(table_name, :tenant_uuid)

    add_foreign_key(table_name, :extension_items, column: :extension_item_id, primary_key: :id, on_delete: :nullify) unless index_exists?(table_name, :extension_item_id)
    add_foreign_key(table_name, :extension_items, column: :extension_item_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(table_name, :extension_item_uuid)

    add_foreign_key(table_name, :users, column: :creator_id, primary_key: :id, on_delete: :nullify) unless index_exists?(table_name, :creator_id)
    add_foreign_key(table_name, :users, column: :creator_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(table_name, :creator_uuid)
    add_foreign_key(table_name, :users, column: :updater_id, primary_key: :id, on_delete: :nullify) unless index_exists?(table_name, :updater_id)
    add_foreign_key(table_name, :users, column: :updater_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(table_name, :updater_uuid)
    add_foreign_key(table_name, :users, column: :lock_user_id, primary_key: :id, on_delete: :nullify) unless index_exists?(table_name, :lock_user_id)
    add_foreign_key(table_name, :users, column: :lock_user_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(table_name, :lock_user_uuid)

    add_index table_name, :uuid, unique: true unless index_exists?(table_name, :uuid)

    # optional unique index for yaml_key, if you want to use yaml keys for the data set identification (example for lookup items with parent lookup items)
    # add_index table_name, :yaml_key, unique: true, length: 760, where: "yaml_key IS NOT NULL AND del_flag = 0" unless index_exists?(table_name, :yaml_key, unique: true, length: 760, where: "yaml_key IS NOT NULL AND del_flag = 0")
    # alternative unique index for yaml_key with tenant_id, if you want to use yaml keys for the data set identification (example for lookup items with parent lookup items) and you have multiple tenants
    # add_index table_name, [:tenant_id, :yaml_key], unique: true, length: { yaml_key: 760 }, where: "yaml_key IS NOT NULL AND del_flag = 0" unless index_exists?(:documentation_items, [:tenant_id, :yaml_key], unique: true, length: { yaml_key: 760 }, where: "yaml_key IS NOT NULL AND del_flag = 0")

    # --- ---------------------- ---
    # --- generate history table ---
    # --- ---------------------- ---

    unless data_source_exists?(h_table_name)
      create_table(h_table_name, id: false, primary_key: :id, options:) do |t|
        t.primary_key :id, :unsigned_integer, null: false, auto_increment: true
        t.timestamps
      end
    end

    add_column(h_table_name, :uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: uuid_size, comment: 'contains the universally unique identifier of this element') unless column_exists?(h_table_name, :uuid)

    add_column(h_table_name, :tenant_id, :unsigned_integer, comment: 'reference field which could contain a reference to a tenant (by default the main tenant of the user)') unless column_exists?(h_table_name, :tenant_id)
    add_column(h_table_name, :tenant_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 61, comment: 'reference field which could contain a reference to a tenant (by default the main tenant of the user)') unless column_exists?(h_table_name, :tenant_uuid)

    add_column(h_table_name, :extension_item_id, :unsigned_integer, comment: 'this field contains the user id of the user who has locked this data set.') unless column_exists?(h_table_name, :extension_item_id)
    add_column(h_table_name, :extension_item_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 68, comment: 'this field contains the user id of the user who has locked this data set.') unless column_exists?(h_table_name, :extension_item_uuid)

    add_column(h_table_name, :parent_id, :unsigned_integer, comment: 'can be used to reference to an parent element of the same table') unless column_exists?(h_table_name, :parent_id)
    add_column(h_table_name, :parent_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: uuid_size, comment: 'contains the universally unique identifier of the parent element') unless column_exists?(h_table_name, :parent_uuid)
    add_column(h_table_name, :parent_version, :double, precision: 10, scale: 2, comment: 'this field contains an integer of the data set version of the parent data set') unless column_exists?(h_table_name, :parent_version)

    add_column(h_table_name, :decimal_position, :double, precision: 10, scale: 2, comment: 'can be used to sort elements with the same parent_id') unless column_exists?(h_table_name, :decimal_position)

    add_column(h_table_name, :reference_model, :string, collation: collation_latin1, charset: charset_latin1, limit: 255, comment: 'generic attribute which can contain a ruby model class, which this data set is referenced (need reference_id)') unless column_exists?(h_table_name, :reference_model)
    add_column(h_table_name, :reference_id, :unsigned_integer, comment: 'generic attribute which can contain a id, which this data set is referenced (for 1:1-Relation, need reference_model)') unless column_exists?(h_table_name, :reference_id)
    add_column(h_table_name, :reference_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 150, comment: 'contains the universally unique identifier of the reference element') unless column_exists?(h_table_name, :reference_uuid)
    add_column(h_table_name, :reference_version, :double, precision: 10, scale: 2, comment: 'this field contains an integer of the data set version of the reference data set') unless column_exists?(h_table_name, :reference_version)
    add_column(h_table_name, :reference_parent_id, :unsigned_integer, comment: 'generic attribute which can contain a id, which this data set is referenced (for 1:1-Relation, need reference_model)') unless column_exists?(h_table_name, :reference_parent_id)
    add_column(h_table_name, :reference_parent_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 150, comment: 'contains the universally unique identifier of the reference element') unless column_exists?(h_table_name, :reference_parent_uuid)
    add_column(h_table_name, :reference_parent_version, :double, precision: 10, scale: 2, comment: 'this field contains an integer of the data set version of the parent reference data set') unless column_exists?(h_table_name, :reference_version)

    add_column(h_table_name, :active, :boolean, default: 1, comment: 'Is these data set active') unless column_exists?(h_table_name, :active)
    add_column(h_table_name, :del_flag, :boolean, default: 0, comment: 'Is these data set logical deleted') unless column_exists?(h_table_name, :del_flag)

    add_column(h_table_name, :creator_id, :unsigned_integer, comment: 'this field contains the user id of the creator of these element.') unless column_exists?(h_table_name, :creator_id)
    add_column(h_table_name, :updater_id, :unsigned_integer, comment: 'this field contains the user id of the user who has changed this data set.') unless column_exists?(h_table_name, :updater_id)
    add_column(h_table_name, :lock_user_id, :unsigned_integer, comment: 'this field contains the user id of the user who has locked this data set.') unless column_exists?(h_table_name, :lock_user_id)

    add_column(h_table_name, :creator_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'this field contains the user id of the creator of these element.') unless column_exists?(h_table_name, :creator_uuid)
    add_column(h_table_name, :updater_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'this field contains the user id of the user who has changed this data set.') unless column_exists?(h_table_name, :updater_uuid)
    add_column(h_table_name, :lock_user_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'this field contains the user id of the user who has locked this data set.') unless column_exists?(h_table_name, :lock_user_uuid)

    add_column(h_table_name, :locked_at, :datetime, comment: 'datetime when this data set was locked.') unless column_exists?(h_table_name, :locked_at)
    add_column(h_table_name, :save_info, :text, collation:, charset:, limit: 16.megabytes, comment: 'this field contains json object change information (reference to the history data set, which fields have change, last value of the field, quick changes.') unless column_exists?(h_table_name, :save_info)
    add_column(h_table_name, :version, :double, precision: 10, scale: 2, comment: 'this field contains an integer of the data set version of this data set') unless column_exists?(h_table_name, :version)
    add_column(h_table_name, :tenant_independent, :boolean, default: false, comment: 'When true, this record is accessible across all tenants regardless of tenant restriction.') unless column_exists?(h_table_name, :tenant_independent)

    add_column(h_table_name, :f_type, :string, collation: collation_latin1, charset: charset_latin1, limit: 100, comment: 'can be used to group this data set') unless column_exists?(h_table_name, :f_type)
    add_column(h_table_name, :state, :string, collation: collation_latin1, charset: charset_latin1, limit: 100, comment: 'can be used to give a data set a state') unless column_exists?(h_table_name, :state)
    add_column(h_table_name, :tags, :text, collation: collation_latin1, charset: charset_latin1, limit: 65_535, comment: 'can contain some tags for a search/filter') unless column_exists?(h_table_name, :tags)
    add_column(h_table_name, :name, :string, collation:, charset:, limit: 150, comment: 'unique/shortcut name of an data set (example MPLS-004M)') unless column_exists?(h_table_name, :name)
    add_column(h_table_name, :hierarchy_name, :text, collation:, charset:, limit: 65_535, comment: 'displayed hierarchy name') unless column_exists?(h_table_name, :hierarchy_name)

    add_column(h_table_name, :yaml_key, :text, collation:, charset:, limit: 65_535, comment: 'yaml key with with this name and parent names point separated like parent_name.name  ') unless column_exists?(h_table_name, :yaml_key)
    add_column(h_table_name, :language, :string, default: I18n.locale, collation: collation_latin1, charset: charset_latin1, limit: 2, comment: 'default language of this data set') unless column_exists?(h_table_name, :language)

    add_column(h_table_name, :title, :string, collation:, charset:, limit: 150, comment: 'title of an data set (example: Multiconnect 4 Megabyte) ') unless column_exists?(h_table_name, :title)
    add_column(h_table_name, :description, :text, collation:, charset:, limit: 65_535, comment: 'Data set of an data set (example: this is a Multiconnect 4 Megabyte) ') unless column_exists?(h_table_name, :description)

    add_column(h_table_name, :history_info, :text, collation:, charset:, limit: 16.megabytes,comment: 'this field contains json object change information (reference to the original data set, which fields contains which have changed, last value of these fields.') unless column_exists?(h_table_name, :history_info)
    add_column(h_table_name, :history_date, :datetime, comment: 'History datetime when this data set was saved.') unless column_exists?(h_table_name, :history_date)

    add_column(h_table_name, :history_user_id, :unsigned_integer, comment: 'user id who saved this data set (changed the origingal).') unless column_exists?(h_table_name, :history_user_id)
    add_column(h_table_name, :history_user_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'user id who saved this data set (changed the origingal).') unless column_exists?(h_table_name, :history_user_uuid)

    add_column(h_table_name, :original_id, :unsigned_integer, comment: 'id of the data set in the original table') unless column_exists?(h_table_name, :original_id)
    add_column(h_table_name, :original_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: uuid_size, comment: 'id of the data set in the original table') unless column_exists?(h_table_name, :original_uuid)

    add_column(h_table_name, :history_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: h_uuid_size, comment: 'contains the universally unique identifier of this history element') unless column_exists?(h_table_name, :history_uuid)

    add_column(h_table_name, :history_reference_model, :string, collation: collation_latin1, charset: charset_latin1, comment: 'generic attribute which can contain a ruby model class, which this data set is referenced (need history_reference_id)') unless column_exists?(h_table_name, :history_reference_model)
    add_column(h_table_name, :history_reference_id, :unsigned_integer, comment: 'generic attribute which can contain a id, which this data set is referenced (need history_reference_model)') unless column_exists?(h_table_name, :history_reference_id)
    add_column(h_table_name, :history_reference_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 150, comment: 'generic attribute which can contain a uuid, which this data set is referenced (need history_reference_model)') unless column_exists?(h_table_name, :history_reference_uuid)
    add_column(h_table_name, :history_reference_parent_id, :unsigned_integer, comment: 'generic attribute which can contain a id, which this data set is parent referenced (need history_reference_model)') unless column_exists?(h_table_name, :history_reference_parent_id)
    add_column(h_table_name, :history_reference_parent_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 150, comment: 'generic attribute which can contain a uuid, which this data set is parent referenced (need history_reference_model)') unless column_exists?(h_table_name, :history_reference_parent_uuid)

    add_foreign_key(h_table_name, table_name, column: :original_id, primary_key: :id, on_delete: :nullify) unless foreign_key_exists?(h_table_name, table_name, column: :original_id)

    add_foreign_key(h_table_name, table_name, column: :parent_id, primary_key: :id) unless index_exists?(h_table_name, :parent_id)
    add_foreign_key(h_table_name, table_name, column: :parent_uuid, primary_key: :uuid) unless index_exists?(h_table_name, :parent_uuid)

    add_foreign_key(h_table_name, :tenants, column: :tenant_id, primary_key: :id, on_delete: :nullify) unless index_exists?(h_table_name, :tenant_id)
    add_foreign_key(h_table_name, :tenants, column: :tenant_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(h_table_name, :tenant_uuid)

    add_foreign_key(h_table_name, :extension_items, column: :extension_item_id, primary_key: :id, on_delete: :nullify) unless index_exists?(h_table_name, :extension_item_id)
    add_foreign_key(h_table_name, :extension_items, column: :extension_item_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(h_table_name, :extension_item_uuid)

    add_foreign_key(h_table_name, :users, column: :creator_id, primary_key: :id, on_delete: :nullify) unless index_exists?(h_table_name, :creator_id)
    add_foreign_key(h_table_name, :users, column: :creator_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(h_table_name, :creator_uuid)
    add_foreign_key(h_table_name, :users, column: :updater_id, primary_key: :id, on_delete: :nullify) unless index_exists?(h_table_name, :updater_id)
    add_foreign_key(h_table_name, :users, column: :updater_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(h_table_name, :updater_uuid)
    add_foreign_key(h_table_name, :users, column: :lock_user_id, primary_key: :id, on_delete: :nullify) unless index_exists?(h_table_name, :lock_user_id)
    add_foreign_key(h_table_name, :users, column: :lock_user_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(h_table_name, :lock_user_uuid)
    add_foreign_key(h_table_name, :users, column: :history_user_id, primary_key: :id, on_delete: :nullify) unless index_exists?(h_table_name, :history_user_id)
    add_foreign_key(h_table_name, :users, column: :history_user_uuid, primary_key: :uuid, on_delete: :nullify) unless index_exists?(h_table_name, :history_user_uuid)

    execute "alter table #{h_table_name} ROW_FORMAT=COMPRESSED;"

    ActiveRecord::Base.transaction do
      # --- ----------------------- ---
      # --- check for missing uuids ---
      # --- ----------------------- ---

      f_model_name.constantize.where(uuid: nil).each do |element|
        execute "update #{table_name} set uuid = '#{element.new_uuid(c)}' where id ='#{element.id}'"
        execute "update #{h_table_name} set uuid = '#{element.new_uuid(c)}' where original_id ='#{element.id}' and (uuid is null or uuid = '')"
      end

      h_f_model_name.constantize.where(history_uuid: nil).each do |element|
        execute "update #{h_table_name} set history_uuid = '#{element.new_uuid(c)}' where id ='#{element.id}'"
      end

      add_index h_table_name, %i[uuid version] unless index_exists?(h_table_name, %i[uuid version])
  

      # --- --------------------- ---
      # --- create extension item ---
      # --- --------------------- ---
  
      extension_name = "folder_#{extension_type}_name_#{model.underscore}"
      begin
        if ExtensionItem.exists?(name: extension_name, active: 1, del_flag: 0)
          extension_item = ExtensionItem.where(name: extension_name, active: 1, del_flag: 0).first
        else
          count = ExtensionItem.where(del_flag: 0).count * 10
          extension_item = ExtensionItem.new
          ext_hash = { name: extension_name, decimal_position: count, tenant_id:, tenant_uuid:,
            uuid: '9ff66aad-5acf-46c9-955e-94035ed7ed8b--extension_item--20260919095526',
            creator_id: user_id, updater_id: user_id, creator_uuid: user_uuid, updater_uuid: user_uuid,
            save_info: '{"type":"create","history":{},"fields":{}}', f_type: extension_type, extension_folder:,
            title: "#{extension_type.capitalize}: #{title}", description: "#{extension_type.capitalize} #{title}" }

          if parent_extension_item.present?
            ext_hash[:parent_id] = parent_extension_item.id
            ext_hash[:parent_uuid] = parent_extension_item.uuid
          end

          extension_item = extension_item.save_element(c:, element: ext_hash, check_uuid: false, set_tenant: false)[:element]
        end
      rescue StandardError => e
        puts e.message
        puts e.backtrace.join("\n")
      end
      

      # --- ------------------- ---
      # --- create Version Item ---
      # --- ------------------- ---

      if extension_type.blank?
        version_name = model.underscore
      else
        version_name = I18n.t('fields.version_items.name', extension_type:, name: model.underscore)
      end

      if VersionItem.exists?(name: version_name)
        version_item = VersionItem.find_by(name: version_name)
      else
        version_item = VersionItem.new.save_element(c:, check_uuid: false, element:
          { f_type: extension_type, name: version_name, uuid: '180b2482-a05a-4975-8988-8813175a243d--version_item--20260919095526',
          extension_item_version: "0.0.1",
          title: I18n.t('fields.version_items.title', name: model.camelcase.singularize),
          description: I18n.t('fields.version_items.description', name: model.camelcase.singularize),
          extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid })[:element]
      end

      # --- ----------- ---
      # --- create role ---
      # --- ----------- ---

      role = nil
      if extension_type.blank?
        role_name = model.underscore
      else
        role_name = I18n.t('fields.role.name', extension_type:, name: model.underscore)
      end

      if Role.exists?(name: role_name)
        role = Role.find_by(name: role_name)
      else
        role = Role.new.save_element(c:, check_uuid: false, element: { f_type: 'controller', name: role_name,
          title: I18n.t('fields.role.title', name: model.camelcase.singularize),
          description: I18n.t('fields.role.description', name: model.camelcase.singularize),
          uuid: 'd72fb3ae-52f2-4136-a0b8-f272687fc929--role--20260919095526', extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid })[:element]
        UserJoinRole.create(user_id: user_id, role_id: role.id, user_uuid: user_uuid, role_uuid: role.uuid, uuid: '282ef804-7e7e-49a3-8dbb-2e147ed6ac1a--user_join_role--20260919095526')
      end

      # --- ------------------- ---
      # --- create lookup items ---
      # --- ------------------- ---

    lg_page = LookupItem.find_by(name: "#{extension_type}_configuration", parent_id: nil, del_flag: 0, active: 1)

    l_admin_roles = Role.where(name: ['admin'])
    l_roles = [role]

    lg_controller = LookupItemCreateHelper.group(c:, parent: lg_page, name: 'pl_connect_call_item',
      title:, extension_item:, description: I18n.t('fields.lookup_items.page_controller.description', title: title, model: model.camelcase),
      f_type: I18n.t('fields.lookup_items.page_controller.f_type'), roles: l_admin_roles, uuid: 'fe50b947-69a5-42ff-99ab-3b0b0698abe1--lookup_item--20260919095526' )

    lg_f_type = LookupItemCreateHelper.group(c:, parent: lg_controller,
      name: I18n.t('fields.lookup_items.f_type.name'), title: I18n.t('fields.lookup_items.f_type.title'),
      f_type: I18n.t('fields.lookup_items.f_type.f_type'), uuid: 'b1b458ed-3992-4187-bc1a-375bd4a37148--lookup_item--20260919095526', extension_item:,
      description: I18n.t('fields.lookup_items.f_type.description', title: title, model: model.camelcase), roles: l_admin_roles)

    lg_state = LookupItemCreateHelper.group(c:, parent: lg_controller,
      name: I18n.t('fields.lookup_items.state.name'), title: I18n.t('fields.lookup_items.state.title'),
      f_type: I18n.t('fields.lookup_items.state.f_type'), uuid: '0ecd8565-f932-474c-9102-eb1e30fb7d9d--lookup_item--20260919095526', extension_item:,
      description: I18n.t('fields.lookup_items.state.description', title: title, model: model.camelcase), roles: l_admin_roles)

    lg_search = LookupItemCreateHelper.group(c:, parent: lg_controller,
      name: I18n.t('fields.lookup_items.search_option.name'), title: I18n.t('fields.lookup_items.search_option.title'),
      f_type: I18n.t('fields.lookup_items.search_option.f_type'), uuid: '3d8c47bc-8a44-44f2-9c8a-88bb76f35df3--lookup_item--20260919095526', extension_item:,
      description: I18n.t('fields.lookup_items.search_option.description', title: title, model: model.camelcase), roles: l_admin_roles)

  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'qe', decimal_position: '10',
        uuid: 'bb608e16-4abe-4b94-8c38-8310bd2bef80--lookup_item--20260919095526', extension_item:,
        title: 'Activate Quickedit', description: 'Should the table be directly editable?', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'concat', decimal_position: '20',
        uuid: '02f9a09f-4aa9-4d89-b022-77782d75af6e--lookup_item--20260919095526', extension_item:,
        title: 'Additionally link search fields', description: '', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'contains', decimal_position: '30',
        uuid: '32d72a8e-534b-4d75-abb7-2b9c81fc3753--lookup_item--20260919095526', extension_item:,
        title: 'Contain (Partial match)', description: 'Finds records where the search term appears anywhere in the field (e.g., searching for 778 will match 17780). No wildcards required.', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'hls', decimal_position: '40',
        uuid: 'e4249181-b4d0-4261-8bb8-ff2710679a2d--lookup_item--20260919095526', extension_item:,
        title: 'Highlight search term', description: 'Should the search term be highlighted in the results table?', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'max_id', decimal_position: '50',
        uuid: 'f4a829a9-aec3-49c9-94a2-0db46d6e8ca5--lookup_item--20260919095526', extension_item:,
        title: 'Only show with highest ID', description: 'This allows you to search for multiple comma-separated search terms. However, for a search term, if it occurs multiple times, only the one with the highest ID is displayed.', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'min_id', decimal_position: '60',
        uuid: 'a9254de4-cafc-4bc6-9140-a50904e3432a--lookup_item--20260919095526', extension_item:,
        title: 'Only show with lowest ID', description: 'This allows you to search for multiple comma-separated search terms. However, for a search term, if it occurs multiple times, only the one with the lowest ID is displayed.', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'regex', decimal_position: '70',
        uuid: '125d969f-f882-4512-91e7-e2c0bf4396ab--lookup_item--20260919095526', extension_item:,
        title: 'Regex Search (Regular Expression)', description: 'Search term is interpreted as a regular expression\nhttps://de.wikipedia.org/wiki/Regul%C3%A4rer_Ausdruck', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'samm', decimal_position: '80',
        uuid: 'a54579ff-8761-4308-8e2b-ddc217ea532f--lookup_item--20260919095526', extension_item:,
        title: 'Search all my clients', description: 'All my clients to whom I am assigned are searched.', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'where_condition', decimal_position: '90',
        uuid: '9728943d-b42d-4dc1-80c4-7409dffdab5c--lookup_item--20260919095526', extension_item:,
        title: 'Where condition', description: 'The search term is interpreted as part of the Where condition', roles: l_admin_roles)
  

      lg_model_classes = LookupItem.where(f_type: 'group', yaml_key: 'plugin_configuration.table_item.model_classes').first

      lookup_name = I18n.t('fields.lookup_items.model_classes.name', model: model)
      l_model_classes = LookupItemCreateHelper.lookup(c:, parent: lg_model_classes, name: lookup_name,
        uuid: 'a7f47607-0e52-44d5-a687-bd3802d60ea0--lookup_item--20260919095526', extension_item:,
        title: I18n.t('fields.lookup_items.model_classes.title', model: model.camelcase.singularize), roles: l_admin_roles)


      lg_role_controller = LookupItem.where(f_type: 'group', yaml_key: 'plugin_configuration.role.controller').first

      lookup_name = I18n.t('fields.lookup_items.role_controller.name', model: model)
      l_role_controller = LookupItemCreateHelper.lookup(c:, parent: lg_role_controller, name: lookup_name,
        uuid: 'fbf7ab42-b286-4162-901b-bd088dd33994--lookup_item--20260919095526', extension_item:,
        title: I18n.t('fields.lookup_items.role_controller.title', model: model.underscore), roles: l_admin_roles)

      # --- ----------- ---
      # --- create link ---
      # --- ----------- ---

      link_item_type = "link"
      

      # --- ------------------------- ---
      # --- create template item area ---
      # --- ------------------------- ---

      begin
        if TemplateItem.exists?(name: model.underscore, f_type: 'controller')
          template_item = TemplateItem.find_by(name: model.underscore, f_type: 'controller')
        else
          parent_item = TemplateItem.where(parent_id: nil, del_flag: 0, active: 1).first
          count = parent_item.children.count * 10

          template_item = TemplateItem.create(name: model.underscore, decimal_position: count, creator_id: user_id, f_type: 'controller',
            updater_id: user_id, creator_uuid: user_uuid, updater_uuid: user_uuid, save_info: '{"type":"create","history":{},"fields":{}}',
            title:, description: I18n.t('fields.template_items.description', title:), uuid: '495f06c7-0aa4-465e-a945-ca32539901ac--template_item--20260919095526',
            extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid)
        end
      rescue StandardError => e
        puts e.message
        puts e.backtrace.join("\n")
      end

      # --- --------------------- ---
      # --- create data item area ---
      # --- --------------------- ---

      begin
        if DataItem.exists?(name: model.underscore, f_type: 'controller')
          data_item = DataItem.find_by(name: model.underscore, f_type: 'controller')
        else
          parent_item = DataItem.where(parent_id: nil, del_flag: 0, active: 1).first

          begin
            count = parent_item.children.count * 10
          rescue StandardError => e
            count = 10
          end

          data_item = DataItem.create(name: model.underscore, decimal_position: count, creator_id: user_id, updater_id: user_id,
            creator_uuid: user_uuid, updater_uuid: user_uuid, f_type: 'controller', title:, save_info: '{"type":"create","history":{},"fields":{}}',
            description: I18n.t('fields.data_items.description', title:), uuid: 'f7fd6fe2-6440-41b0-95a5-1c0953db87a7--data_item--20260919095526',
            extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid)
        end
      rescue StandardError => e
        puts e.message
        puts e.backtrace.join("\n")
      end

      # --- ---------------------------------------- ---
      # --- init table config in attribute item area ---
      # --- ---------------------------------------- ---

      begin
        TableItemHelper.generate_models(c:, update_attributes: false, extension_item_id: extension_item.id,
          extension_item_uuid: extension_item.uuid, tables: [table_name, h_table_name])
        TableItemHelper.set_create_static_parameters
      rescue StandardError => e
        puts e.message
      end

      begin
        table_item_f_type = TableItem.find_by(table_name:, name: 'f_type')
        table_item_f_type.save_element(c:, element: { selection_group: lg_f_type.uuid, table_type: 'string', edit_type: 'select' })
      rescue StandardError => e
        puts e.message
      end

      begin
        table_item_state = TableItem.find_by(table_name:, name: 'state')
        table_item_state.save_element(c:, element: { selection_group: lg_state.uuid, table_type: 'string', edit_type: 'select' })
      rescue StandardError => e
        puts e.message
      end

      # --- ------------------- ---
      # --- generate page group ---
      # --- ------------------- ---
      group = PageItem.find_or_initialize_by(yaml_key: "group_#{model.underscore}", f_type: 'group')
      group.save_element(c:, element: { decimal_position: 10, version: 1, f_type: 'group', name: "group_#{model.underscore}", short_title: title, title:,
                                        description: I18n.t('fields.page_items.group.description', title:, model: model.camelcase), table_name:, f_model_name:,
                                        extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid })

      # --- generate page list ---
      PageGeneratorHelper.generate_list(c:, group:, title:, table_name:, f_model_name:, extension_item:, decimal_position: 10)

      # --- generate page tree ---
      PageGeneratorHelper.generate_tree(c:, group:, title:, table_name:, f_model_name:, extension_item:, decimal_position: 20)

      # --- generate page history ---
      PageGeneratorHelper.generate_history(c:, group:, title:, table_name:, f_model_name:, h_table_name:, h_f_model_name:, extension_item:, decimal_position: 30)

      # --- generate page search ---
      PageGeneratorHelper.generate_search(c:, group:, title:, table_name:, f_model_name:, extension_item:, decimal_position: 40)

      # --- generate page form ---
      PageGeneratorHelper.generate_form(c:, group:, title:, table_name:, f_model_name:, extension_item:, decimal_position: 50)

      # --- generate web service ---
      PageGeneratorHelper.generate_web_service(c:, group:, title:, table_name:, f_model_name:, extension_item:, decimal_position: 60)

      # --- -------------------------------------- ---
      # --- connect page items with attribute items ---
      # --- -------------------------------------- ---

      begin
        PageItemHelper.check_table_item_reference(c:)
      rescue StandardError => e
        puts e.message
      end

      # --- -------------------------------------- ---
      # ---   generate for page items and table    ---
      # ---  item the default yaml configuration   ---
      # --- -------------------------------------- ---

      # Write YAML locale files into the extension folder when one is configured.
      # This keeps plugin-specific translations separated from the system locales.
      yaml_locale_base = extension_folder.present? ? File.expand_path(extension_folder, Rails.root) : nil

      # Update page_items and table_items locale files (without controller_title to avoid
      # creating wrong page_item.en.yml / table_item.en.yml controller locale files).
      YamlHelper.update_yaml(c: c, reference_model: PageItem, reference_id: group.id, locale_base_path: yaml_locale_base)

      TableItem.where(f_type: 'table', name: [table_name, h_table_name]).try(:each) do |table_item|
        YamlHelper.update_yaml(c: c, reference_model: TableItem, reference_id: table_item.id, locale_base_path: yaml_locale_base)
      end

      # Write a single controller locale entry using the actual controller model name (e.g. test_item),
      # not the reference_model name. This avoids creating page_item.en.yml / table_item.en.yml.
      YamlHelper.write_controller_locale(controller_name: table_name.singularize, title:, locale_base_path: yaml_locale_base)
    end

  end

  def down
    ActiveRecord::Base.transaction do
      # --- ---------------- ---
      # --- create variables ---
      # --- ---------------- ---
      c = ControllerHelper.init_tenant(:default, {}, false, true)
      admin_role = Role.find_by(name: 'admin')
      model = 'PlConnectCallItem'
      title = 'CallItem'

      user_id = 1
      user_uuid = 'e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458'
      tenant_id = 1
      tenant_uuid = '43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652'

      extension_type = 'plugin'
      extension_folder = '../extensions/plugins/connect/'

      table_name = 'pl_connect_call_items'
      f_model_name = 'PlConnectCallItem'
      h_table_name = 'pl_connect_call_item_histories'
      h_f_model_name = 'PlConnectCallItemHistory'
  
      # --- --------------- ---
      # --- drop main table ---
      # --- --------------- ---

      drop_table table_name if data_source_exists?(table_name)

      # --- ------------------ ---
      # --- drop history table ---
      # --- ------------------ ---

      drop_table h_table_name if data_source_exists?(h_table_name)
  


      # --- ------------------- ---
      # --- drop extension item ---
      # --- ------------------- ---
  
      extension_name = "folder_#{extension_type}_name_#{model.underscore}"
      ExtensionItem.where(name: extension_name).delete_all

      # --- ----------------- ---
      # --- drop lookup items ---
      # --- ----------------- ---

      lg_page = LookupItem.find_by(name: 'plugin_configuration', parent_id: nil, del_flag: 0, active: 1)
      LookupItem.where(yaml_key: "#{lg_page.name}.pl_connect_call_item").delete_all

      lg_model_classes = LookupItem.where(f_type: 'group', yaml_key: 'plugin_configuration.table_item.model_classes').first
      lg_role_controller = LookupItem.where(f_type: 'group', yaml_key: 'plugin_configuration.role.controller').first

      LookupItem.where(f_type: 'lookup', parent_id: lg_model_classes.id, name: I18n.t('fields.lookup_items.model_classes.name', model: model.camelcase.singularize)).delete_all
      LookupItem.where(f_type: 'lookup', parent_id: lg_role_controller.id, name: I18n.t('fields.lookup_items.role_controller.name', model: model.underscore)).delete_all

      # --- ----------- ---
      # --- delete role ---
      # --- ----------- ---

      if extension_type.blank?
        role_name = model.underscore
      else
        role_name = I18n.t('fields.role.name', extension_type:, model: model.underscore)
      end

      if Role.exists?(name: role_name)
        role = Role.find_by(name: role_name)
        UserJoinRole.where(role_id: role.id).delete_all
        role.delete
      end

      # --- ----------- ---
      # --- delete link ---
      # --- ----------- ---

      

      # --- ------------------------- ---
      # --- delete template item area ---
      # --- ------------------------- ---

      if TemplateItem.exists?(name: model.underscore, f_type: 'controller')
        template_item = TemplateItem.find_by(name: model.underscore, f_type: 'controller')
        template_item.delete
      end

      # --- --------------------- ---
      # --- delete data item area ---
      # --- --------------------- ---

      if DataItem.exists?(name: model.underscore, f_type: 'controller')
        data_item = DataItem.find_by(name: model.underscore, f_type: 'controller')
        data_item.delete
      end

      # --- ----------------- ---
      # --- delete page group ---
      # --- ----------------- ---

      PageItem.where(f_type: 'group', name: "group_#{model.underscore}").delete_all

      # --- ---------------------- ---
      # --- delete attribute group ---
      # --- ---------------------- ---

      TableItem.where(f_type: 'table', name: [table_name, h_table_name]).delete_all
    end
  end
end
