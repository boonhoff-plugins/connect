# frozen_string_literal: true

module PlConnect
  # SfuService
  #
  # Thin wrapper around the LiveKit server SDK - mints the short-lived, per-
  # user access token a browser needs to join an SFU-relayed conference room
  # (see PlConnect::CallService.sfu_configured?/pl_connect_call_controller.js's
  # SFU path). The room itself needs no separate creation call: LiveKit
  # creates a room implicitly the first time any participant joins it with a
  # valid token, and tears it down again once empty - there is nothing here
  # to persist beyond PlConnectCallItem#room_key, which already exists for the
  # mesh path and is reused verbatim as the LiveKit room name.
  #
  # == Data protection
  # The token only grants join/publish/subscribe rights to one specific room
  # for one specific, already-authorized participant (identity: user.uuid) -
  # it carries no other personal data, expires on its own (DEFAULT_TTL), and
  # is generated fresh on every start_call/answer_call/resume request rather
  # than stored anywhere. LiveKit itself only relays encrypted media between
  # participants; this application never enables server-side recording.
  class SfuService
    # Mints a token for `user` to join `call`'s room. Returns nil (never
    # raises into the caller) when the SFU is not fully configured, so
    # call sites can fall back to treating the call as mesh-only.
    def self.access_token(call:, user:)
      return nil if call.blank? || user.blank?
      return nil unless CallService.sfu_configured?

      token = LiveKit::AccessToken.new(
        api_key: CallService.sfu_api_key,
        api_secret: CallService.sfu_api_secret,
        identity: user.uuid,
        name: user.login.to_s
      )
      token.video_grant = LiveKit::VideoGrant.new(
        room: call.room_key,
        roomJoin: true,
        canPublish: true,
        canSubscribe: true
      )
      token.to_jwt
    rescue StandardError => e
      Rails.logger.error "PlConnect::SfuService.access_token: #{e.class}: #{e.message}"
      nil
    end

    # { url:, token: } the client needs to join via livekit-client, or nil
    # when this call is not (or no longer) SFU-relayed - shared by
    # PlConnectApiController#_call_json (start_call/answer_call) and
    # PlConnectWorkspaceHelper#pl_connect_call_resume_payload (page reload),
    # so both always mint a fresh, short-lived token rather than persisting
    # one anywhere.
    def self.payload_for(call:, user:)
      return nil unless call&.sfu_active?

      token = access_token(call: call, user: user)
      return nil if token.blank?

      { url: CallService.sfu_url, token: token }
    end
  end
end
