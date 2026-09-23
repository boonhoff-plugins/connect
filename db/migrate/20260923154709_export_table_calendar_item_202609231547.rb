class ExportTableCalendarItem202609231547 < ActiveRecord::Migration[8.1]
  def up
    ActiveRecord::Base.transaction do
      c = ControllerHelper.init_tenant(:default, {}, false, true)

  
      tables = TableItem.where(f_model_name: 'CalendarItem', f_type: 'table')
      last_index = tables.length - 1
      tables.try(:each_with_index) do |table, index|
        next if index == last_index
        di_table = DynamicItem.find_by(reference_uuid: table.uuid)
        childs = TableItem.where(parent_uuid: table.uuid)
        begin
          childs.delete_all
          di_table.try(:delete)
          table.try(:delete)
        rescue StandardError => e
          puts e.message
        end
      end

      begin
        table = TableItem.find_or_initialize_by(f_model_name: 'CalendarItem', f_type: 'table')
        
      rescue StandardError => e
        puts e.message
      end
  

      field_meeting_active = TableItem.find_or_initialize_by(yaml_key: 'calendar_items.meeting_active')
      field_meeting_active.save_element(c:, element: {"active" => true, "add_dynamics_to_the_import_file" => true, "always_quick_editable" => false, "column_count" => nil, "decimal_position" => 0.57e3, "default" => "", "del_flag" => false, "description" => "When enabled, a 'Join meeting' link is generated automatically and inserted into the description, and shown on the calendar entry.", "edit_type" => "boolean", "exportable" => true, "extension_item_uuid" => "f71cb033-72ca-45e7-b216-12b4b174f262--extension_item--20260828211521", "f_class" => "", "f_model_name" => "CalendarItem", "f_readonly" => false, "f_readonly_condition" => "0", "f_type" => "attribute", "f_type_filter" => nil, "foreign_key_table" => "", "group_sign" => "", "group_sign_onclick" => "", "group_sign_ondblclick" => "", "hierarchy_name" => "calendar_items > meeting_active (12233)", "importable" => false, "include_blank" => false, "input_selected" => false, "javascript_code" => "", "label_onclick" => "", "label_ondblclick" => "", "language" => "en", "limit" => "", "locked_at" => nil, "multiple" => false, "name" => "meeting_active", "onblur" => "", "onchange" => "", "onclick" => "", "ondblclick" => "", "onfocus" => "", "output_format" => "", "output_selected" => false, "parent_uuid" => "559d385f-8649-4bf3-94a7-c5189981f9be--table_item--20260902211833", "parent_version" => 2, "quick_editable" => false, "reference_id" => nil, "reference_model" => nil, "reference_uuid" => nil, "reference_version" => 0, "required" => false, "save_info" => "{\"type\":\"update\",\"history\":{\"id\":1666,\"history_uuid\":\"4171f666-857a-43b4-9c65-710d71bece92--table_item_history--20260922202841\",\"updater_id\":1,\"updater_uuid\":\"e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458\",\"date\":\"2026-09-23 15:05:33\"},\"fields\":{\"extension_item_uuid\":\"24c2a097-941c-419d-90d2-6f487ed823dc--extension_item--20250829171607\",\"table_type\":null,\"edit_type\":null,\"extension_item_id\":1}}", "search_input" => true, "search_output" => true, "selected" => false, "selection_group" => "", "selection_group_filter" => nil, "short_title" => "Meeting active", "show_label" => true, "style" => "", "stylesheet_code" => "", "table_footer_function" => nil, "table_name" => "calendar_items", "table_show_footer" => false, "table_type" => "boolean", "tenant_uuid" => "43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652", "title" => "Meeting active", "uuid" => "a9d9ab94-7701-4f5f-9611-29f750536af2--table_item--20260922202840", "version" => 3, "yaml_key" => "calendar_items.meeting_active", "validation_regex_text" => "", "validation_regex" => "", "encrypted" => false, "mysql_character_set" => "", "tenant_independent" => false, "sensitive_field" => false, version: 1, parent_id: nil, save_info: "{\"type\":\"create-import\",\"history\":{},\"fields\":{}}"})
      field_meeting_active.parent_id = table.id
      field_meeting_active.parent_uuid = table.uuid
      field_meeting_active.save_without_timestamp
      execute "update dynamic_items set reference_id = #{field_meeting_active.id} where reference_uuid = '#{field_meeting_active.uuid}' and reference_uuid is not null and reference_uuid <> ''"
      begin
        TableItemHelper.create_table_column(c:, element: field_meeting_active)
      rescue StandardError => e
        puts e.message
      end
  

      field_meeting_chat_uuid = TableItem.find_or_initialize_by(yaml_key: 'calendar_items.meeting_chat_uuid')
      field_meeting_chat_uuid.save_element(c:, element: {"active" => true, "add_dynamics_to_the_import_file" => true, "always_quick_editable" => false, "column_count" => nil, "decimal_position" => 0.58e3, "default" => "", "del_flag" => false, "description" => "Internal: uuid of the PlConnect group conversation backing this event's meeting. Managed automatically, not user-editable.", "edit_type" => "select", "exportable" => true, "extension_item_uuid" => "f71cb033-72ca-45e7-b216-12b4b174f262--extension_item--20260828211521", "f_class" => "", "f_model_name" => "CalendarItem", "f_readonly" => false, "f_readonly_condition" => "0", "f_type" => "attribute", "f_type_filter" => nil, "foreign_key_table" => "", "group_sign" => "", "group_sign_onclick" => "", "group_sign_ondblclick" => "", "hierarchy_name" => "calendar_items > meeting_chat_uuid (12234)", "importable" => false, "include_blank" => false, "input_selected" => false, "javascript_code" => "", "label_onclick" => "", "label_ondblclick" => "", "language" => "en", "limit" => "150", "locked_at" => nil, "multiple" => false, "name" => "meeting_chat_uuid", "onblur" => "", "onchange" => "", "onclick" => "", "ondblclick" => "", "onfocus" => "", "output_format" => "", "output_selected" => false, "parent_uuid" => "559d385f-8649-4bf3-94a7-c5189981f9be--table_item--20260902211833", "parent_version" => 2, "quick_editable" => false, "reference_id" => nil, "reference_model" => nil, "reference_uuid" => nil, "reference_version" => 0, "required" => false, "save_info" => "{\"type\":\"update\",\"history\":{\"id\":1668,\"history_uuid\":\"1554fc01-fd3a-4f0f-a766-c73a1e0f4037--table_item_history--20260922202841\",\"updater_id\":1,\"updater_uuid\":\"e8fc4c71-cc50-4632-a8a4-876142a7867a--user--20260516184458\",\"date\":\"2026-09-23 15:09:17\"},\"fields\":{\"extension_item_uuid\":\"24c2a097-941c-419d-90d2-6f487ed823dc--extension_item--20250829171607\",\"extension_item_id\":1}}", "search_input" => true, "search_output" => true, "selected" => false, "selection_group" => "", "selection_group_filter" => nil, "short_title" => "Meeting chat uuid", "show_label" => true, "style" => "", "stylesheet_code" => "", "table_footer_function" => nil, "table_name" => "calendar_items", "table_show_footer" => false, "table_type" => "string", "tenant_uuid" => "43cae939-950c-4baa-ae19-b9425624555e--tenant--20210827120652", "title" => "Meeting chat uuid", "uuid" => "fa763109-efde-428f-b3f4-99d74fe25a58--table_item--20260922202841", "version" => 3, "yaml_key" => "calendar_items.meeting_chat_uuid", "validation_regex_text" => "", "validation_regex" => "", "encrypted" => false, "mysql_character_set" => "", "tenant_independent" => false, "sensitive_field" => false, version: 1, parent_id: nil, save_info: "{\"type\":\"create-import\",\"history\":{},\"fields\":{}}"})
      field_meeting_chat_uuid.parent_id = table.id
      field_meeting_chat_uuid.parent_uuid = table.uuid
      field_meeting_chat_uuid.save_without_timestamp
      execute "update dynamic_items set reference_id = #{field_meeting_chat_uuid.id} where reference_uuid = '#{field_meeting_chat_uuid.uuid}' and reference_uuid is not null and reference_uuid <> ''"
      begin
        TableItemHelper.create_table_column(c:, element: field_meeting_chat_uuid)
      rescue StandardError => e
        puts e.message
      end
  
    end
  end

  def down
    # No down migration needed for export table items
  end
end
