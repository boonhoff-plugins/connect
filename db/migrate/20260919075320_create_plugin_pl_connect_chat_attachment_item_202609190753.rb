# frozen_string_literal: true

# CreatePluginPlConnectChatAttachmentItem202609190753
class CreatePluginPlConnectChatAttachmentItem202609190753 < ActiveRecord::Migration[8.1]
  include Db::PluginItemTables
  def up
    # --- ---------------- ---
    # --- create variables ---
    # --- ---------------- ---
    c = ControllerHelper.init_tenant(:default, {}, false, true)
    admin_role = Role.find_by(name: 'admin')
    model = 'PlConnectChatAttachmentItem'
    title = 'ChatAttachmentItem'

    parent_extension_item = ExtensionItem.where(active: true, del_flag: false, parent_uuid: nil, parent_id: nil, extension_folder: '../extensions/plugins/connect/').first

    user_id = 1
    user_uuid = 'e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458'

    tenant_id = 1
    tenant_uuid = '43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652'

    extension_type = 'plugin'
    extension_folder = '../extensions/plugins/connect/'

    table_name = 'pl_connect_chat_attachment_items'
    f_model_name = 'PlConnectChatAttachmentItem'
    h_table_name = 'pl_connect_chat_attachment_item_histories'
    h_f_model_name = 'PlConnectChatAttachmentItemHistory'

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
    # --- generate main table --- (see Db::PluginItemTables)
    # --- ------------------- ---

    create_plugin_main_table!(table_name:, uuid_size:, options:, charset:, collation:, charset_latin1:, collation_latin1:)

    # --- ---------------------- ---
    # --- generate history table --- (see Db::PluginItemTables)
    # --- ---------------------- ---

    create_plugin_history_table!(table_name:, h_table_name:, uuid_size:, h_uuid_size:, options:, charset:, collation:, charset_latin1:, collation_latin1:)

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
            uuid: '1c60e005-bff2-4fc1-b7bd-30b0a84cd8e8--extension_item--20260919095320',
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

      # Guard by the fixed uuid first: the name is I18n-derived and can differ
      # between languages or a previous, partially applied import — a name-only
      # check would insert an already existing uuid (version_items.uuid UNIQUE).
      version_item = VersionItem.find_by(uuid: '54a28201-fa97-496c-a07f-fb66c7a994cb--version_item--20260919095320') || VersionItem.find_by(name: version_name)
      if version_item.blank?
        version_item = VersionItem.new.save_element(c:, check_uuid: false, element:
          { f_type: extension_type, name: version_name, uuid: '54a28201-fa97-496c-a07f-fb66c7a994cb--version_item--20260919095320',
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

      # Guard by the fixed uuid first: the name is I18n-derived and can differ
      # between languages or a previous, partially applied import — a name-only
      # check would insert an already existing uuid (roles.uuid UNIQUE).
      role = Role.find_by(uuid: '84b5e492-4c7f-499d-9098-54d53ce95adc--role--20260919095320') || Role.find_by(name: role_name)
      if role.blank?
        role = Role.new.save_element(c:, check_uuid: false, element: { f_type: 'controller', name: role_name,
          title: I18n.t('fields.role.title', name: model.camelcase.singularize),
          description: I18n.t('fields.role.description', name: model.camelcase.singularize),
          uuid: '84b5e492-4c7f-499d-9098-54d53ce95adc--role--20260919095320', extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid })[:element]
        UserJoinRole.create(user_id: user_id, role_id: role.id, user_uuid: user_uuid, role_uuid: role.uuid, uuid: '8258cab1-757a-48ad-a35d-a37f3ab41294--user_join_role--20260919095320')
      end

      # --- ------------------- ---
      # --- create lookup items ---
      # --- ------------------- ---

    lg_page = LookupItem.find_by(name: "#{extension_type}_configuration", parent_id: nil, del_flag: 0, active: 1)

    l_admin_roles = Role.where(name: ['admin'])
    l_roles = [role]

    lg_controller = LookupItemCreateHelper.group(c:, parent: lg_page, name: 'pl_connect_chat_attachment_item',
      title:, extension_item:, description: I18n.t('fields.lookup_items.page_controller.description', title: title, model: model.camelcase),
      f_type: I18n.t('fields.lookup_items.page_controller.f_type'), roles: l_admin_roles, uuid: '0493a9e3-603b-47ca-a34c-51ff6c5ef2c2--lookup_item--20260919095320' )

    lg_f_type = LookupItemCreateHelper.group(c:, parent: lg_controller,
      name: I18n.t('fields.lookup_items.f_type.name'), title: I18n.t('fields.lookup_items.f_type.title'),
      f_type: I18n.t('fields.lookup_items.f_type.f_type'), uuid: '34044d1f-52bb-44be-b9ba-ad6a41f3db1b--lookup_item--20260919095320', extension_item:,
      description: I18n.t('fields.lookup_items.f_type.description', title: title, model: model.camelcase), roles: l_admin_roles)

    lg_state = LookupItemCreateHelper.group(c:, parent: lg_controller,
      name: I18n.t('fields.lookup_items.state.name'), title: I18n.t('fields.lookup_items.state.title'),
      f_type: I18n.t('fields.lookup_items.state.f_type'), uuid: 'bbdd77a5-9a37-4909-8f5a-5608f9a4260c--lookup_item--20260919095320', extension_item:,
      description: I18n.t('fields.lookup_items.state.description', title: title, model: model.camelcase), roles: l_admin_roles)

    lg_search = LookupItemCreateHelper.group(c:, parent: lg_controller,
      name: I18n.t('fields.lookup_items.search_option.name'), title: I18n.t('fields.lookup_items.search_option.title'),
      f_type: I18n.t('fields.lookup_items.search_option.f_type'), uuid: '0056d95d-5ecf-49e8-b802-aee8dee51039--lookup_item--20260919095320', extension_item:,
      description: I18n.t('fields.lookup_items.search_option.description', title: title, model: model.camelcase), roles: l_admin_roles)

  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'qe', decimal_position: '10',
        uuid: '611d2a9b-1036-4844-8fc2-f68fb4762dce--lookup_item--20260919095320', extension_item:,
        title: 'Activate Quickedit', description: 'Should the table be directly editable?', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'concat', decimal_position: '20',
        uuid: '662092fb-8486-48f3-a9e6-026a6f6602d8--lookup_item--20260919095320', extension_item:,
        title: 'Additionally link search fields', description: '', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'contains', decimal_position: '30',
        uuid: '1ffef0c5-e2d3-4c27-9418-7f28452424b7--lookup_item--20260919095320', extension_item:,
        title: 'Contain (Partial match)', description: 'Finds records where the search term appears anywhere in the field (e.g., searching for 778 will match 17780). No wildcards required.', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'hls', decimal_position: '40',
        uuid: 'f32f82a9-c75c-4bfc-97ce-79f558a91a82--lookup_item--20260919095320', extension_item:,
        title: 'Highlight search term', description: 'Should the search term be highlighted in the results table?', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'max_id', decimal_position: '50',
        uuid: 'c6bd7bcc-3155-4764-843f-283f0ea3ed06--lookup_item--20260919095320', extension_item:,
        title: 'Only show with highest ID', description: 'This allows you to search for multiple comma-separated search terms. However, for a search term, if it occurs multiple times, only the one with the highest ID is displayed.', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'min_id', decimal_position: '60',
        uuid: '9b463fd9-d241-4ea4-b25f-bc642a00efed--lookup_item--20260919095320', extension_item:,
        title: 'Only show with lowest ID', description: 'This allows you to search for multiple comma-separated search terms. However, for a search term, if it occurs multiple times, only the one with the lowest ID is displayed.', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'regex', decimal_position: '70',
        uuid: '518aa535-dc42-48d1-bd1b-ac5196b1cfd1--lookup_item--20260919095320', extension_item:,
        title: 'Regex Search (Regular Expression)', description: 'Search term is interpreted as a regular expression\nhttps://de.wikipedia.org/wiki/Regul%C3%A4rer_Ausdruck', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'samm', decimal_position: '80',
        uuid: '8cfe2c31-a6dd-4de2-b1d5-4da372f77ab3--lookup_item--20260919095320', extension_item:,
        title: 'Search all my clients', description: 'All my clients to whom I am assigned are searched.', roles: l_admin_roles)
  
      lookup_item = LookupItemCreateHelper.lookup(c:, parent: lg_search, f_type: "symbol_lookup",
        name: 'where_condition', decimal_position: '90',
        uuid: '69c53004-a0e3-4b53-a072-1f22785d6c06--lookup_item--20260919095320', extension_item:,
        title: 'Where condition', description: 'The search term is interpreted as part of the Where condition', roles: l_admin_roles)
  

      lg_model_classes = LookupItem.where(f_type: 'group', yaml_key: 'plugin_configuration.table_item.model_classes').first

      lookup_name = I18n.t('fields.lookup_items.model_classes.name', model: model)
      l_model_classes = LookupItemCreateHelper.lookup(c:, parent: lg_model_classes, name: lookup_name,
        uuid: 'af269c71-42f0-4423-aed8-774ab1b97498--lookup_item--20260919095320', extension_item:,
        title: I18n.t('fields.lookup_items.model_classes.title', model: model.camelcase.singularize), roles: l_admin_roles)


      lg_role_controller = LookupItem.where(f_type: 'group', yaml_key: 'plugin_configuration.role.controller').first

      lookup_name = I18n.t('fields.lookup_items.role_controller.name', model: model)
      l_role_controller = LookupItemCreateHelper.lookup(c:, parent: lg_role_controller, name: lookup_name,
        uuid: '0cf0d59a-161a-4257-83ed-466f0b43865b--lookup_item--20260919095320', extension_item:,
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
            title:, description: I18n.t('fields.template_items.description', title:), uuid: 'f827b72f-f6ee-44e7-8beb-2ab5f17844fb--template_item--20260919095320',
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
            description: I18n.t('fields.data_items.description', title:), uuid: 'f8310773-b269-4a35-ad3f-de4ab6903732--data_item--20260919095320',
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
      model = 'PlConnectChatAttachmentItem'
      title = 'ChatAttachmentItem'

      user_id = 1
      user_uuid = 'e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458'
      tenant_id = 1
      tenant_uuid = '43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652'

      extension_type = 'plugin'
      extension_folder = '../extensions/plugins/connect/'

      table_name = 'pl_connect_chat_attachment_items'
      f_model_name = 'PlConnectChatAttachmentItem'
      h_table_name = 'pl_connect_chat_attachment_item_histories'
      h_f_model_name = 'PlConnectChatAttachmentItemHistory'
  
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
      LookupItem.where(yaml_key: "#{lg_page.name}.pl_connect_chat_attachment_item").delete_all

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