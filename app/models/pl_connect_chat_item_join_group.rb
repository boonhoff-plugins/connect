# frozen_string_literal: true

# PlConnectChatItemJoinGroup
#
# Assigns a chat conversation to a group. Used for group-wide channels and for
# the visibility evaluation in UserVisibilityConcern.
class PlConnectChatItemJoinGroup < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_chat_item, optional: true
  belongs_to :group, optional: true
end
