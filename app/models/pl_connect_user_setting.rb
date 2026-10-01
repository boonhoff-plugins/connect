# frozen_string_literal: true

# PlConnectUserSetting
#
# One row per user: their manually chosen, persisted chat status override
# (see CreatePlConnectUserSettings for why this is a durable row rather than
# a PresenceService cache entry). `chat_status` blank/nil means "automatic"
# (the ordinary online/away heartbeat logic applies, see
# PlConnect::PresenceService#display_states_for).
class PlConnectUserSetting < ApplicationRecord
  include AssociationOriginalModelConcern

  CHAT_STATUSES = %w[away dnd offline].freeze

  belongs_to :user, optional: true

  validates :chat_status, inclusion: { in: CHAT_STATUSES }, allow_blank: true
end
