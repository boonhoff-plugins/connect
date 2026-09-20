# frozen_string_literal: true

# PlConnectWorkspaceController
#
# Hand-written controller for the Connect workspace — a full-screen, Teams-style
# surface that deliberately replaces the regular application chrome (navbar,
# footer, "main_content" turbo frame) with its own layout.
#
# Why a hand-written controller instead of a generated one:
#   The generated PageItem controllers (pl_connect_chat_item_controller.rb etc.)
#   are regenerated whenever their model configuration is rebuilt, so anything
#   written into them is at risk of being lost. They also render through the
#   generic form/list machinery, which is exactly what this surface must not do.
#
# Authorization:
#   Unlike PlConnectApiController — which only requires a session because the
#   real permission there is per-conversation membership — this controller keeps
#   the standard `permission?` gate from AuthorizeControllerConcern. That gate
#   resolves to the role name "plugin_pl_connect_workspace" (see
#   PermissionControllerConcern#user_has_permission?), so an administrator can
#   decide who is allowed into the workspace at all. Membership in individual
#   conversations is still checked separately by the services.
#
# Layout:
#   `layout` is overridden below to return the plugin's own template. The file
#   lives in extensions/plugins/connect/app/views/layouts/pl_connect.html.erb
#   and is found automatically because system/config/application.rb appends
#   every plugin's app/views directory to config.paths["app/views"].
class PlConnectWorkspaceController < ApplicationController
  # Sections of the workspace, in the order they appear in the icon rail.
  # `key`    — internal identifier, also used to highlight the active rail entry
  # `path`   — target URL (no Rails path helper, so the rail stays independent
  #            of route naming)
  # `icon`   — Font Awesome class (the icon set already bundled with the app)
  # `i18n`   — translation key below pl_connect.workspace.section
  SECTIONS = [
    { key: "home",     path: "/pl_connect_workspace/index_element",    icon: "fa-solid fa-house",            i18n: "home" },
    { key: "chat",     path: "/pl_connect_workspace/chat_element",     icon: "fa-solid fa-comments",         i18n: "chat" },
    { key: "calendar", path: "/pl_connect_workspace/calendar_element", icon: "fa-solid fa-calendar-days",    i18n: "calendar" },
    { key: "call",     path: "/pl_connect_workspace/call_element",     icon: "fa-solid fa-video",            i18n: "call" }
  ].freeze

  # Start page: chat overview on the left, calendar on the right.
  def index_element
    _prepare_shell(section: "home")
    _load_conversations
    _load_calendar_options
  rescue StandardError => e
    ErrorHelper.response(c: @c, e:)
  end

  # Full chat surface: conversation list plus message pane.
  # The message pane is populated by the Stimulus controller (phase 4); the
  # conversation list is rendered server-side so the page is useful without JS.
  def chat_element
    _prepare_shell(section: "chat")
    _load_conversations
    _resolve_initial_chat
    _resolve_pending_call
  rescue StandardError => e
    ErrorHelper.response(c: @c, e:)
  end

  # Full calendar surface. This reuses the existing CalendarItem feed and the
  # existing event_calendar Stimulus controller instead of duplicating either.
  def calendar_element
    _prepare_shell(section: "calendar")
    _load_calendar_options
  rescue StandardError => e
    ErrorHelper.response(c: @c, e:)
  end

  # Placeholder surface for screen sharing and a call history list (still to
  # come). Starting a new call from here is already possible - see the shared
  # user picker (pl_connect_user_picker_controller.js) wired up in the view.
  def call_element
    _prepare_shell(section: "call")
  rescue StandardError => e
    ErrorHelper.response(c: @c, e:)
  end

  private

  # --- Layout ------------------------------------------------------------

  # Selects the workspace layout for normal page requests.
  #
  # Modal and content-fragment requests (request_type=modal_window|just_content)
  # and PDF exports still have to go through the standard resolution in
  # LayoutControllerConcern, otherwise a dialog opened from inside the workspace
  # would drag the whole full-screen shell into the modal.
  def layout
    return super if params[:format] == "pdf"
    return super if params[:request_type].present?

    "pl_connect"
  end

  # --- Shared context ----------------------------------------------------

  # Fills the context values the layout and the icon rail depend on.
  def _prepare_shell(section:)
    @c[:pl_connect_section] = section
    @c[:pl_connect_sections] = SECTIONS
    @c[:header_title] = I18n.t("pl_connect.workspace.section.#{section}")
    @c[:pl_connect_user] = current_chat_user
    @c[:pl_connect_presence_active] = PlConnect::PresenceService.active?
    @c[:pl_connect_call_active] = PlConnect::CallService.active?
  end

  # The workspace only ever operates on the logged-in user. Everything that
  # follows depends on this, so the actions bail out early when it is missing.
  def current_chat_user
    @current_chat_user ||= User.find_by(id: session[:user]&.[](:id), del_flag: false, active: true)
  end

  # Pre-selects a conversation when the user arrived through a deep link
  # (?chat=<uuid>), for example from the conversation list on the start page.
  #
  # The value is only accepted when it is one of the conversations already
  # loaded for this user. That makes the parameter harmless: an arbitrary UUID
  # is dropped here instead of being handed to the client, and the JSON API
  # would reject it a second time anyway (PlConnectApiController resolves every
  # conversation through the membership scope).
  def _resolve_initial_chat
    requested = params[:chat].to_s
    return @c[:pl_connect_initial_chat_uuid] = nil if requested.blank?

    known = (@c[:pl_connect_conversations] || []).any? { |conversation| conversation[:uuid].to_s == requested }

    @c[:pl_connect_initial_chat_uuid] = known ? requested : nil
  end

  # Optional query param (?start_call=audio|video), set by the shared user
  # picker after it creates/opens a 1:1 chat from the Calls surface. Read
  # client side by pl_connect_call_controller.js to auto-start the call once
  # the chat has finished loading (see its pendingValue).
  #
  # Only honoured together with a chat uuid _resolve_initial_chat has already
  # accepted, i.e. one the caller is actually a member of. Without that a
  # dangling start_call value would be handed to the client for a conversation
  # it will never open, so it is dropped here instead.
  def _resolve_pending_call
    requested = params[:start_call].to_s
    accepted = @c[:pl_connect_initial_chat_uuid].present? && %w[audio video].include?(requested)

    @c[:pl_connect_pending_call] = accepted ? requested : nil
  end

  # --- Chat --------------------------------------------------------------

  # Loads the conversation sidebar. Reuses the same resolver and serializer as
  # the JSON API so the server-rendered list and the live updates cannot drift
  # apart in their idea of what a conversation looks like.
  def _load_conversations
    user = current_chat_user
    return @c[:pl_connect_conversations] = [] if user.blank?

    resolver = PlConnect::ConversationResolver.new(c: @c, user: user)
    conversations = resolver.list(archived: false)

    @c[:pl_connect_conversations] = conversations.map do |chat|
      PlConnect::MessageSerializer.conversation_as_json(chat: chat, viewer: user)
    end

    @c[:pl_connect_total_unread] = PlConnect::ReadStateService.new(c: @c, user: user).total_unread
  end

  # --- Calendar ----------------------------------------------------------

  # Mirrors CalendarItemController#show_element so the workspace calendar
  # behaves exactly like the standalone one.
  #
  # The view type constants are taken from CalendarItemController rather than
  # copied, so a new view added there cannot silently become invalid here.
  # Note that the config group's yaml_key is "system_configuration.page.calendar",
  # i.e. the values live under SYSTEM[:page][:calendar] — not SYSTEM[:calendar].
  def _load_calendar_options
    session_view = session[:calendar_last_view].to_s
    @c[:default_view] = if CalendarItemController::CALENDAR_VIEW_TYPES.include?(session_view)
                          session_view
    else
                          _resolve_calendar_view(SYSTEM&.dig(:page, :calendar, :default_view))
    end

    @c[:first_day] = (SYSTEM&.dig(:page, :calendar, :first_day) || 1).to_i
    @c[:weekends_active] = _calendar_bool(:weekends_active, default: true)
    @c[:slot_min_time] = SYSTEM&.dig(:page, :calendar, :slot_min_time).presence || "00:00:00"
    @c[:slot_max_time] = SYSTEM&.dig(:page, :calendar, :slot_max_time).presence || "24:00:00"
    @c[:time_format_24h_active] = _calendar_bool(:time_format_24h_active, default: true)
  end

  # Translates the admin-facing key ("month"/"week"/"day"/"list") into the
  # FullCalendar view type. Raw FullCalendar view types are also accepted for
  # backward compatibility with values stored before that mapping existed.
  # Anything unknown is normalised to the month grid so the data-* attribute
  # can never carry an invalid view type into the client.
  def _resolve_calendar_view(value)
    return "dayGridMonth" if value.blank?

    resolved = CalendarItemController::CALENDAR_VIEW_KEY_MAP.fetch(value, value)
    CalendarItemController::CALENDAR_VIEW_TYPES.include?(resolved) ? resolved : "dayGridMonth"
  end

  # Reads a boolean_lookup value from SYSTEM[:page][:calendar][key]. Those
  # entries are already cast to real true/false by the time they reach SYSTEM,
  # but this stays defensive (falls back to `default`) for missing values or
  # values stored as plain strings in an older/manually edited config.
  def _calendar_bool(key, default:)
    value = SYSTEM&.dig(:page, :calendar, key)
    return default if value.nil?

    ActiveModel::Type::Boolean.new.cast(value)
  end
end
