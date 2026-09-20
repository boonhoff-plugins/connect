# frozen_string_literal: true

# PlConnectChatItemJoinUserHistory
class PlConnectChatItemJoinUserHistory < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_chat_item, optional: true
  belongs_to :user, optional: true
end
