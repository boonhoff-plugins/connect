# frozen_string_literal: true

# AddPlConnectCallAudioConfig
#
# Configuration for the call-audio feedback feature (ringtone for the callee,
# ringback tone for the caller) and the voicemail feature (an unanswered
# direct call auto-transitions to a recording prompt after a configurable
# timeout - see PlConnect::CallVoicemailTimeoutJob and
# PlConnect::CallService#voicemail_active? and friends).
#
# == Placement under lookup_item 3699 ("pl_connect_connect"), not under
#    "pl_connect_chat_item"
# Every existing call-related switch (webrtc_calls_active, webrtc_stun_urls,
# webrtc_mesh_participant_limit, ...) lives under the "pl_connect_chat_item"
# plugin_group (see AddPlConnectConfigLookupItems /
# AddPlConnectMeshParticipantLimitLookupItem), simply because that group
# existed first and every earlier PLUGIN&.dig(...) fallback happened to be
# read from there. "pl_connect_connect" (uuid below) is the plugin's own
# top-level "Connect" group and, unlike pl_connect_chat_item/pl_connect_call_item,
# had no children of its own yet. Ringtone/ringback/voicemail are behavioural,
# cross-cutting UX settings rather than a technical property of one data model
# (ChatItem or CallItem) - they are given their own home here so this group
# can grow into the natural place for future plugin-wide (not model-specific)
# behaviour switches, instead of continuing to overload pl_connect_chat_item.
#
# LookupItemConfigHelper#parse_value reads the *title* as the value - f_type
# decides how it is parsed: "boolean_lookup" -> title "true"/"false",
# "integer_lookup" -> title.to_i.
class AddPlConnectCallAudioConfig < ActiveRecord::Migration[8.1]
  # uuid of the "pl_connect_connect" plugin_configuration group (id 3699) -
  # looked up by uuid rather than by yaml_key, same reasoning as
  # AddPlConnectConfigLookupItems::CONTROLLER_GROUP_UUID.
  CONTROLLER_GROUP_UUID = "69e28912-948f-494e-b514-d223a9718275--lookup_item--20260828211521"

  ITEMS = [
    {
      uuid: "367ef005-c0ee-4fb0-888f-6d2c00541927--lookup_item--20260922100000",
      name: "ringtone_active", f_type: "boolean_lookup", title: "true",
      description: "Plays an incoming-call ringtone (generated in the browser via the Web Audio API - no audio " \
                   "file involved) for the callee while a direct call is ringing, so an incoming call is not only " \
                   "visible but also audible. Deactivating this only silences the tone; the incoming-call banner " \
                   "itself is unaffected."
    },
    {
      uuid: "dfc781e0-88e0-4085-8005-42ece87cb17d--lookup_item--20260922100000",
      name: "ringback_active", f_type: "boolean_lookup", title: "true",
      description: "Plays a ringback tone (generated in the browser, same mechanism as ringtone_active) for the " \
                   "caller while their outgoing direct call is ringing, as audible feedback that the call is " \
                   "actually progressing and not stalled."
    },
    {
      uuid: "1c6d1f68-c0d9-4b2f-8b6a-c0c7df26c972--lookup_item--20260922100000",
      name: "voicemail_active", f_type: "boolean_lookup", title: "true",
      description: "Master switch for the voicemail feature (PlConnect::CallVoicemailTimeoutJob). When active, a " \
                   "direct call that rings unanswered for voicemail_timeout_seconds automatically ends as missed " \
                   "and prompts the caller to leave a recorded message, which is delivered to the callee as a " \
                   "normal chat message with an audio attachment. Deactivating this leaves an unanswered call " \
                   "ringing indefinitely until either side hangs up, matching the behaviour before this feature " \
                   "existed."
    },
    {
      uuid: "dc65652d-87f9-42cd-812a-a0b2fb84a501--lookup_item--20260922100000",
      name: "voicemail_timeout_seconds", f_type: "integer_lookup", title: "30",
      description: "Seconds an unanswered direct call keeps ringing before PlConnect::CallVoicemailTimeoutJob ends " \
                   "it as missed and prompts the caller to leave a voicemail. Only relevant while voicemail_active " \
                   "is on."
    },
    {
      uuid: "989822c4-3b08-4c37-af8b-23916404958a--lookup_item--20260922100000",
      name: "voicemail_max_duration_seconds", f_type: "integer_lookup", title: "120",
      description: "Maximum recording length, in seconds, of a single voicemail message - the browser stops " \
                   "recording and uploads automatically once this is reached. Bounds both the caller's own upload " \
                   "size and the storage taken up by the resulting DataItem (see PlConnect::AttachmentService)."
    }
  ].freeze

  def up
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    controller_group = LookupItem.find_by(uuid: CONTROLLER_GROUP_UUID, del_flag: 0, active: 1)
    return puts "  [SKIP] pl_connect_connect lookup group not found." if controller_group.blank?

    admin_roles = Role.where(name: [ "admin" ])
    ITEMS.each { |attrs| _create_config_item(attrs, controller_group, admin_roles) }
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
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

  # Creates (or updates) a single config LookupItem under the controller group,
  # then grants the admin roles visibility on it via LookupItemJoinRole.
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

  # Idempotently ensures a LookupItemJoinRole exists between the given
  # lookup_item and role.
  def _grant_role(lookup_item, role)
    join = LookupItemJoinRole.find_or_initialize_by(lookup_item_id: lookup_item.id, role_id: role.id)
    join.save_element(c: @c, element: {
                        lookup_item_id: lookup_item.id, lookup_item_uuid: lookup_item.uuid,
                        role_id: role.id, role_uuid: role.uuid
                      })
  end
end
