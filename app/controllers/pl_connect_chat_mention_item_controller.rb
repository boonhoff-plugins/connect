# frozen_string_literal: true

# PlConnectChatMentionItemController
class PlConnectChatMentionItemController < ApplicationController
  include AttributeControllerConcern
  include IndexElementControllerConcern
  include EditElementControllerConcern
  include HistoryElementControllerConcern
  include SearchElementControllerConcern
  include ListElementControllerConcern
  include TreeElementControllerConcern
  include ExportElementControllerConcern
  include ImportElementControllerConcern
  include JsonElementControllerConcern
  include QuickEditControllerConcern
  include PageConfigControllerConcern
  include FragmentControllerConcern

  private

  # def around
    # case action_name
    # when 'search_element'
    # when 'list_element'
    # end
    # yield
  # end

  # def final_check(c:)
    # case action_name
    # when 'edit_element'
    # end
  # end
end
