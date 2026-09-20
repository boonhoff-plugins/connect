# frozen_string_literal: true

# PlConnectChatItemJoinTenant
#
# Assigns a chat conversation to a tenant. Only relevant for conversations that
# are explicitly shared across tenant boundaries.
class PlConnectChatItemJoinTenant < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_chat_item, optional: true
end
