# frozen_string_literal: true

# PlConnectCallItem
#
# One audio/video call inside a conversation. The record is pure signalling
# bookkeeping: it stores who called whom, when, for how long and in which
# signalling room. The media streams themselves never touch the server — they
# are negotiated peer to peer via WebRTC.
#
# The participant list lives in pl_connect_call_item_join_users. Unlike
# PlConnectChatItem this model does not use UserVisibilityConcern: a call is
# never "visible" on its own, access is always derived from membership in the
# conversation the call belongs to.
class PlConnectCallItem < ApplicationRecord
  include AssociationOriginalModelConcern

  F_TYPES = %w[direct_call conference screen_share].freeze
  STATES  = %w[ringing active ended missed declined].freeze

  # A plain WebRTC mesh needs n*(n-1) peer connections. Beyond roughly four
  # participants an SFU is required, so the mesh is capped here.
  MESH_PARTICIPANT_LIMIT = 4

  belongs_to :chat_item, class_name: "PlConnectChatItem", foreign_key: "chat_item_id", optional: true, inverse_of: false
  belongs_to :initiator, class_name: "User", foreign_key: "initiator_user_id", optional: true, inverse_of: false

  has_many :pl_connect_call_item_join_users, dependent: :destroy
  has_many :users, through: :pl_connect_call_item_join_users

  validates :f_type, inclusion: { in: F_TYPES }, allow_blank: true
  validates :state, inclusion: { in: STATES }, allow_blank: true

  def self.running
    where(state: %w[ringing active], del_flag: false)
  end

  # Random, unguessable signalling room key. It is used as the ActionCable
  # stream name, so it must not be derivable from the conversation uuid.
  def self.generate_room_key
    SecureRandom.hex(32)
  end

  def participants
    pl_connect_call_item_join_users.where(del_flag: false)
  end

  def active_participants
    participants.where(left_at: nil)
  end

  def participant_for(user)
    return nil if user.blank?

    participants.find_by(user_id: user.id)
  end

  def running?
    %w[ringing active].include?(state)
  end

  def full?
    active_participants.count >= [ max_participants.to_i, MESH_PARTICIPANT_LIMIT ].min
  end

  # The ActionCable stream name used for SDP/ICE exchange.
  def stream_name
    "pl_connect_call_#{room_key}"
  end
end
