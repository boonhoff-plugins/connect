# frozen_string_literal: true

# PlConnectChatItemJoinRoleHistory
class PlConnectChatItemJoinRoleHistory < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_chat_item, optional: true
  belongs_to :role, optional: true
end
