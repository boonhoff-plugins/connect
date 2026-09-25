# frozen_string_literal: true

# MovePlConnectMeshLimitToConnectGroup
#
# Moves "webrtc_mesh_participant_limit" (added by
# AddPlConnectMeshParticipantLimitLookupItem under "pl_connect_chat_item") to
# lookup_item 3699 ("pl_connect_connect"), alongside the other call-behaviour
# switches from AddPlConnectCallAudioConfig - requested explicitly so every
# call-related knob lives in one place. Also raises its default from 4 to 8,
# matching PlConnectCallItem::MESH_PARTICIPANT_LIMIT's own new ceiling (see
# that model) - a plain WebRTC mesh still cannot be configured past that
# constant; 25+ participants would need a media server (SFU) relaying streams
# instead of every browser connecting to every other one directly, which is a
# separate, much larger feature and out of scope here.
#
# Both parent_id and parent_uuid must be passed together - save_element's
# sync_parent_fields resolves a missing one from the OLD parent_uuid still in
# the DB, so passing only parent_id silently leaves the record under its old
# parent (see /memories/repo/save-element-parent-move.md).
class MovePlConnectMeshLimitToConnectGroup < ActiveRecord::Migration[8.1]
  ITEM_UUID = "2e9a6f0c-2b4b-4f9e-9c2a-1a6b7e0d5f3a--lookup_item--20260920090000"
  OLD_GROUP_UUID = "56a615c0-de38-4b1c-a65d-03875ca24479--lookup_item--20260919090445" # pl_connect_chat_item
  NEW_GROUP_UUID = "69e28912-948f-494e-b514-d223a9718275--lookup_item--20260828211521" # pl_connect_connect (3699)

  NEW_TITLE = "8"
  NEW_DESCRIPTION = "Maximum number of participants in a group/channel/team call (PlConnect::CallService). A " \
                     "plain WebRTC mesh needs n*(n-1) peer connections, so this value can only ever be lowered " \
                     "here, never raised above PlConnectCallItem::MESH_PARTICIPANT_LIMIT (8) - real support for " \
                     "20+ participants would require a media server (SFU) and is out of scope. No personal data " \
                     "of its own; only caps how many already-authorized conversation members may join the same " \
                     "call."

  def up
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    item = LookupItem.find_by(uuid: ITEM_UUID, del_flag: false)
    return puts "  [SKIP] webrtc_mesh_participant_limit not found." if item.blank?

    new_group = LookupItem.find_by(uuid: NEW_GROUP_UUID, del_flag: false, active: true)
    return puts "  [SKIP] pl_connect_connect lookup group (3699) not found." if new_group.blank?

    result = item.save_element(c: @c, element: {
                                 parent_id: new_group.id, parent_uuid: new_group.uuid,
                                 extension_item_id: new_group.extension_item_id, extension_item_uuid: new_group.extension_item_uuid,
                                 title: NEW_TITLE, description: NEW_DESCRIPTION
                               })
    return puts "  [ERROR] #{result[:successful_text]}" unless result[:successful]

    YamlHelper.update_yaml(c: @c, reference_model: LookupItem, reference_id: new_group.id,
      auto_translate: SYSTEM&.dig(:language, :auto_translate_in_another_yml_files))
    sleep 3 # YamlHelper.update_yaml writes in a background Thread - see the memory note above.

    puts "  [OK] webrtc_mesh_participant_limit moved to pl_connect_connect (3699), default raised to #{NEW_TITLE}."
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    item = LookupItem.find_by(uuid: ITEM_UUID, del_flag: false)
    return if item.blank?

    old_group = LookupItem.find_by(uuid: OLD_GROUP_UUID, del_flag: false)
    return puts "  [SKIP] pl_connect_chat_item lookup group not found." if old_group.blank?

    item.save_element(c: @c, element: {
                        parent_id: old_group.id, parent_uuid: old_group.uuid,
                        extension_item_id: old_group.extension_item_id, extension_item_uuid: old_group.extension_item_uuid,
                        title: "4",
                        description: "Maximum number of participants in a group/channel/team call " \
                                      "(PlConnect::CallService). A plain WebRTC mesh needs n*(n-1) peer " \
                                      "connections per participant, so this value can only ever be lowered here, " \
                                      "never raised above PlConnectCallItem::MESH_PARTICIPANT_LIMIT - going " \
                                      "higher would require a media server (SFU) and is out of scope. No " \
                                      "personal data of its own; only caps how many already-authorized " \
                                      "conversation members may join the same call."
                      })

    YamlHelper.update_yaml(c: @c, reference_model: LookupItem, reference_id: old_group.id,
      auto_translate: SYSTEM&.dig(:language, :auto_translate_in_another_yml_files))
    sleep 3
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end
end
