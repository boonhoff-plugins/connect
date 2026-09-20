class PlConnectChatItemHistory < ApplicationRecord
  include AssociationHistoryModelConcern
  # Mirrors the UserVisibilityConcern of PlConnectChatItem on the history side.
  # Added manually because the create_all_identity_join generator aborts on
  # plugin models (its inject_into_file resolves against system/, not the
  # plugin folder) and never reached the injection step.
  include UserHistoryVisibilityConcern
end
