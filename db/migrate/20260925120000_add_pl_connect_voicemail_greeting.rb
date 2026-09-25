# frozen_string_literal: true

# AddPlConnectVoicemailGreeting
#
# Adds the spoken announcement played before voicemail recording starts (see
# PlConnect::CallVoicemailTimeoutJob / pl_connect_call_controller.js#playVoicemailGreeting)
# as a file_lookup LookupItem, child of lookup_item 3699 ("pl_connect_connect",
# same group as AddPlConnectCallAudioConfig's ringtone/ringback/voicemail
# switches) - an administrator can replace the mp3 at any time by uploading a
# new file onto this item, no deploy required. Seeded with a placeholder
# English announcement ("The person you are trying to reach is not available
# right now. Please leave a message after the tone.") synthesised via TTS.
#
# The blob is set directly (not through save_element's upload handling, which
# only fires for an ActionDispatch::Http::UploadedFile) using the same
# compressed-binary shape SaveOriginalModelConcern#process_file_upload would
# have produced from a real upload - see LookupItem#file_content, which
# decompresses it again, and PlConnect::CallService.voicemail_greeting_audio,
# which fetches it live (never cached in PLUGIN, same reasoning as any other
# file_lookup/password_lookup value).
class AddPlConnectVoicemailGreeting < ActiveRecord::Migration[8.1]
  CONTROLLER_GROUP_UUID = "69e28912-948f-494e-b514-d223a9718275--lookup_item--20260828211521"
  ITEM_UUID = "86ad3ff6-8cc5-4e7d-aded-64e5d7ea6660--lookup_item--20260925120000"
  ASSET_PATH = File.join(__dir__, "seed_files", "voicemail_greeting_en.mp3")

  def up
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    controller_group = LookupItem.find_by(uuid: CONTROLLER_GROUP_UUID, del_flag: 0, active: 1)
    return puts "  [SKIP] pl_connect_connect lookup group not found." if controller_group.blank?
    return puts "  [SKIP] seed audio file not found at #{ASSET_PATH}." unless File.exist?(ASSET_PATH)

    audio = File.binread(ASSET_PATH)

    item = LookupItem.find_or_initialize_by(uuid: ITEM_UUID)
    result = item.save_element(c: @c, check_uuid: false, element: {
                                 name: "voicemail_greeting_audio", f_type: "file_lookup",
                                 description: "Spoken announcement played before voicemail recording starts (see " \
                                              "PlConnect::CallVoicemailTimeoutJob). Upload a different audio file " \
                                              "here to replace it - only relevant while voicemail_active is on.",
                                 parent_id: controller_group.id, parent_uuid: controller_group.uuid,
                                 extension_item_id: controller_group.extension_item_id,
                                 extension_item_uuid: controller_group.extension_item_uuid,
                                 file_data: Zlib::Deflate.deflate(audio),
                                 file_data_compressed: true,
                                 file_data_content_type: "audio/mpeg",
                                 file_data_file_name: "voicemail_greeting_en.mp3"
                               })

    return puts "  [ERROR] voicemail_greeting_audio: #{result[:successful_text]}" unless result[:successful]

    admin_role = Role.find_by(name: "admin")
    if admin_role.present?
      join = LookupItemJoinRole.find_or_initialize_by(lookup_item_id: result[:element].id, role_id: admin_role.id)
      join.save_element(c: @c, element: {
                          lookup_item_id: result[:element].id, lookup_item_uuid: result[:element].uuid,
                          role_id: admin_role.id, role_uuid: admin_role.uuid
                        })
    end

    puts "  [OK] voicemail_greeting_audio"
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
    item = LookupItem.find_by(uuid: ITEM_UUID)
    return if item.blank?

    LookupItemJoinRole.where(lookup_item_id: item.id).destroy_all
    item.destroy
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end
end
