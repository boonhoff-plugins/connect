# frozen_string_literal: true

module PlConnect
  # CallService
  #
  # The single write path for audio/video calls (PlConnectCallItem), mirroring
  # MessageComposer for messages: controllers must go through here instead of
  # calling save_element on PlConnectCallItem/PlConnectCallItemJoinUser
  # directly.
  #
  # == Scope
  # A 1:1 conversation (chat_item.f_type == "direct") starts a "direct_call":
  # the other member is invited and the call rings until accepted/declined.
  # A group/channel/team conversation starts a "conference" call instead: it
  # becomes active immediately with only the initiator in it. Unlike a direct
  # call, starting or joining a conference never rings anyone by itself - it
  # only shows up as a "started a call"/"call.active" system message for
  # whoever has that conversation open, and as the call_active flag on the
  # conversation otherwise, so a member who wants in can press the same call
  # button themselves (#start, above, then joins via #accept since the call is
  # already running). Ringing a specific person - the callee of a direct call,
  # or a conference member who is not currently looking at the conversation -
  # is always the explicit #invite below, never automatic. Both call types are
  # a plain WebRTC mesh (see PlConnectCallItem::MESH_PARTICIPANT_LIMIT for why
  # that caps out at a handful of participants) and share every method below;
  # #accept in particular does double duty as both "answer an invite" and
  # "join a running conference".
  #
  # == Two independent real time channels
  #   * the *chat* stream (ChatBroadcaster#call_state) carries the call's
  #     lifecycle (started/accepted/declined/ended) to every member of the
  #     conversation, whether or not they are actually in the call — this is
  #     what lets a call show up as a system message in the history.
  #   * the *call* stream (PlConnectCallItem#stream_name / PlConnectCallChannel)
  #     carries the actual WebRTC signalling and is only ever joined by the
  #     call's participants.
  #
  # == GDPR note
  # A call record and its participants are personal data about who spoke with
  # whom and for how long (Art. 4 (1)). The legal basis is the same as for
  # messages themselves (performance of the employment/collaboration context);
  # no additional payload (audio/video/screen content) is ever persisted here —
  # only metadata (timestamps, state, mute/camera flags) leaves the browser.
  class CallService
    def initialize(c:, chat_item:, user:)
      @c = c
      @chat_item = chat_item
      @user = user
    end

    # Master switch, so an installation that does not want calls at all can
    # turn the feature off without removing the UI (same pattern as
    # PresenceService.active?).
    def self.active?
      value = PLUGIN&.dig(:pl_connect_chat_item, :webrtc_calls_active)
      return true if value.nil?

      ActiveModel::Type::Boolean.new.cast(value) ? true : false
    end

    # The call this user is still an active (non-left) participant of, if any.
    # Used so a fresh mount of the call Stimulus controller - a full page load,
    # e.g. reloading the workspace or leaving it via the rail's "Back" link
    # into the main application, both of which destroy the previous WebRTC/JS
    # state entirely - can silently rejoin instead of just dropping the call
    # (see PlConnectWorkspaceHelper#pl_connect_call_resume_payload).
    #
    # Only "active" calls qualify: a still-"ringing" call this user has not
    # yet answered is already covered by the ordinary incoming-call banner
    # (PlConnectPresenceChannel "call.invite"), not by this path.
    def self.resumable_call_for(user)
      return nil if user.blank?

      PlConnectCallItem
        .where(state: "active", del_flag: false)
        .joins(:pl_connect_call_item_join_users)
        .where(pl_connect_call_item_join_users: { user_id: user.id, del_flag: false, left_at: nil })
        .first
    end

    # STUN/TURN configuration handed to the browser's RTCPeerConnection.
    #
    # Follows the same "safe default, LookupItem creation deferred" precedent
    # as PlConnectApiController#page_size: PLUGIN.pl_connect_chat_item is read
    # directly with a hardcoded fallback (a public STUN server) rather than
    # requiring a LookupItem to exist before calls work at all. Turning this
    # into an administrable LookupItem (with its Art. 6 legal basis and
    # confidentiality notes for any TURN credential) is left to a later phase.
    #
    # GDPR note: STUN/TURN candidate gathering necessarily discloses each
    # participant's public IP address to the other participant (and, if a TURN
    # relay is configured, to the TURN operator) - this is an unavoidable
    # property of WebRTC connectivity establishment, not something this method
    # controls, and must be reflected in the eventual LookupItem description.
    def self.ice_servers
      stun_urls = PLUGIN&.dig(:pl_connect_chat_item, :webrtc_stun_urls).to_s
      stun_urls = "stun:stun.l.google.com:19302" if stun_urls.blank?
      servers = [ { urls: stun_urls.split(",").map(&:strip) } ]

      turn_urls = PLUGIN&.dig(:pl_connect_chat_item, :webrtc_turn_urls).to_s
      if turn_urls.present?
        servers << {
          urls: turn_urls.split(",").map(&:strip),
          username: PLUGIN&.dig(:pl_connect_chat_item, :webrtc_turn_username).to_s,
          credential: PLUGIN&.dig(:pl_connect_chat_item, :webrtc_turn_credential).to_s
        }
      end

      servers
    end

    # Maximum number of participants allowed in a mesh call, administrable via
    # the same "safe default, LookupItem creation deferred" precedent as
    # .ice_servers above. Never exceeds PlConnectCallItem::MESH_PARTICIPANT_LIMIT
    # regardless of what is configured - that constant is a technical ceiling
    # (n*(n-1) peer connections), not a policy the configuration is allowed to
    # raise.
    def self.mesh_participant_limit
      configured = PLUGIN&.dig(:pl_connect_chat_item, :webrtc_mesh_participant_limit).to_i
      configured = PlConnectCallItem::MESH_PARTICIPANT_LIMIT if configured <= 0
      [ configured, PlConnectCallItem::MESH_PARTICIPANT_LIMIT ].min
    end

    # Call-audio and voicemail configuration (see AddPlConnectCallAudioConfig).
    # Read from PLUGIN&.dig(:pl_connect_connect, ...) - a separate
    # plugin_group from the ChatItem-scoped settings above, deliberately: see
    # the migration's own comment for why.

    # Whether the callee hears an audible ringtone (generated client side via
    # the Web Audio API) while a direct call is ringing.
    def self.ringtone_active?
      value = PLUGIN&.dig(:pl_connect_connect, :ringtone_active)
      return true if value.nil?

      ActiveModel::Type::Boolean.new.cast(value) ? true : false
    end

    # Whether the caller hears an audible ringback tone while their own
    # outgoing direct call is ringing.
    def self.ringback_active?
      value = PLUGIN&.dig(:pl_connect_connect, :ringback_active)
      return true if value.nil?

      ActiveModel::Type::Boolean.new.cast(value) ? true : false
    end

    # Master switch for the voicemail feature (see CallVoicemailTimeoutJob).
    def self.voicemail_active?
      value = PLUGIN&.dig(:pl_connect_connect, :voicemail_active)
      return true if value.nil?

      ActiveModel::Type::Boolean.new.cast(value) ? true : false
    end

    # Seconds an unanswered direct call rings before voicemail kicks in.
    def self.voicemail_timeout_seconds
      configured = PLUGIN&.dig(:pl_connect_connect, :voicemail_timeout_seconds).to_i
      configured.positive? ? configured : 30
    end

    # Maximum length, in seconds, of a single voicemail recording.
    def self.voicemail_max_duration_seconds
      configured = PLUGIN&.dig(:pl_connect_connect, :voicemail_max_duration_seconds).to_i
      configured.positive? ? configured : 120
    end

    # uuid of the "voicemail_greeting_audio" file_lookup (see
    # AddPlConnectVoicemailGreeting) - referenced by fixed uuid, like
    # AddPlConnectCallAudioConfig's own group/item uuids, rather than by
    # yaml_key: the audio bytes are fetched live (see #voicemail_greeting_audio
    # below) and must never go through the PLUGIN yaml cache in the first
    # place (same memory-safety reasoning as LookupItem#file_content).
    GREETING_ITEM_UUID = "86ad3ff6-8cc5-4e7d-aded-64e5d7ea6660--lookup_item--20260925120000"

    # The configured greeting LookupItem, or nil when it was deleted.
    def self.voicemail_greeting_item
      LookupItem.find_by(uuid: GREETING_ITEM_UUID, del_flag: false, active: true)
    end

    # Live fetch of the greeting's audio bytes - played by
    # pl_connect_call_controller.js#playVoicemailGreeting before a voicemail
    # recording starts. An administrator can replace the announcement at any
    # time by uploading a new file onto this LookupItem; nil (no announcement
    # played, straight to the beep) when none is configured.
    def self.voicemail_greeting_audio
      voicemail_greeting_item&.file_content
    end

    def self.voicemail_greeting_content_type
      voicemail_greeting_item&.file_data_content_type.presence || "audio/mpeg"
    end

    # Starts a new call, or joins/returns the one already running in this
    # conversation — a second click on the call button must never create a
    # second, competing PlConnectCallItem, and a group member clicking it
    # while a conference is already running simply joins that conference.
    def start
      return _failure("Conversation not found.") if @chat_item.blank?
      return _failure("You are not a member of this conversation.") unless @chat_item.member?(@user)
      return _failure("Calls are disabled for this installation.") unless self.class.active?

      running = @chat_item.running_call
      return accept(call: running) if running.present?

      @chat_item.f_type == "direct" ? _start_direct_call : _start_group_call
    rescue StandardError => e
      _handle_exception(e, "start")
    end

    # Callee response to a direct-call invite, or a conversation member
    # joining an already-running conference call - both end up as an active
    # participant of `call`, the only difference is whether a participant row
    # already exists (invited) or must be created (joining).
    def accept(call:)
      return _failure("Call not found.") if call.blank?

      participant = call.participant_for(@user)

      if participant.blank?
        return _failure("You are not a member of this conversation.") unless @chat_item.member?(@user)
        return _failure("This call has already ended.") unless call.running?
        return _failure("This call is full.") if call.full?

        add_result = _add_participant(call, @user, connection_state: "connecting", joined_at: Time.current)
        return add_result unless add_result[:successful]
      else
        update_result = participant.save_element(c: @c, element: {
          connection_state: "connecting",
          joined_at: participant.joined_at || Time.current,
          left_at: nil
        })
        return update_result unless update_result[:successful]
      end

      if call.state == "ringing"
        call_result = call.save_element(c: @c, element: { state: "active", started_at: call.started_at || Time.current })
        return call_result unless call_result[:successful]

        call = call_result[:element]
      end

      ChatBroadcaster.call_state(chat_item: @chat_item, call_item: call.reload, action: "accepted",
                                  extra: { user_uuid: @user.uuid })
      _resolve_invite(call, user: @user)

      { successful: true, successful_text: nil, element: call }
    rescue StandardError => e
      _handle_exception(e, "accept")
    end

    def decline(call:)
      return _failure("Call not found.") if call.blank?

      participant = call.participant_for(@user)
      # Declining a conference invite you were never formally invited to (a
      # group notification, not a personal ringing invite) is a no-op: there
      # is no participant row to close and the call keeps running for
      # whoever is already in it.
      return { successful: true, successful_text: nil, element: call } if participant.blank?

      participant.save_element(c: @c, element: { connection_state: "closed", left_at: Time.current })

      # A direct call only ever has one other member: a decline always ends
      # it. _end_call already broadcasts call.declined and posts the system
      # message, so no separate broadcast is needed here.
      if call.state == "ringing"
        _end_call(call, reason: "declined")
      else
        ChatBroadcaster.call_state(chat_item: @chat_item, call_item: call, action: "declined",
                                    extra: { user_uuid: @user.uuid })
      end
      _resolve_invite(call, user: @user)

      { successful: true, successful_text: nil, element: call }
    rescue StandardError => e
      _handle_exception(e, "decline")
    end

    # Either side hanging up, at any point of the call. For a direct call this
    # always ends it (there is no one left to talk to). For a conference it
    # only ends the call once the last remaining participant leaves -
    # otherwise it just removes this one participant and keeps running for
    # everyone else.
    def hangup(call:)
      return _failure("Call not found.") if call.blank?

      was_ringing = call.state == "ringing"
      participant = call.participant_for(@user)
      participant&.save_element(c: @c, element: { connection_state: "closed", left_at: Time.current })

      ChatBroadcaster.call_state(chat_item: @chat_item, call_item: call, action: "left",
                                  extra: { user_uuid: @user.uuid })

      if %w[ringing active].include?(call.state)
        _end_call(call, reason: was_ringing ? "missed" : "ended") if @chat_item.f_type == "direct" || call.active_participants.count.zero?
      end

      { successful: true, successful_text: nil, element: call }
    rescue StandardError => e
      _handle_exception(e, "hangup")
    end

    # Persists a mute/camera/screen-share toggle and relays it on the call
    # stream. Called from the REST API (not the ActionCable channel) so the
    # write goes through the same, properly built `c` as every other save —
    # see PlConnectCallChannel for why channel actions deliberately do not
    # write to the database themselves.
    def update_media_state(call:, audio_active:, video_active:, screen_active:)
      return _failure("Call not found.") if call.blank?

      participant = call.participant_for(@user)
      return _failure("You are not a participant of this call.") if participant.blank?

      cast = ActiveModel::Type::Boolean.new
      result = participant.save_element(c: @c, element: {
        audio_active: cast.cast(audio_active),
        video_active: cast.cast(video_active),
        screen_active: cast.cast(screen_active)
      })
      return result unless result[:successful]

      participant = result[:element]

      ActionCable.server.broadcast(call.stream_name, {
        event: "media_state",
        call_uuid: call.uuid,
        user_uuid: @user.uuid,
        audio_active: participant.audio_active,
        video_active: participant.video_active,
        screen_active: participant.screen_active
      })

      result
    rescue StandardError => e
      _handle_exception(e, "update_media_state")
    end

    # Rings one specific conversation member into this already-running call -
    # the only path that ever rings anyone for a conference (see the class
    # doc above): starting or joining one yourself never does. Also usable on
    # a direct call to re-ring a partner who left/declined earlier, as long as
    # the call itself is still running and not already full.
    #
    # @user must already be an active participant of the call themselves -
    # inviting people into a call you are not even in yourself would let
    # anyone with the chat/call uuids ring an arbitrary conversation member
    # without ever having joined.
    def invite(call:, target_user:)
      return _failure("Call not found.") if call.blank?
      return _failure("This call has already ended.") unless call.running?
      return _failure("This call is full.") if call.full?

      inviter_participant = call.participant_for(@user)
      return _failure("You must be in the call to invite someone.") if inviter_participant.blank? || inviter_participant.left_at.present?

      # target_user no longer has to already be a member of this conversation -
      # the tenant-wide directory search (see #invitable_members below) lets
      # you ring in any colleague, so they are added as a conversation member
      # here on demand. A "direct" (1:1) conversation cannot gain a third
      # member though - #full? already rejects this in practice since a direct
      # call's max_participants is 2, but this gives a clearer message.
      unless @chat_item.member?(target_user)
        return _failure("You cannot add another person to a one-to-one call.") if @chat_item.f_type == "direct"

        add_member_result = @chat_item.add_member(c: @c, user: target_user, membership_role: "member")
        return add_member_result unless add_member_result[:successful]
      end

      existing = call.participant_for(target_user)
      if existing.present?
        return _failure("That person is already in the call.") if existing.left_at.nil?

        update_result = existing.save_element(c: @c, element: { connection_state: "invited", left_at: nil })
        return update_result unless update_result[:successful]
      else
        add_result = _add_participant(call, target_user, connection_state: "invited")
        return add_result unless add_result[:successful]
      end

      _notify_invitee(call, target_user)
      { successful: true, successful_text: nil, element: call }
    rescue StandardError => e
      _handle_exception(e, "invite")
    end

    # Candidates for #invite above. With no search term this is the previous,
    # unchanged quick list: conversation members who are not already an active
    # (non-left) participant of `call`. Once the caller types a search term it
    # widens to the same tenant-wide directory search behind the "new chat"
    # picker (ConversationResolver#searchable_users) minus current call
    # participants, so a colleague who was never part of this conversation can
    # be rung in too - #invite adds them as a conversation member on demand.
    def invitable_members(call:, term: nil)
      return User.none if call.blank?

      active_ids = call.active_participants.select(:user_id)
      clean_term = term.to_s.strip

      scope =
        if clean_term.present?
          ConversationResolver.new(c: @c, user: @user).searchable_users(term: clean_term, limit: 20)
        else
          User.where(id: @chat_item.active_memberships.select(:user_id))
        end

      scope.where.not(id: active_ids)
    end

    private

    def _start_direct_call
      partner = @chat_item.partner_for(@user)
      return _failure("This conversation has no other member to call.") if partner.blank?

      result = PlConnectCallItem.new.save_element(c: @c, element: {
        chat_item_id: @chat_item.id,
        chat_item_uuid: @chat_item.uuid,
        f_type: "direct_call",
        state: "ringing",
        room_key: PlConnectCallItem.generate_room_key,
        initiator_user_id: @user.id,
        initiator_user_uuid: @user.uuid,
        max_participants: 2,
        tenant_id: @chat_item.tenant_id,
        tenant_uuid: @chat_item.tenant_uuid
      })
      return result unless result[:successful]

      call = result[:element]

      _add_participant(call, @user, connection_state: "connecting", joined_at: Time.current)
      _add_participant(call, partner, connection_state: "invited")

      @chat_item.save_element(c: @c, element: { call_active: true })

      ChatBroadcaster.call_state(chat_item: @chat_item, call_item: call, action: "started")
      _notify_invitee(call, partner)
      composer.create_system(event_key: "call.started", payload: { login: @user.login.to_s }, call_item_uuid: call.uuid)
      _schedule_voicemail_timeout(call)

      { successful: true, successful_text: nil, element: call }
    end

    # A conference call becomes active immediately with only the initiator in
    # it - there is no "ringing" state for a group, since there is no single
    # callee to ring. Nobody is notified/rung automatically (see the class doc
    # above and #invite below); other members join in via #accept whenever
    # they open the conversation and press the call button themselves, up to
    # CallService.mesh_participant_limit.
    def _start_group_call
      result = PlConnectCallItem.new.save_element(c: @c, element: {
        chat_item_id: @chat_item.id,
        chat_item_uuid: @chat_item.uuid,
        f_type: "conference",
        state: "active",
        started_at: Time.current,
        room_key: PlConnectCallItem.generate_room_key,
        initiator_user_id: @user.id,
        initiator_user_uuid: @user.uuid,
        max_participants: self.class.mesh_participant_limit,
        tenant_id: @chat_item.tenant_id,
        tenant_uuid: @chat_item.tenant_uuid
      })
      return result unless result[:successful]

      call = result[:element]

      _add_participant(call, @user, connection_state: "connecting", joined_at: Time.current)
      @chat_item.save_element(c: @c, element: { call_active: true })

      ChatBroadcaster.call_state(chat_item: @chat_item, call_item: call, action: "started")
      composer.create_system(event_key: "call.started", payload: { login: @user.login.to_s }, call_item_uuid: call.uuid)

      { successful: true, successful_text: nil, element: call }
    end

    def _add_participant(call, user, connection_state:, joined_at: nil)
      PlConnectCallItemJoinUser.new.save_element(c: @c, element: {
        pl_connect_call_item_id: call.id,
        pl_connect_call_item_uuid: call.uuid,
        user_id: user.id,
        user_uuid: user.uuid,
        tenant_id: @chat_item.tenant_id,
        tenant_uuid: @chat_item.tenant_uuid,
        connection_state: connection_state,
        joined_at: joined_at,
        left_at: nil
      })
    end

    def _end_call(call, reason:)
      duration = call.started_at.present? ? (Time.current - call.started_at).round : 0

      result = call.save_element(c: @c, element: {
        state: reason,
        ended_at: Time.current,
        duration_seconds: duration
      })
      return unless result[:successful]

      call = result[:element]
      @chat_item.save_element(c: @c, element: { call_active: false })

      ChatBroadcaster.call_state(chat_item: @chat_item, call_item: call, action: reason)
      # @user is the person taking the action for "ended"/"declined" (they are
      # the one hanging up/declining), but for "missed" it is the original
      # caller (see CallVoicemailTimeoutJob, which hangs up as the initiator) -
      # so login is passed for all three reasons, but only interpolated into
      # the "call.ended"/"call.declined" locale strings, not "call.missed",
      # where it would misleadingly read as if the caller missed their own call.
      composer.create_system(event_key: "call.#{reason}", payload: { login: @user.login.to_s, duration_seconds: duration }, call_item_uuid: call.uuid)

      # Anyone still "invited" (ringing, not yet answered) when the call ends -
      # e.g. the voicemail timeout job marking an unanswered direct call
      # "missed", or the caller hanging up before the callee ever answered -
      # must stop ringing in every tab they have open, not just wait for the
      # chat-stream broadcast above (which only reaches tabs that already have
      # this exact conversation open, see _resolve_invite).
      call.participants.where(connection_state: "invited", left_at: nil).find_each do |participant|
        _resolve_invite(call, user: participant.user)
      end
    end

    def _notify_invitee(call, partner)
      return if partner.uuid.blank?

      PlConnectPresenceChannel.notify(
        user_uuid: partner.uuid,
        event: "call.invite",
        payload: {
          call_uuid: call.uuid,
          chat_uuid: @chat_item.uuid,
          chat_title: @chat_item.display_title_for(partner),
          caller_login: @user.login.to_s
        }
      )
    rescue StandardError => e
      Rails.logger.error "PlConnect::CallService#_notify_invitee: #{e.class}: #{e.message}"
    end

    # Tells every browser tab/window this user currently has open (not just
    # whichever one answered) to stop ringing for this call. The presence
    # stream reaches all of a user's tabs (see PlConnectPresenceChannel),
    # unlike the chat stream used by ChatBroadcaster.call_state above, which
    # only reaches tabs that already have this exact conversation open -
    # without this, accepting or declining a call in one tab left every other
    # open tab/window ringing indefinitely.
    def _resolve_invite(call, user:)
      return if user.blank? || user.uuid.blank?

      PlConnectPresenceChannel.notify(user_uuid: user.uuid, event: "call.invite_resolved",
                                      payload: { call_uuid: call.uuid })
    rescue StandardError => e
      Rails.logger.error "PlConnect::CallService#_resolve_invite: #{e.class}: #{e.message}"
    end

    # Schedules CallVoicemailTimeoutJob to end this (still ringing) direct
    # call as missed and prompt the caller for a voicemail if nobody answers
    # in time. The job itself re-checks call.state before doing anything, so
    # it is a no-op if the call was already accepted/declined/hung up before
    # it runs - no cancellation bookkeeping is needed here.
    def _schedule_voicemail_timeout(call)
      return unless self.class.voicemail_active?

      PlConnect::CallVoicemailTimeoutJob
        .set(wait: self.class.voicemail_timeout_seconds.seconds)
        .perform_later(call_uuid: call.uuid)
    rescue StandardError => e
      Rails.logger.error "PlConnect::CallService#_schedule_voicemail_timeout: #{e.class}: #{e.message}"
    end

    def composer
      @composer ||= MessageComposer.new(c: @c, chat_item: @chat_item, user: @user)
    end

    def _failure(text)
      { successful: false, successful_text: text, element: nil }
    end

    # Never logs call metadata beyond class/message (GDPR Art. 5 (1) c) — same
    # discipline as MessageComposer#_handle_exception.
    def _handle_exception(error, context)
      Rails.logger.error "PlConnect::CallService##{context}: #{error.class}: #{error.message}"
      _failure("The call could not be processed.")
    end
  end
end
