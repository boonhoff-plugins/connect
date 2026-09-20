# frozen_string_literal: true

# PlConnectCallItemJoinUser
#
# One participant of an audio/video call. Carries the per-participant media
# state so the UI can render who is muted, who shares their screen and who is
# still connecting.
class PlConnectCallItemJoinUser < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_call_item, optional: true
  belongs_to :user, optional: true

  # Mirrors the RTCPeerConnection.connectionState values plus "invited" for the
  # phase before the callee accepted.
  CONNECTION_STATES = %w[invited connecting connected disconnected failed closed].freeze

  validates :connection_state, inclusion: { in: CONNECTION_STATES }, allow_blank: true
end
