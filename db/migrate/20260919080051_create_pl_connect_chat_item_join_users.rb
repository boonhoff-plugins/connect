class CreatePlConnectChatItemJoinUsers < ActiveRecord::Migration[8.1]
  def up
    ActiveRecord::Base.transaction do
      @c = ControllerHelper.init_tenant(:default, {}, false, true)

      join_table = 'pl_connect_chat_item_join_users'

      first_prefix = 'pl_connect_chat_item'
      first_table = 'pl_connect_chat_items'

      second_prefix = 'user'
      second_table = 'users'

      join_history_table = 'pl_connect_chat_item_join_user_histories'
      extension_folder = '../extensions/plugins/connect/'
      extension_item = ExtensionItem.find_by(extension_folder: extension_folder, parent_id: nil, del_flag: false, active: true)

      if extension_item.blank?
        raise "ExtensionItem with extension_folder '#{extension_folder}' not found. Please create it first."
      end

      if connection.adapter_name.to_s.downcase.include?("mysql")
        charset_latin1   = 'latin1'
        collation_latin1 = 'latin1_general_ci'
      else
        charset_latin1   = nil
        collation_latin1 = nil
      end

      first_uuid_size  = 54 + first_table.size
      second_uuid_size = 54 + second_table.size
      join_uuid_size   = 54 + join_table.size
      join_h_uuid_size = 54 + join_history_table.size

      create_table(join_table, options: 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;', &:timestamps) unless data_source_exists?(join_table)

      add_column(join_table, "#{first_prefix}_id", :unsigned_integer) unless column_exists?(join_table, "#{first_prefix}_id")
      add_column(join_table, "#{first_prefix}_uuid", :string, collation: collation_latin1, charset: charset_latin1, limit: first_uuid_size) unless column_exists?(join_table, "#{first_prefix}_uuid")

      add_column(join_table, "#{second_prefix}_id", :unsigned_integer) unless column_exists?(join_table, "#{second_prefix}_id")
      add_column(join_table, "#{second_prefix}_uuid", :string, collation: collation_latin1, charset: charset_latin1, limit: second_uuid_size) unless column_exists?(join_table, "#{second_prefix}_uuid")

      add_column(join_table, :uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: join_uuid_size, comment: 'Contains the Universally Unique Identifier of this element') unless column_exists?(join_table, :uuid)
      add_column(join_table, :hierarchy_name, :string, limit: 2000, comment: 'displayed hierarchy name') unless column_exists?(join_table, :hierarchy_name)

      add_column(join_table, :tenant_id, :unsigned_integer) unless column_exists?(join_table, :tenant_id)
      add_column(join_table, :tenant_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 61, comment: 'reference field which could contain a reference to a tenant') unless column_exists?(join_table, :tenant_uuid)

      add_column(join_table, :creator_id, :unsigned_integer, comment: 'This field contains the user id of the creator of these element.') unless column_exists?(join_table, :creator_id)
      add_column(join_table, :creator_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'This field contains the user id of the creator of these element.') unless column_exists?(join_table, :creator_uuid)
      add_column(join_table, :updater_id, :unsigned_integer, comment: 'This field contains the user id of the user who has changed this data set.') unless column_exists?(join_table, :updater_id)
      add_column(join_table, :updater_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'This field contains the user id of the user who has changed this data set.') unless column_exists?(join_table, :updater_uuid)

      add_column(join_table, :active, :boolean, default: 1, comment: 'Is these data set active') unless column_exists?(join_table, :active)
      add_column(join_table, :del_flag, :boolean, default: 0, comment: 'Is these data set logical deleted') unless column_exists?(join_table, :del_flag)

      add_index join_table, :uuid, unique: true unless index_exists?(join_table, :uuid)

      # history table

      create_table(join_history_table, options: 'CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;', &:timestamps) unless data_source_exists?(join_history_table)

      add_column(join_history_table, "#{first_prefix}_id", :unsigned_integer) unless column_exists?(join_history_table, "#{first_prefix}_id")
      add_column(join_history_table, "#{first_prefix}_uuid", :string, collation: collation_latin1, charset: charset_latin1, limit: first_uuid_size) unless column_exists?(join_history_table, "#{first_prefix}_uuid")

      add_column(join_history_table, "#{second_prefix}_id", :unsigned_integer) unless column_exists?(join_history_table, "#{second_prefix}_id")
      add_column(join_history_table, "#{second_prefix}_uuid", :string, collation: collation_latin1, charset: charset_latin1, limit: second_uuid_size) unless column_exists?(join_history_table, "#{second_prefix}_uuid")

      add_column(join_history_table, :uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: join_h_uuid_size, comment: 'Contains the Universally Unique Identifier of this element') unless column_exists?(join_history_table, :uuid)
      add_column(join_history_table, :hierarchy_name, :string, limit: 2000, comment: 'displayed hierarchy name') unless column_exists?(join_history_table, :hierarchy_name)

      add_column(join_history_table, :tenant_id, :unsigned_integer) unless column_exists?(join_history_table, :tenant_id)
      add_column(join_history_table, :tenant_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 61, comment: 'reference field which could contain a reference to a tenant') unless column_exists?(join_history_table, :tenant_uuid)

      add_column(join_history_table, :creator_id, :unsigned_integer, comment: 'This field contains the user id of the creator of these element.') unless column_exists?(join_history_table, :creator_id)
      add_column(join_history_table, :creator_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'This field contains the user id of the creator of these element.') unless column_exists?(join_history_table, :creator_uuid)
      add_column(join_history_table, :updater_id, :unsigned_integer, comment: 'This field contains the user id of the user who has changed this data set.') unless column_exists?(join_history_table, :updater_id)
      add_column(join_history_table, :updater_uuid, :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'This field contains the user id of the user who has changed this data set.') unless column_exists?(join_history_table, :updater_uuid)

      add_column(join_history_table, :active, :boolean, default: 1, comment: 'Is these data set active') unless column_exists?(join_history_table, :active)
      add_column(join_history_table, :del_flag, :boolean, default: 0, comment: 'Is these data set logical deleted') unless column_exists?(join_history_table, :del_flag)

      add_column(join_history_table, "history_#{first_prefix}_id", :unsigned_integer) unless column_exists?(join_history_table, "history_#{first_prefix}_id")
      add_column(join_history_table, "history_#{first_prefix}_uuid", :string, collation: collation_latin1, charset: charset_latin1, limit: first_uuid_size) unless column_exists?(join_history_table, "history_#{first_prefix}_uuid")

      add_column(join_history_table, "history_#{second_prefix}_id", :unsigned_integer) unless column_exists?(join_history_table, "history_#{second_prefix}_id")
      add_column(join_history_table, "history_#{second_prefix}_uuid", :string, collation: collation_latin1, charset: charset_latin1, limit: second_uuid_size) unless column_exists?(join_history_table, "history_#{second_prefix}_uuid")

      add_column(join_history_table, :history_uuid , :string, collation: collation_latin1, charset: charset_latin1, limit: join_h_uuid_size, comment: 'Contains the Universally Unique Identifier of this history element') unless column_exists?(join_history_table, :history_uuid)

      add_column(join_history_table, :history_info, :text, limit: 16.megabytes, comment: 'This field contains json object change information (reference to the original data set, which fields contains which have changed, last value of these fields.') unless column_exists?(join_history_table, :history_info)
      add_column(join_history_table, :history_date , :datetime, comment: 'History datetime when this data set was saved.') unless column_exists?(join_history_table, :history_date)

      add_column(join_history_table, :history_user_id , :unsigned_integer, comment: 'user id who saved this data set (changed the origingal).') unless column_exists?(join_history_table, :history_user_id)
      add_column(join_history_table, :history_user_uuid , :string, collation: collation_latin1, charset: charset_latin1, limit: 58, comment: 'user id who saved this data set (changed the origingal).') unless column_exists?(join_history_table, :history_user_uuid)

      add_column(join_history_table, :original_id , :bigint, comment: 'id of the data set in the original table') unless column_exists?(join_history_table, :original_id)
      add_column(join_history_table, :original_uuid , :string, collation: collation_latin1, charset: charset_latin1, limit: join_uuid_size, comment: 'id of the data set in the original table') unless column_exists?(join_history_table, :original_uuid)

      begin
        TableItemHelper.generate_models(c: @c, update_attributes: false,
          extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid,
          tables: [join_table, join_history_table])
        TableItemHelper.set_create_static_parameters

      rescue StandardError => e
        puts e.message
      end
    end
  end
end
