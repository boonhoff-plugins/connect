create_resource_routes(%w[pl_connect_chat_item], @full_feature_actions, path_aliases: { 'pl_connect_chat_item' => 'pl_connect/chat_item' })
create_resource_routes(%w[pl_connect_chat_message_item], @full_feature_actions, path_aliases: { 'pl_connect_chat_message_item' => 'pl_connect/chat_message_item' })
create_resource_routes(%w[pl_connect_chat_reaction_item], @full_feature_actions, path_aliases: { 'pl_connect_chat_reaction_item' => 'pl_connect/chat_reaction_item' })
create_resource_routes(%w[pl_connect_chat_attachment_item], @full_feature_actions, path_aliases: { 'pl_connect_chat_attachment_item' => 'pl_connect/chat_attachment_item' })
create_resource_routes(%w[pl_connect_chat_mention_item], @full_feature_actions, path_aliases: { 'pl_connect_chat_mention_item' => 'pl_connect/chat_mention_item' })
create_resource_routes(%w[pl_connect_call_item], @full_feature_actions, path_aliases: { 'pl_connect_call_item' => 'pl_connect/call_item' })

# --- Chat runtime API -------------------------------------------------------
#
# JSON endpoints used by the chat UI. Declared explicitly instead of through
# create_resource_routes because these are not CRUD screens but a small,
# purpose built API; the verbs are part of the contract and must not be
# widened by a generator. Same pattern as calendar_item/events_feed in the
# core routes file.
#
# GET is used for everything that only reads, POST for everything that writes,
# so a state changing call can never be triggered by a plain link or an
# <img src>.

get  "pl_connect_api/conversations"      => "pl_connect_api#conversations",      as: :pl_connect_api_conversations
get  "pl_connect_api/messages"           => "pl_connect_api#messages",           as: :pl_connect_api_messages
get  "pl_connect_api/thread"             => "pl_connect_api#thread",             as: :pl_connect_api_thread
get  "pl_connect_api/search"             => "pl_connect_api#search",             as: :pl_connect_api_search
get  "pl_connect_api/users"              => "pl_connect_api#users",              as: :pl_connect_api_users
get  "pl_connect_api/presence"           => "pl_connect_api#presence",           as: :pl_connect_api_presence
get  "pl_connect_api/download_attachment" => "pl_connect_api#download_attachment", as: :pl_connect_api_download_attachment

post "pl_connect_api/open_direct"        => "pl_connect_api#open_direct",        as: :pl_connect_api_open_direct
post "pl_connect_api/create_group"       => "pl_connect_api#create_group",       as: :pl_connect_api_create_group
post "pl_connect_api/create_message"     => "pl_connect_api#create_message",     as: :pl_connect_api_create_message
post "pl_connect_api/update_message"     => "pl_connect_api#update_message",     as: :pl_connect_api_update_message
post "pl_connect_api/delete_message"     => "pl_connect_api#delete_message",     as: :pl_connect_api_delete_message
post "pl_connect_api/toggle_reaction"    => "pl_connect_api#toggle_reaction",    as: :pl_connect_api_toggle_reaction
post "pl_connect_api/mark_read"          => "pl_connect_api#mark_read",          as: :pl_connect_api_mark_read
post "pl_connect_api/upload_attachment"  => "pl_connect_api#upload_attachment",  as: :pl_connect_api_upload_attachment

# --- Calls (phase 5) ---------------------------------------------------------
#
# Every state change (start/answer/hangup/media toggle) goes through POST so it
# can never be triggered by a plain link or an <img src>. The actual WebRTC
# signalling itself does not use these routes at all - it travels over
# PlConnectCallChannel once a call has been started/answered here.

post "pl_connect_api/start_call"         => "pl_connect_api#start_call",         as: :pl_connect_api_start_call
post "pl_connect_api/answer_call"        => "pl_connect_api#answer_call",        as: :pl_connect_api_answer_call
post "pl_connect_api/hangup_call"        => "pl_connect_api#hangup_call",        as: :pl_connect_api_hangup_call
post "pl_connect_api/call_media_state"   => "pl_connect_api#call_media_state",   as: :pl_connect_api_call_media_state
post "pl_connect_api/upload_voicemail"   => "pl_connect_api#upload_voicemail",   as: :pl_connect_api_upload_voicemail
get  "pl_connect_api/voicemail_greeting" => "pl_connect_api#voicemail_greeting", as: :pl_connect_api_voicemail_greeting
get  "pl_connect_api/call_invitable_users" => "pl_connect_api#call_invitable_users", as: :pl_connect_api_call_invitable_users
post "pl_connect_api/invite_call"        => "pl_connect_api#invite_call",        as: :pl_connect_api_invite_call

# --- Workspace shell --------------------------------------------------------
#
# The full screen Teams style surface. GET only: these actions render pages and
# never change state. Declared explicitly rather than via create_resource_routes
# because the workspace is not a CRUD screen and must not inherit the
# edit/delete/import/export routes a generated resource would bring along.

get "pl_connect_workspace/index_element"    => "pl_connect_workspace#index_element",    as: :pl_connect_workspace_index
get "pl_connect_workspace/chat_element"     => "pl_connect_workspace#chat_element",     as: :pl_connect_workspace_chat
get "pl_connect_workspace/calendar_element" => "pl_connect_workspace#calendar_element", as: :pl_connect_workspace_calendar
get "pl_connect_workspace/call_element"     => "pl_connect_workspace#call_element",     as: :pl_connect_workspace_call

# --- Calendar meeting join link ---------------------------------------------
#
# Resolves the internal "Join meeting" link auto-inserted into a CalendarItem's
# meeting_url (and description) when meeting_active is enabled into an actual
# Connect conversation (see PlConnectCalendarMeetingController#join and
# PlConnect::CalendarItemMeetingConcern#ensure_meeting_chat). Kept at the same
# url path the core system used to serve before this feature moved into the
# plugin, so meeting_url values generated before the move keep working.
get "calendar_item/join_meeting/:uuid" => "pl_connect_calendar_meeting#join", as: :calendar_item_join_meeting
