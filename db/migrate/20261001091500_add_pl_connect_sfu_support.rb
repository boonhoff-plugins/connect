# frozen_string_literal: true

# AddPlConnectSfuSupport
#
# Adds the groundwork for routing conference calls (f_type "conference")
# through a media server (SFU - Selective Forwarding Unit, LiveKit) instead of
# a plain WebRTC mesh, so a conference can scale well past
# PlConnectCallItem::MESH_PARTICIPANT_LIMIT. Direct 1:1 calls always stay on
# the mesh (always exactly 2 participants, there is no scaling problem there).
#
# == What this migration adds
#   * pl_connect_call_items.sfu_active (+ history table) - set once, at
#     creation time, on each individual call record (PlConnect::CallService).
#     Deliberately NOT re-derived from the live config on every read: an admin
#     flipping the sfu_active config LookupItem mid-system-life must not
#     change the rules for a conference call that is already running - see
#     PlConnectCallItem#full?, which reads this column instead of
#     PlConnect::CallService.sfu_active? directly.
#   * LookupItem config under lookup_item 3699 ("pl_connect_connect"), same
#     master-switch + configurable-value pattern as voicemail_active/
#     webrtc_mesh_participant_limit:
#       - sfu_active            (boolean_lookup, default "false")
#       - sfu_url                (lookup, e.g. "wss://livekit.example.com" -
#                                  the WebSocket URL the BROWSER connects to)
#       - sfu_api_key            (lookup - LiveKit API key, server side only)
#       - sfu_api_secret         (password_lookup - LiveKit API secret)
#       - sfu_max_participants   (integer_lookup, default "50")
#
# Turning sfu_active on WITHOUT a configured sfu_url/sfu_api_key/sfu_api_secret
# is harmless by design - PlConnect::CallService.sfu_configured? requires all
# four to be present, so conferences keep using the mesh until an actual
# LiveKit server has been deployed and its credentials filled in (see
# docker-compose.livekit.yml for a self-hosted starting point).
class AddPlConnectSfuSupport < ActiveRecord::Migration[8.1]
  CONTROLLER_GROUP_UUID = "69e28912-948f-494e-b514-d223a9718275--lookup_item--20260828211521" # pl_connect_connect (3699)

  COLUMN_TABLE = "pl_connect_call_items"
  COLUMN_HISTORY_TABLE = "pl_connect_call_item_histories"
  COLUMN_NAME = :sfu_active
  COLUMN_COMMENT = "Set once at creation time: true when this specific call is being relayed through the " \
                   "SFU media server (LiveKit) instead of a plain WebRTC mesh. Never re-derived from the live " \
                   "sfu_active config afterwards, so an admin toggling that config mid-system-life cannot change " \
                   "the rules for a call already in progress."

  ITEMS = [
    {
      uuid: "7b7a9a2b-6e0a-4a2e-8a2a-7b0a6e0a4a2e--lookup_item--20261001090000",
      name: "sfu_active", f_type: "boolean_lookup", title: "false",
      description: "Master switch: when active (and sfu_url/sfu_api_key/sfu_api_secret are all configured, see " \
                   "PlConnect::CallService.sfu_configured?), new conference calls (group/channel/team) are " \
                   "relayed through the configured SFU media server (LiveKit) instead of a plain WebRTC mesh, " \
                   "removing PlConnectCallItem::MESH_PARTICIPANT_LIMIT's ceiling in favour of " \
                   "sfu_max_participants. Direct 1:1 calls always stay on the mesh regardless of this switch."
    },
    {
      uuid: "2a1c9e2d-4b6a-4c8e-9a2a-2a1c9e2d4b6a--lookup_item--20261001090000",
      name: "sfu_url", f_type: "lookup", title: "",
      description: "WebSocket URL of the LiveKit server the BROWSER connects to directly, e.g. " \
                   "\"wss://livekit.example.com\". Only relevant while sfu_active is on."
    },
    {
      uuid: "3b2d0f3e-5c7b-4d9f-ab3b-3b2d0f3e5c7b--lookup_item--20261001090000",
      name: "sfu_api_key", f_type: "lookup", title: "",
      description: "LiveKit API key used server side (PlConnect::SfuService) to mint short-lived, per-user " \
                   "access tokens - never sent to the browser on its own, only the signed token is. Only " \
                   "relevant while sfu_active is on."
    },
    {
      uuid: "4c3e1a4f-6d8c-4eaf-bc4c-4c3e1a4f6d8c--lookup_item--20261001090000",
      name: "sfu_api_secret", f_type: "password_lookup", title: "",
      description: "LiveKit API secret used server side (PlConnect::SfuService) to sign access tokens - never " \
                   "sent to the browser. Only relevant while sfu_active is on."
    },
    {
      uuid: "5d4f2b5a-7e9d-4fb1-cd5d-5d4f2b5a7e9d--lookup_item--20261001090000",
      name: "sfu_max_participants", f_type: "integer_lookup", title: "50",
      description: "Maximum number of participants in an SFU-relayed conference call. A real ceiling is still " \
                   "enforced server side (PlConnectCallItem::SFU_PARTICIPANT_LIMIT) so this value can only ever " \
                   "be lowered, not raised past it. Only relevant while sfu_active is on - mesh conferences keep " \
                   "using webrtc_mesh_participant_limit instead."
    }
  ].freeze

  def up
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    _add_sfu_active_column
    _add_config_items
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
    [ COLUMN_TABLE, COLUMN_HISTORY_TABLE ].each do |table_name|
      remove_column(table_name, COLUMN_NAME) if data_source_exists?(table_name) && column_exists?(table_name, COLUMN_NAME)
    end

    TableItem.where(table_name: [ COLUMN_TABLE, COLUMN_HISTORY_TABLE ], name: COLUMN_NAME.to_s).delete_all

    ITEMS.each do |attrs|
      item = LookupItem.find_by(uuid: attrs[:uuid])
      next if item.blank?

      LookupItemJoinRole.where(lookup_item_id: item.id).destroy_all
      item.destroy
    end
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  private

  def _add_sfu_active_column
    [ COLUMN_TABLE, COLUMN_HISTORY_TABLE ].each do |table_name|
      unless data_source_exists?(table_name)
        puts "  [SKIP] table #{table_name} does not exist."
        next
      end

      if column_exists?(table_name, COLUMN_NAME)
        puts "  [SKIP] #{table_name}.#{COLUMN_NAME} already exists."
        next
      end

      add_column(table_name, COLUMN_NAME, :boolean, default: false, comment: COLUMN_COMMENT)
      puts "  [OK] #{table_name}.#{COLUMN_NAME} added."
    end

    extension_item = ExtensionItem.find_by(extension_folder: "../extensions/plugins/connect/", parent_id: nil, del_flag: false, active: true)
    return puts "  [WARN] Connect ExtensionItem not found - skipping TableItem generation." if extension_item.blank?

    begin
      TableItemHelper.generate_models(c: @c, update_attributes: false,
                                      extension_item_id: extension_item.id,
                                      extension_item_uuid: extension_item.uuid,
                                      tables: [ COLUMN_TABLE, COLUMN_HISTORY_TABLE ])
    rescue StandardError => e
      puts "  [WARN] TableItemHelper.generate_models: #{e.message}"
    end

    TableItem.where(table_name: [ COLUMN_TABLE, COLUMN_HISTORY_TABLE ], name: COLUMN_NAME.to_s, del_flag: false).find_each do |table_item|
      result = table_item.save_element(c: @c, element: { description: COLUMN_COMMENT })
      puts "  [WARN] TableItem '#{table_item.table_name}.#{table_item.name}': #{result[:successful_text]}" unless result[:successful]
    end
  end

  def _add_config_items
    controller_group = LookupItem.find_by(uuid: CONTROLLER_GROUP_UUID, del_flag: 0, active: 1)
    return puts "  [SKIP] pl_connect_connect lookup group (3699) not found." if controller_group.blank?

    admin_roles = Role.where(name: [ "admin" ])
    ITEMS.each { |attrs| _create_config_item(attrs, controller_group, admin_roles) }

    YamlHelper.update_yaml(c: @c, reference_model: LookupItem, reference_id: controller_group.id,
      auto_translate: SYSTEM&.dig(:language, :auto_translate_in_another_yml_files))
    sleep 3 # YamlHelper.update_yaml writes in a background Thread - see /memories/repo/yaml-helper-async-thread.md
  end

  def _create_config_item(attrs, controller_group, admin_roles)
    item = LookupItem.find_or_initialize_by(uuid: attrs[:uuid])
    result = item.save_element(c: @c, check_uuid: false, element: {
                                 name: attrs[:name], title: attrs[:title], description: attrs[:description], f_type: attrs[:f_type],
                                 parent_id: controller_group.id, parent_uuid: controller_group.uuid,
                                 extension_item_id: controller_group.extension_item_id, extension_item_uuid: controller_group.extension_item_uuid
                               })

    unless result[:successful]
      puts "  [ERROR] #{attrs[:name]}: #{result[:successful_text]}"
      return
    end

    admin_roles.each { |role| _grant_role(result[:element], role) }
    puts "  [OK] #{attrs[:name]}"
  end

  def _grant_role(lookup_item, role)
    join = LookupItemJoinRole.find_or_initialize_by(lookup_item_id: lookup_item.id, role_id: role.id)
    join.save_element(c: @c, element: {
                        lookup_item_id: lookup_item.id, lookup_item_uuid: lookup_item.uuid,
                        role_id: role.id, role_uuid: role.uuid
                      })
  end
end
