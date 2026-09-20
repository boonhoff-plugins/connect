class ImportPluginPlConnectChatMentionItemController < ImportController

  @@child_helper    = ImportPluginPlConnectChatMentionItemHelper

  @@child_title     = "Import (Plugin ChatMentionItem)"

  def permission?(redirection: true, render_json: true)
    if session[:user].present? && (session[:user].has_role?(:roles => 'import', :controller => self) || session[:user].has_role?(:roles => 'config', :controller => self))
      return true
    else
      super(redirection:)
    end
  end

  def import_example
    if params[:element][:file].tempfile.path.downcase.ends_with?("xlsx")
      original_filename                   = params[:element][:file].original_filename.split(".")[0]

      options                             = SYSTEM&.dig(:data, :csv, :options) || {}
      options[:encoding]                  = (params[:element][:encoding].present? ? params[:element][:encoding] : SYSTEM&.dig(:data, :csv, :default_encoding))
      data_array                          = Array.new

      xlsx                                = Roo::Spreadsheet.open(params[:element][:file].tempfile.path)
      sheet                               = xlsx.sheet(0)
      csv_sheet                           = sheet.to_csv

      CSV.parse(csv_sheet, col_sep: options[:col_sep], encoding: options[:encoding], headers: true) do |row|

      end
    end
    raise "Function has to be programmed."
  end

  private

  # this function set the layout of an page.
  def layout
    if action_name.starts_with?("fragment_")
      return "application_raw"
    else
      return "application"
    end
  end
end
