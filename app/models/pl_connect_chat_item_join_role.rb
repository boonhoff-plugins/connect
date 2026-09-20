# frozen_string_literal: true

# PlConnectChatItemJoinRole
#
# Assigns a chat conversation to a role. Used for role-wide channels and for
# the visibility evaluation in UserVisibilityConcern.
class PlConnectChatItemJoinRole < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_chat_item, optional: true
  belongs_to :role, optional: true
end
