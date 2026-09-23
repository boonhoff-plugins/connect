class ExportPlugin202609231601 < ActiveRecord::Migration[8.1]
  def up
    ActiveRecord::Base.transaction do
      # --- ---------------- ---
      # --- create variables ---
      # --- ---------------- ---

      c = ControllerHelper.init_tenant(:default, {}, false, true)
      admin_role = Role.find_by(name: 'admin')
      role = nil
      extension_type = 'plugin'
      set_tenant = false
  
      model = 'CalendarItem'
      name = 'calendar_item'
      user_id = '1'
      user_uuid = 'e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458'

      # --- ----------------- ---
      # --- export page items ---
      # --- ----------------- ---
  
      parent = PageItem.find_by(uuid: 'e54392fb-df7f-48e7-b125-127466012fe1--page_item--20260902211844')
      element_4639 = PageItem.find_or_initialize_by(yaml_key: 'group_calendar_item.form_calendar_item__edit_element.register_common_calendar_item.area_calendar_details')
      
      # this is needed if you add and change in the same migrate execution
      parent = PageItem.find_by(name: 'register_common_calendar_item', del_flag: 0) if parent.blank?
      
      
      
      element_5324 = PageItem.find_or_initialize_by(yaml_key: 'group_calendar_item.form_calendar_item__edit_element.register_common_calendar_item.area_calendar_details.meeting_active')
      element_5324 = element_5324.save_element(c:, check_uuid: false, element: {"active" => true, "add_button_modal" => false, "add_dynamics_to_the_import_file" => false, "add_url_path" => "", "always_quick_editable" => false, "column_count" => nil, "create_dynamic" => true, "decimal_position" => 0.25e2, "default" => "", "del_flag" => false, "delete_url_path" => "", "description" => "When enabled, a join link is generated automatically, inserted into the description above, and shown on the calendar entry.", "dropdown_direction" => "", "edit_type" => "boolean", "edit_url_path" => "", "enable_created_at_area" => false, "enable_f_type_area" => false, "enable_limit_area" => false, "enable_option_area" => false, "enable_order_area" => false, "enable_reference_model_area" => false, "enable_state_area" => false, "enable_updated_at_area" => false, "enable_user_area" => false, "exportable" => false, "extension_item_uuid" => "f71cb033-72ca-45e7-b216-12b4b174f262--extension_item--20260828211521", "f_class" => "", "f_model_name" => "CalendarItem", "f_readonly" => false, "f_readonly_condition" => "0", "f_type" => "attribute", "f_type_filter" => "", "foreign_key_table" => "", "form_config_uuid" => nil, "group_sign" => "", "group_sign_onclick" => "", "group_sign_ondblclick" => "", "hierarchy_name" => "group_calendar_item > form_calendar_item__edit_element (4602) > register_common_calendar_item (4603) > area_calendar_details (4639) > meeting_active (5324)", "importable" => false, "include_blank" => false, "input_selected" => false, "javascript_code" => "", "json_url_path" => "", "label_onclick" => "", "label_ondblclick" => "", "language" => "en", "limit" => "", "load_timeout_in_ms" => 10, "locked_at" => nil, "modal_window_width" => "", "multiple" => false, "name" => "meeting_active", "onblur" => "", "onchange" => "", "onclick" => "", "ondblclick" => "", "onfocus" => "", "option_area_select_group" => nil, "output_format" => "", "output_selected" => false, "parent_uuid" => "480707aa-983d-44dd-8543-108933d7ce4e--page_item--20260903201325", "parent_version" => 4, "quick_editable" => false, "reference_id" => nil, "reference_model" => nil, "reference_uuid" => nil, "reference_version" => 0, "required" => false, "search_input" => false, "search_output" => false, "search_output_name" => "", "searchable" => false, "select_option_title" => "", "selected" => false, "selection_group" => "", "selection_group_filter" => "", "short_title" => "Enable meeting", "show_detail_view_button" => false, "show_label" => true, "show_multiple_change" => false, "show_table_add_button" => true, "show_tree_add_button" => true, "sortable" => true, "style" => "", "stylesheet_code" => "", "table_cookie_active" => false, "table_footer_function" => "", "table_item_id" => nil, "table_item_uuid" => nil, "table_name" => "calendar_items", "table_show_footer" => false, "table_type" => "boolean", "tenant_uuid" => "43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652", "title" => "Enable meeting", "validation_regex" => "", "validation_regex_text" => "", "yaml_key" => "group_calendar_item.form_calendar_item__edit_element.register_common_calendar_item.area_calendar_details.meeting_active", "tenant_independent" => false, "allow_copy" => true, "allow_attachments" => true, "allow_links" => true, "allow_emails" => true, "allow_comments" => true, "allow_workflows" => true, "allow_documentation" => false, "allow_delete" => true, "allow_history_view" => true, "allow_list_view" => true, "allow_search_view" => true, "allow_tree_view" => true, "allow_dashboard_view" => true, "allow_restore" => true, "allow_import" => true, "allow_lock_unlock" => true, "allow_individual_config" => true, "allow_preview" => false, "allow_migrate_export" => true, "allow_full_page_edit" => true, "allow_modal_edit" => true, "allow_archive" => false, "allow_context_menu" => true, "sensitive_field" => false}.merge(parent_id: element_4639.id, parent_uuid: element_4639.uuid), set_tenant: set_tenant)[:element]
      element_5324.role_ids = Role.where(uuid: []).pluck(:id) if element_5324.respond_to?(:role_ids=)
      element_5324.user_ids = User.where(uuid: []).pluck(:id) if element_5324.respond_to?(:user_ids=)
      element_5324.group_ids = Group.where(uuid: []).pluck(:id) if element_5324.respond_to?(:group_ids=)
      element_5324.tenant_ids = Tenant.where(uuid: []).pluck(:id) if element_5324.respond_to?(:tenant_ids=) 

      # --- ----------- ---
      # --- export role ---
      # --- ----------- ---

      if Role.exists?(name: 'plugin/calendar_item')
        role = Role.find_by(name: 'plugin/calendar_item')
        role = role.save_element(c:, check_uuid: false, element: {f_type: "controller", name: "plugin/calendar_item", title: "calendar_item", description: "Role for the controller CalendarItem", uuid: "790e8946-a2c9-4f3a-96a2-766d534b6b7d--role--20260923180128"})[:element]
      else
        role = Role.new.save_element(c:, check_uuid: false, element: { f_type: 'controller', name: I18n.t('fields.role.name', extension_type:, name: model.underscore), title: I18n.t('fields.role.title', name: model.underscore), description: I18n.t('fields.role.description', name: model.camelcase.singularize), uuid: 'bc5120e0-aa7b-4739-97cf-ee7fd9ec5643--role--20260923180128' })[:element]
        UserJoinRole.create(user_id: user_id, role_id: role.id, user_uuid: user_uuid, role_uuid: role.uuid, uuid: 'e2bbae02-69ae-4395-9815-1d265c2d7e2b--user_join_role--20260923180128')
      end
      
      # --- ----------- ---
      # --- export link ---
      # --- ----------- ---

      begin        
        if (!LinkItem.exists?(name: "link_nav_#{name}"))
          parent = LinkItem.find_by(uuid: '814527fc-8002-44e8-8658-38e757342f4a--link_item--20180816133128')
          link_item = LinkItem.new.save_element(c:, check_uuid: false, element: {"action_name" => "show_element", "active" => true, "controller_name" => "calendar_item", "decimal_position" => 0.8e2, "del_flag" => false, "description" => "Page Calendar", "edit_link" => nil, "extension_item_uuid" => "791e7898-20cc-405e-9a80-79b07659b0f7--extension_item--20260902202308", "f_type" => "link", "hierarchy_name" => "<i class=\"fa-solid fa-user-lock\"></i> Default Navigation > <i class=\"fa fa-gear fa-fw\"></i> <span class=\"d-sm-none d-md-inline\">Setting</span> (4) > <i class=\"fa-solid fa-people-carry-box\"></i> Collaboration (24) > <i class=\"fa-solid fa-calendar-days\"></i> Calendar (83)", "id_key" => "", "include_search_link" => false, "is_turbo_link" => true, "language" => "en", "locked_at" => nil, "main_link" => nil, "name" => "link_nav_calendar_item", "onclick" => "", "parent_uuid" => "814527fc-8002-44e8-8658-38e757342f4a--link_item--20180816133128", "parent_version" => 21.0, "reference_id" => nil, "reference_model" => "", "reference_uuid" => nil, "reference_version" => 0.0, "reload_allways_link" => false, "search_link" => nil, "state" => nil, "tags" => "", "target" => "_self", "tenant_uuid" => "43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652", "title" => "<i class=\"fa-solid fa-calendar-days\"></i> Calendar", "url" => "", "yaml_key" => "post_login_navigation.group_nav_config.group_nav_collaboration.link_nav_calendar_item", "widget_item_uuid" => nil, "widget_item_id" => nil, "tenant_independent" => false, "content_type" => ""})[:element]
          link_item.parent_id = parent.id
          link_item.save_witout_timestamp
          LinkItemJoinRole.create(link_item_id: link_item.id, role_id: admin_role.id)
          LinkItemJoinRole.create(link_item_id: link_item.id, role_id: role.id)   
        end   
      rescue StandardError => e
        puts e.message
        puts e.backtrace.join("\n")
      end   
      
      # --- -------------------- ---
      # --- export template area ---
      # --- -------------------- ---

      begin
          if (!TemplateItem.exists?(name:, f_type: 'controller'))
            template_item = TemplateItem.new.save_element(c:, check_uuid: false, element: {"active" => true, "attach_functions" => nil, "bcc" => nil, "body" => nil, "cc" => nil, "decimal_position" => 0.3e2, "del_flag" => false, "description" => "Templates for the controller Calendar", "extension_item_uuid" => "791e7898-20cc-405e-9a80-79b07659b0f7--extension_item--20260902202308", "f_type" => "controller", "from" => nil, "hierarchy_name" => nil, "just_for_creator" => false, "language" => "en", "locked_at" => nil, "name" => "calendar_item", "parent_id" => nil, "parent_uuid" => nil, "parent_version" => 0.0, "publish_date" => nil, "reference_id" => nil, "reference_model" => nil, "reference_uuid" => nil, "reference_version" => 0.0, "select_existing_attachments" => false, "state" => nil, "subject" => nil, "tags" => nil, "tenant_id" => nil, "tenant_uuid" => nil, "title" => "Calendar", "to" => nil, "yaml_key" => nil, "tenant_independent" => false})[:element]
           
          end
      rescue StandardError => e
        puts e.message
        puts e.backtrace.join("\n")
      end
      # --- ---------------- ---
      # --- export data area ---
      # --- ---------------- ---

      begin
          if (!DataItem.exists?(name:, f_type: 'controller'))
            data_item = DataItem.new.save_element(c:, check_uuid: false, element: {"active" => true, "compressed" => false, "content_type" => nil, "data" => nil, "decimal_position" => 0.1e2, "del_flag" => false, "description" => "Files for the controller Calendar", "extension_item_uuid" => "791e7898-20cc-405e-9a80-79b07659b0f7--extension_item--20260902202308", "f_type" => "controller", "hierarchy_name" => "calendar_item", "language" => "en", "locked_at" => nil, "name" => "calendar_item", "parent_id" => nil, "parent_uuid" => nil, "parent_version" => nil, "path" => nil, "reference_id" => nil, "reference_model" => nil, "reference_uuid" => nil, "reference_version" => nil, "state" => nil, "tags" => "", "tenant_uuid" => "43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652", "title" => "Calendar", "yaml_key" => "calendar_item", "encrypted" => false, "tenant_independent" => false, "visibility" => "external"})[:element]
           
        end
      rescue StandardError => e
          puts e.message
          puts e.backtrace.join("\n")
      end
      
    end
  end

  def down
    
  end


end