# frozen_string_literal: true

# PlConnectCalendarMeetingController
#
# Resolves the stable internal link CalendarItem auto-generates into
# meeting_url when meeting_active is enabled (see
# PlConnect::CalendarItemMeetingConcern#_sync_meeting_link) into an actual
# Connect group conversation, then redirects there so the user can join the
# call.
#
# Lives entirely in the Connect plugin: the core CalendarItem model/view/JS
# never need to know this controller exists. Route is declared in this
# plugin's own config/routes.rb, at the SAME url path the core used to serve
# ("/calendar_item/join_meeting/:uuid"), so already-generated meeting_url
# values keep working unchanged.
#
# The underlying PlConnect conversation is created (and its membership synced
# to the event's current attendees) lazily, on first click, rather than at
# save time — see PlConnect::CalendarItemMeetingConcern#ensure_meeting_chat.
class PlConnectCalendarMeetingController < ApplicationController
  # GET /calendar_item/join_meeting/:uuid
  def join
    user = session[:user]
    if user.blank?
      flash[:warning] = "Please log in to join this meeting."
      return redirect_to("/calendar_item/show_element")
    end

    event = CalendarItem.visible_to_user(user, @c).find_by(uuid: params[:uuid], del_flag: false)
    if event.blank? || !event.meeting_active?
      flash[:warning] = "Meeting not found."
      return redirect_to("/calendar_item/show_element")
    end

    unless PlConnect::CallService.active?
      flash[:warning] = "Meetings are not available on this installation."
      return redirect_to("/calendar_item/show_element")
    end

    chat_uuid = event.ensure_meeting_chat(c: @c, user:)
    if chat_uuid.blank?
      flash[:warning] = "Could not open this meeting."
      return redirect_to("/calendar_item/show_element")
    end

    redirect_to "/pl_connect_workspace/chat_element?chat=#{chat_uuid}&start_call=video"
  rescue StandardError => e
    ErrorHelper.response(c: @c, e:)
  end

  private

  # Overrides the role based check of PermissionControllerConcern, same
  # reasoning as PlConnectApiController#user_has_permission?: access here is
  # decided per event (CalendarItem.visible_to_user + meeting_active?), not
  # per controller role — requiring an extra role would mean an administrator
  # has to grant it to literally every user before anyone could join a
  # meeting from their calendar. Authentication is still mandatory (checked
  # explicitly in #join).
  def user_has_permission?
    session[:user].present?
  end
end
