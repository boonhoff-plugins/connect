# frozen_string_literal: true

module PlConnect
  # CallVoicemailTimeoutJob
  #
  # Scheduled once per outgoing direct call (see CallService#_schedule_voicemail_timeout)
  # to fire voicemail_timeout_seconds after the call started ringing. Re-checks
  # the call's state before doing anything, so it is a harmless no-op if the
  # call was already accepted, declined, or hung up in the meantime - no
  # cancellation bookkeeping (e.g. storing the job's provider_job_id) is
  # needed for that reason.
  #
  # Ends the call through the normal CallService#hangup path (as the
  # initiator) rather than duplicating its "missed" bookkeeping here - this
  # reuses the existing participant-closing, ChatBroadcaster.call_state
  # broadcast, and "call.missed" system message untouched, exactly as if the
  # caller had hung up themselves. A "voicemail_start" event is then
  # broadcast on the call's own signalling stream, targeted at the caller,
  # prompting their browser to start recording (see
  # pl_connect_call_controller.js#startVoicemailRecording). No new
  # PlConnectCallItem state is introduced for this - the call itself simply
  # ends as "missed", exactly like any other unanswered call; the recording
  # that follows is a fully separate, ordinary chat message (see
  # PlConnectApiController#upload_voicemail).
  class CallVoicemailTimeoutJob < ApplicationJob
    self.queue_adapter = :solid_queue

    queue_as :default

    def perform(call_uuid:)
      return unless CallService.voicemail_active?

      call = PlConnectCallItem.find_by(uuid: call_uuid, del_flag: false)
      return if call.blank? || call.state != "ringing"

      initiator = call.initiator
      chat_item = call.chat_item
      return if initiator.blank? || chat_item.blank?

      c = ControllerHelper.init_tenant(call.tenant_uuid, {})
      c[:session] = { user: initiator }

      CallService.new(c: c, chat_item: chat_item, user: initiator).hangup(call: call)

      ActionCable.server.broadcast(call.stream_name, {
        event: "voicemail_start",
        call_uuid: call.uuid,
        target_user_uuid: initiator.uuid,
        max_duration_seconds: CallService.voicemail_max_duration_seconds
      })
    rescue StandardError => e
      Rails.logger.error "PlConnect::CallVoicemailTimeoutJob: #{e.class}: #{e.message}"
    end
  end
end
