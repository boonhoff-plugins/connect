# frozen_string_literal: true

# CreatePluginPlConnectConnect202608281915
class CreatePluginPlConnectConnect202608281915 < ActiveRecord::Migration[8.1]
  def up
    # --- ---------------- ---
    # --- create variables ---
    # --- ---------------- ---
    c = ControllerHelper.init_tenant(:default, {}, false, true)
    admin_role = Role.find_by(name: 'admin')
    model = 'PlConnectConnect'
    title = 'Connect'

    parent_extension_item = ExtensionItem.where(active: true, del_flag: false, parent_uuid: nil, parent_id: nil, extension_folder: '../extensions/plugins/connect/').first

    user_id = 1
    user_uuid = 'e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458'

    tenant_id = 1
    tenant_uuid = '43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652'

    extension_type = 'plugin'
    extension_folder = '../extensions/plugins/connect/'

    table_name = 'pl_connect_connects'
    f_model_name = 'PlConnectConnect'
    h_table_name = 'pl_connect_connect_histories'
    h_f_model_name = 'PlConnectConnectHistory'

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
            uuid: 'f71cb033-72ca-45e7-b216-12b4b174f262--extension_item--20260828211521',
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
      version_item = VersionItem.find_by(uuid: 'dad2222a-8c7f-4bae-b395-63800eab40b5--version_item--20260828211521') || VersionItem.find_by(name: version_name)
      if version_item.blank?
        version_item = VersionItem.new.save_element(c:, check_uuid: false, element:
          { f_type: extension_type, name: version_name, uuid: 'dad2222a-8c7f-4bae-b395-63800eab40b5--version_item--20260828211521',
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
      role = Role.find_by(uuid: '59a72eb8-4f50-4dc8-a64e-ba401f8702ea--role--20260828211521') || Role.find_by(name: role_name)
      if role.blank?
        role = Role.new.save_element(c:, check_uuid: false, element: { f_type: 'controller', name: role_name,
          title: I18n.t('fields.role.title', name: model.camelcase.singularize),
          description: I18n.t('fields.role.description', name: model.camelcase.singularize),
          uuid: '59a72eb8-4f50-4dc8-a64e-ba401f8702ea--role--20260828211521', extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid })[:element]
        UserJoinRole.create(user_id: user_id, role_id: role.id, user_uuid: user_uuid, role_uuid: role.uuid, uuid: '924cf06b-b8c4-472f-9f5b-bab7f41ce714--user_join_role--20260828211521')
      end

      # --- ------------------- ---
      # --- create lookup items ---
      # --- ------------------- ---

    lg_page = LookupItem.find_by(name: "#{extension_type}_configuration", parent_id: nil, del_flag: 0, active: 1)

    l_admin_roles = Role.where(name: ['admin'])
    l_roles = [role]

    lg_controller = LookupItemCreateHelper.group(c:, parent: lg_page, name: 'pl_connect_connect',
      title:, extension_item:, description: I18n.t('fields.lookup_items.page_controller.description', title: title, model: model.camelcase),
      f_type: I18n.t('fields.lookup_items.page_controller.f_type'), roles: l_admin_roles, uuid: '69e28912-948f-494e-b514-d223a9718275--lookup_item--20260828211521' )

      lg_role_controller = LookupItem.where(f_type: 'group', yaml_key: 'plugin_configuration.role.controller').first

      lookup_name = I18n.t('fields.lookup_items.role_controller.name', model: model)
      l_role_controller = LookupItemCreateHelper.lookup(c:, parent: lg_role_controller, name: lookup_name,
        uuid: '75f64a1a-d19c-4c9d-aa8e-f24bf625970a--lookup_item--20260828211521', extension_item:,
        title: I18n.t('fields.lookup_items.role_controller.title', model: model.underscore), roles: l_admin_roles)

      # --- ----------- ---
      # --- create link ---
      # --- ----------- ---

      begin
        if LinkItem.exists?(name: "link_nav_#{model.underscore}")
          link_item = LinkItem.find_by(name: "link_nav_#{model.underscore}")
        else
          parent_item = LinkItem.find_by(uuid: 'b4002f65-3863-4266-8a8f-aea6291b62b9--link_item--20180307000000')
          count = parent_item.children.count * 10

        
          link_controller_name = "pl_connect/#{model.underscore.gsub('pl_connect_', '')}"
        

          link_item = LinkItem.create(parent_id: parent_item.id, parent_uuid: parent_item.uuid, name: "link_nav_#{model.underscore}", decimal_position: count,
            creator_id: user_id, updater_id: user_id, creator_uuid: user_uuid, updater_uuid: user_uuid, save_info: '{"type":"create","history":{},"fields":{}}',
            f_type: 'link', controller_name: link_controller_name, action_name: 'list_element',
            title:, description: I18n.t('fields.link_items.description', title:), include_search_link: true, uuid: '57263a6c-0189-4481-96a9-762631839650--link_item--20260828211521',
            tenant_id:, tenant_uuid:, extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid)
        end

        LinkItemJoinRole.create(link_item_id: link_item.id, link_item_uuid: link_item.uuid, role_id: admin_role.id, role_uuid: admin_role.uuid, uuid: 'cf9aa6f7-6c44-4419-bb34-d6dbd9408fc4--link_item_join_role--20260828211521')
        LinkItemJoinRole.create(link_item_id: link_item.id, link_item_uuid: link_item.uuid, role_id: role.id, role_uuid: role.uuid, uuid: 'c61be61c-3fc0-4bf8-8c88-4201ccc85803--link_item_join_role--20260828211521')
      rescue StandardError => e
        puts e.message
        puts e.backtrace.join("\n")
      end

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
            title:, description: I18n.t('fields.template_items.description', title:), uuid: '0ff40b09-fd00-4212-928b-68db05d02c15--template_item--20260828211521',
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
            description: I18n.t('fields.data_items.description', title:), uuid: 'e507afc6-1356-420c-ad57-a47d00e9c11e--data_item--20260828211521',
            extension_item_id: extension_item.id, extension_item_uuid: extension_item.uuid)
        end
      rescue StandardError => e
        puts e.message
        puts e.backtrace.join("\n")
      end

      # --- ---------------------------------------- ---
      # --- init table config in attribute item area ---
      # --- ---------------------------------------- ---

  end

  def down
    ActiveRecord::Base.transaction do
      # --- ---------------- ---
      # --- create variables ---
      # --- ---------------- ---
      c = ControllerHelper.init_tenant(:default, {}, false, true)
      admin_role = Role.find_by(name: 'admin')
      model = 'PlConnectConnect'
      title = 'Connect'

      user_id = 1
      user_uuid = 'e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458'
      tenant_id = 1
      tenant_uuid = '43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652'

      extension_type = 'plugin'
      extension_folder = '../extensions/plugins/connect/'

      table_name = 'pl_connect_connects'
      f_model_name = 'PlConnectConnect'
      h_table_name = 'pl_connect_connect_histories'
      h_f_model_name = 'PlConnectConnectHistory'
  


      # --- ------------------- ---
      # --- drop extension item ---
      # --- ------------------- ---
  
      extension_name = "folder_#{extension_type}_name_#{model.underscore}"
      ExtensionItem.where(name: extension_name).delete_all

      # --- ----------------- ---
      # --- drop lookup items ---
      # --- ----------------- ---

      lg_page = LookupItem.find_by(name: 'plugin_configuration', parent_id: nil, del_flag: 0, active: 1)
      LookupItem.where(yaml_key: "#{lg_page.name}.pl_connect_connect").delete_all

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

      
        if LinkItem.exists?(name: "link_nav_#{model.underscore}")
          link_item = LinkItem.find_by(name: "link_nav_#{model.underscore}")
          LinkItemJoinRole.where(link_item_id: link_item.id).delete_all
          link_item.delete
        end
      

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