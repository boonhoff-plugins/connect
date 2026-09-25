# frozen_string_literal: true

# PlConnectWorkspaceHelper
#
# View helpers for the Connect workspace shell. Kept small on purpose: anything
# that touches authorization or persistence belongs into the service layer
# (PlConnect::*), not into a helper.
module PlConnectWorkspaceHelper
  # Formats the timestamp of the last message for the conversation sidebar.
  #
  # The serializer emits ISO-8601 strings so the REST feed, the ActionCable
  # broadcast and this server-rendered list all share one shape. Parsing it back
  # here is the price for that single shape and is cheap compared to keeping two
  # different representations in sync.
  #
  # Output follows the usual messenger convention:
  #   today      -> time only            (14:05)
  #   this week  -> abbreviated weekday   (Tue)
  #   older      -> short date            (12.03.2026)
  def pl_connect_relative_time(iso_string)
    return "" if iso_string.blank?

    time = Time.zone.parse(iso_string.to_s)
    return "" if time.blank?

    today = Time.zone.today
    if time.to_date == today
      I18n.l(time, format: :pl_connect_time, default: "%H:%M")
    elsif time.to_date > (today - 7)
      I18n.l(time.to_date, format: :pl_connect_weekday, default: "%a")
    else
      I18n.l(time.to_date, format: :pl_connect_date, default: "%d.%m.%Y")
    end
  rescue ArgumentError, TypeError
    # A malformed timestamp must never take the whole sidebar down.
    ""
  end

  # Short, deterministic avatar label for a conversation.
  # Group conversations get an icon instead, so this is only used for 1:1 chats
  # and always derives from data the viewer is already allowed to see.
  def pl_connect_initials(title)
    parts = title.to_s.strip.split(/[\s._-]+/).reject(&:blank?)
    return "?" if parts.empty?

    (parts.size == 1 ? parts.first.first(2) : parts.first(2).map { |p| p.first(1) }.join).upcase
  end

  # Font Awesome icon for a conversation type.
  def pl_connect_conversation_icon(f_type)
    case f_type.to_s
    when "team"    then "fa-solid fa-people-group"
    when "channel" then "fa-solid fa-hashtag"
    when "group"   then "fa-solid fa-user-group"
    else                "fa-solid fa-user"
    end
  end

  # Translated strings the chat Stimulus controller needs at runtime.
  #
  # Handed over as one Stimulus Object value instead of a dozen data
  # attributes, and built here rather than in the view so the key list stays in
  # one place. Everything in here is a static translation - no user data, no
  # configuration secrets - so it is safe to embed into the page.
  #
  # The controller reads these keys; adding one here without using it is
  # harmless, removing one that is used shows an empty string rather than
  # raising.
  def pl_connect_chat_i18n
    {
      today: I18n.t("pl_connect.chat.today"),
      yesterday: I18n.t("pl_connect.chat.yesterday"),
      edited: I18n.t("pl_connect.chat.edited"),
      react: I18n.t("pl_connect.chat.react"),
      edit: I18n.t("pl_connect.chat.edit"),
      delete: I18n.t("pl_connect.chat.delete"),
      confirm_delete: I18n.t("pl_connect.chat.confirm_delete"),
      messages: I18n.t("pl_connect.chat.messages"),
      composer_placeholder: I18n.t("pl_connect.chat.composer_placeholder"),
      typing_one: I18n.t("pl_connect.chat.typing_one"),
      typing_many: I18n.t("pl_connect.chat.typing_many"),
      no_results: I18n.t("pl_connect.chat.no_results"),
      people_heading: I18n.t("pl_connect.chat.people_heading"),
      messages_heading: I18n.t("pl_connect.chat.messages_heading"),
      load_failed: I18n.t("pl_connect.chat.load_failed"),
      send_failed: I18n.t("pl_connect.chat.send_failed"),
      session_expired: I18n.t("pl_connect.chat.session_expired"),
      type_direct: I18n.t("pl_connect.chat.type.direct"),
      type_group: I18n.t("pl_connect.chat.type.group"),
      type_team: I18n.t("pl_connect.chat.type.team"),
      type_channel: I18n.t("pl_connect.chat.type.channel"),
      # System messages are stored as a stable key plus a payload and are
      # rendered in each reader's own language, so the sentence has to be
      # resolved on the client.
      system: I18n.t("pl_connect.chat.system")
    }
  end

  # Translated presence labels for the presence Stimulus controller.
  def pl_connect_presence_i18n
    {
      unknown: I18n.t("pl_connect.presence.unknown"),
      online: I18n.t("pl_connect.presence.online"),
      away: I18n.t("pl_connect.presence.away"),
      busy: I18n.t("pl_connect.presence.busy"),
      dnd: I18n.t("pl_connect.presence.dnd"),
      offline: I18n.t("pl_connect.presence.offline")
    }
  end

  # Translated strings and STUN/TURN configuration for the call Stimulus
  # controller. ice_servers is embedded here (rather than fetched separately)
  # so a call can be answered from an incoming-call banner without an extra
  # round trip - PlConnectApiController#start_call/#answer_call return the same
  # value again for the caller side and for a page reload mid-call.
  def pl_connect_call_i18n
    {
      ringing: I18n.t("pl_connect.call.ringing"),
      connecting: I18n.t("pl_connect.call.connecting"),
      connected: I18n.t("pl_connect.call.connected"),
      incoming_call: I18n.t("pl_connect.call.incoming_call"),
      accept: I18n.t("pl_connect.call.accept"),
      decline: I18n.t("pl_connect.call.decline"),
      hangup: I18n.t("pl_connect.call.hangup"),
      mute: I18n.t("pl_connect.call.mute"),
      unmute: I18n.t("pl_connect.call.unmute"),
      camera_on: I18n.t("pl_connect.call.camera_on"),
      camera_off: I18n.t("pl_connect.call.camera_off"),
      share_screen: I18n.t("pl_connect.call.share_screen"),
      stop_share: I18n.t("pl_connect.call.stop_share"),
      expand: I18n.t("pl_connect.call.expand"),
      collapse: I18n.t("pl_connect.call.collapse"),
      call_ended: I18n.t("pl_connect.call.call_ended"),
      call_declined: I18n.t("pl_connect.call.call_declined"),
      call_missed: I18n.t("pl_connect.call.call_missed"),
      call_failed: I18n.t("pl_connect.call.call_failed"),
      media_error: I18n.t("pl_connect.call.media_error"),
      start_audio_call: I18n.t("pl_connect.call.start_audio_call"),
      start_video_call: I18n.t("pl_connect.call.start_video_call"),
      recording_voicemail: I18n.t("pl_connect.call.recording_voicemail"),
      voicemail_greeting: I18n.t("pl_connect.call.voicemail_greeting"),
      invite: I18n.t("pl_connect.call.invite"),
      invite_search_placeholder: I18n.t("pl_connect.call.invite_search_placeholder"),
      invite_no_results: I18n.t("pl_connect.call.invite_no_results"),
      invite_search_no_results: I18n.t("pl_connect.call.invite_search_no_results"),
      invite_error: I18n.t("pl_connect.call.invite_error")
    }
  end

  # JSON payload for the call Stimulus controller's "resume" value: the call
  # this user is still an active (non-left) participant of, if any (see
  # PlConnect::CallService.resumable_call_for), so a fresh controller mount
  # can silently rejoin instead of just dropping the call. Empty string (not
  # "null") when there is nothing to resume, matching the blank-safe
  # convention already used by pl_connect_pending_call.
  def pl_connect_call_resume_payload(user)
    call = PlConnect::CallService.resumable_call_for(user)
    return "" if call.blank? || call.chat_item.blank?

    participant = call.participant_for(user)
    {
      uuid: call.uuid,
      chat_uuid: call.chat_item.uuid,
      video_active: participant.present? && participant.video_active == true
    }.to_json
  end

  # Translated strings for the shared "pick a colleague" modal (conversation
  # sidebar's "+" button and the Calls surface's start-call buttons).
  def pl_connect_user_picker_i18n
    {
      title: I18n.t("pl_connect.user_picker.title"),
      search_placeholder: I18n.t("pl_connect.user_picker.search_placeholder"),
      no_results: I18n.t("pl_connect.user_picker.no_results"),
      error: I18n.t("pl_connect.user_picker.error"),
      session_expired: I18n.t("pl_connect.chat.session_expired")
    }
  end

  # Translated strings for the main-app shell widget's new-message toast (see
  # extension_shell_widgets/_pl_connect.html.erb and
  # pl_connect_shell_controller.js). Kept separate from pl_connect_chat_i18n
  # because the shell widget never mounts pl-connect-chat.
  def pl_connect_shell_i18n
    {
      new_message: I18n.t("pl_connect.shell.new_message")
    }
  end
end
