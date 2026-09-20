# frozen_string_literal: true

# PlConnectChatItemJoinTenantHistory
class PlConnectChatItemJoinTenantHistory < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_chat_item, optional: true
end
