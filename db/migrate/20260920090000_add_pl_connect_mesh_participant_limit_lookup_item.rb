# frozen_string_literal: true

# AddPlConnectMeshParticipantLimitLookupItem
#
# Adds one more administrable config value under the same "pl_connect_chat_item"
# LookupItem group as 20260919110000_add_pl_connect_config_lookup_items.rb:
# webrtc_mesh_participant_limit, read by PlConnect::CallService.mesh_participant_limit
# when a group/channel/team conversation starts a conference call
# (PlConnect::CallService#_start_group_call).
#
# The title is deliberately set to PlConnectCallItem::MESH_PARTICIPANT_LIMIT's
# current value (4), so running this migration changes nothing observable —
# .mesh_participant_limit already clamps whatever is configured here to that
# same constant, because a plain WebRTC mesh needs n*(n-1) peer connections
# and cannot be raised past it by configuration alone (see PlConnectCallItem).
class AddPlConnectMeshParticipantLimitLookupItem < ActiveRecord::Migration[8.1]
  # Same "pl_connect_chat_item" plugin_configuration group as
  # 20260919110000_add_pl_connect_config_lookup_items.rb.
  CONTROLLER_GROUP_UUID = "56a615c0-de38-4b1c-a65d-03875ca24479--lookup_item--20260919090445"

  ITEM = {
    uuid: "2e9a6f0c-2b4b-4f9e-9c2a-1a6b7e0d5f3a--lookup_item--20260920090000",
    name: "webrtc_mesh_participant_limit", f_type: "integer_lookup", title: "4",
    description: "Maximum number of participants in a group/channel/team call (PlConnect::CallService). A plain " \
                 "WebRTC mesh needs n*(n-1) peer connections per participant, so this value can only ever be " \
                 "lowered here, never raised above PlConnectCallItem::MESH_PARTICIPANT_LIMIT - going higher would " \
                 "require a media server (SFU) and is out of scope. No personal data of its own; only caps how " \
                 "many already-authorized conversation members may join the same call."
  }.freeze

  def up
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    controller_group = LookupItem.find_by(uuid: CONTROLLER_GROUP_UUID, del_flag: 0, active: 1)
    return puts "  [SKIP] pl_connect_chat_item lookup group not found." if controller_group.blank?

    admin_roles = Role.where(name: [ "admin" ])
    _create_config_item(ITEM, controller_group, admin_roles)
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
    item = LookupItem.find_by(uuid: ITEM[:uuid])
    return puts "  [SKIP] #{ITEM[:name]} not found." if item.blank?

    LookupItemJoinRole.where(lookup_item_id: item.id).destroy_all
    item.destroy
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  private

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
