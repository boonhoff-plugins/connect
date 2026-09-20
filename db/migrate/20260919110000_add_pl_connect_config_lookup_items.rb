# frozen_string_literal: true

# AddPlConnectConfigLookupItems
#
# Turns every plugin config value that was, until now, only read from
# `PLUGIN&.dig(:pl_connect_chat_item, :key)` with a hardcoded fallback (see
# PlConnect::PresenceService, PlConnect::AttachmentService, PlConnect::CallService,
# PlConnectApiController#page_size) into a real, administrable LookupItem under
# the "pl_connect_chat_item" group that the scaffolding generator already
# created (see 20260919070445_create_plugin_pl_connect_chat_item_202609190704.rb).
#
# Until this migration runs, an installation has no way to change these values
# without editing code - the fallback in each PLUGIN&.dig(...) call is the only
# behaviour that exists. Every title below is deliberately set to that exact
# fallback, so running this migration changes nothing observable; it only makes
# the value editable under Lookup Items going forward.
#
# LookupItemConfigHelper#parse_value reads the *title* as the value (not
# description!) - f_type decides how it is parsed: "boolean_lookup" -> title
# "true"/"false", "integer_lookup" -> title.to_i, "password_lookup" -> title
# (decrypted transparently), everything else -> the title string as-is.
class AddPlConnectConfigLookupItems < ActiveRecord::Migration[8.1]
  # Fixed uuid of the "pl_connect_chat_item" plugin_configuration group,
  # created once by the scaffolding generator - looked up by uuid rather than
  # by yaml_key, because yaml_key is recomputed from the full title chain on
  # every save_element and cannot be relied on to match what a migration
  # constructs by hand (see repo memory "yaml_key in DocumentationItem").
  CONTROLLER_GROUP_UUID = '56a615c0-de38-4b1c-a65d-03875ca24479--lookup_item--20260919090445'

  ITEMS = [
    {
      uuid: 'f08f20e6-50df-4ac8-8bee-3082848937b7--lookup_item--20260919110000',
      name: 'message_page_size', f_type: 'integer_lookup', title: '50',
      description: 'Number of messages fetched per page when a conversation is opened or scrolled back. ' \
                   'No personal data of its own; only affects pagination of already-authorized message data.'
    },
    {
      uuid: 'b0264bd9-0b51-4e78-a92c-25ab67205d13--lookup_item--20260919110000',
      name: 'max_attachment_size_mb', f_type: 'integer_lookup', title: '25',
      description: 'Maximum size, in megabytes, of a single chat attachment upload. Uploads above this size are rejected ' \
                   'before the file is written to storage.'
    },
    {
      uuid: '0790f92a-632b-4a07-a020-d085a3550ce4--lookup_item--20260919110000',
      name: 'presence_active', f_type: 'boolean_lookup', title: 'true',
      description: 'Master switch for the online/away/busy presence indicator. Presence state is held in the Rails ' \
                   'cache only (PlConnect::PresenceService) and is never written to the database, so no movement ' \
                   'profile of a user can be reconstructed afterwards (Art. 5 (1)(e) DSGVO - Speicherbegrenzung). ' \
                   'Deactivating this hides the indicator without deleting any persisted data, because none exists.'
    },
    {
      uuid: '7644ad15-96e5-43c8-bf16-e1c496a90f77--lookup_item--20260919110000',
      name: 'presence_ttl_seconds', f_type: 'integer_lookup', title: '75',
      description: 'Seconds a presence heartbeat stays valid in the cache before the user is considered offline. ' \
                   "Must stay above the client's heartbeat interval (currently 30s) or a user will flicker offline " \
                   'between two beats.'
    },
    {
      uuid: '00cea55c-609c-467d-945e-34bf2fdc7342--lookup_item--20260919110000',
      name: 'webrtc_calls_active', f_type: 'boolean_lookup', title: 'true',
      description: 'Master switch for 1:1 audio/video calls and screen sharing (PlConnect::CallService). Deactivating ' \
                   'this rejects new calls but does not affect already-persisted call history (PlConnectCallItem).'
    },
    {
      uuid: 'f7156535-baea-4b02-8548-729ea5927403--lookup_item--20260919110000',
      name: 'webrtc_stun_urls', f_type: 'lookup', title: 'stun:stun.l.google.com:19302',
      description: "Comma-separated STUN server URL(s) handed to the browser's RTCPeerConnection for call " \
                   'connectivity. DSGVO note (Art. 6 DSGVO): establishing a WebRTC connection necessarily discloses ' \
                   "each participant's public IP address to the STUN server operator and to the other participant - " \
                   'this is an unavoidable property of the ICE protocol, not something this setting controls. The ' \
                   'default points at a public Google STUN server; set this to an in-house STUN server if that ' \
                   'disclosure to a third party is not acceptable.'
    },
    {
      uuid: 'c5320dd0-6f2a-4b62-b67f-1f2877921c2a--lookup_item--20260919110000',
      name: 'webrtc_turn_urls', f_type: 'lookup', title: '',
      description: 'Comma-separated TURN server URL(s), only used as a relay fallback when a direct/STUN connection ' \
                   'cannot be established (e.g. behind symmetric NAT). Left blank by default - without a TURN server ' \
                   'configured, such calls simply fail to connect rather than being relayed through a third party. ' \
                   "DSGVO note (Art. 6 DSGVO): a configured TURN relay additionally discloses both participants' " \
                   'media traffic metadata and IP addresses to the TURN operator for the duration of the call.'
    },
    {
      uuid: 'f721d123-4225-4774-9bf4-4042ad9a691e--lookup_item--20260919110000',
      name: 'webrtc_turn_username', f_type: 'lookup', title: '',
      description: 'Username for the TURN server configured in webrtc_turn_urls. Only relevant if a TURN server is set.'
    },
    {
      uuid: 'bb86725a-88b0-4a7d-9d31-8f1b7b1b9431--lookup_item--20260919110000',
      name: 'webrtc_turn_credential', f_type: 'password_lookup', title: '',
      description: 'Credential (password/shared secret) for the TURN server configured in webrtc_turn_urls. ' \
                   'Confidential - stored as a password_lookup value (decrypted transparently on read), never shown ' \
                   'in plain text once set. Only relevant if a TURN server is configured.'
    }
  ].freeze

  def up
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    controller_group = LookupItem.find_by(uuid: CONTROLLER_GROUP_UUID, del_flag: 0, active: 1)
    return puts '  [SKIP] pl_connect_chat_item lookup group not found.' if controller_group.blank?

    admin_roles = Role.where(name: ['admin'])
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
