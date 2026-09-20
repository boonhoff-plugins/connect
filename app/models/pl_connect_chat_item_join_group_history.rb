# frozen_string_literal: true

# PlConnectChatItemJoinGroupHistory
class PlConnectChatItemJoinGroupHistory < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_chat_item, optional: true
  belongs_to :group, optional: true
end
