# frozen_string_literal: true

# PlConnectCallItemJoinUserHistory
class PlConnectCallItemJoinUserHistory < ApplicationRecord
  belongs_to :tenant, optional: true
  belongs_to :pl_connect_call_item, optional: true
  belongs_to :user, optional: true
end
