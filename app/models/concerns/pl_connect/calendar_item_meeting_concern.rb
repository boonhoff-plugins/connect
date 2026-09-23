# frozen_string_literal: true

module PlConnect
  # PlConnect::CalendarItemMeetingConcern
  #
  # Adds the "online meeting" behavior to the CORE CalendarItem model, without
  # putting any Connect-specific code inside system/app/models/calendar_item.rb.
  #
  # Mixed into CalendarItem via extensions/plugins/connect/config/initializers/
  # extend_calendar_item.rb (Rails.application.config.to_prepare), which is the
  # only place that touches the core class — this file itself never reopens
  # CalendarItem directly.
  #
  # Behavior (unchanged from the original implementation):
  #   meeting_active (see extensions/plugins/connect/db/migrate/
  #   20260923154709_export_table_calendar_item_202609231547.rb for the two
  #   backing columns, meeting_active + meeting_chat_uuid, both tagged to this
  #   plugin's own extension_item) drives meeting_url and the "Join meeting"
  #   block auto-inserted into description. The actual PlConnect group
  #   conversation behind the join link is created lazily, on first join (see
  #   #ensure_meeting_chat / PlConnectCalendarMeetingController#join).
  module CalendarItemMeetingConcern
    extend ActiveSupport::Concern

    # Prefix identifying a meeting_url value this concern generated itself
    # (the internal "join meeting" link resolved by
    # PlConnectCalendarMeetingController#join) as opposed to a link the user
    # typed in by hand (e.g. an external Teams/Zoom URL). Only a meeting_url
    # starting with this prefix is ever touched/cleared automatically by
    # _sync_meeting_link.
    MEETING_JOIN_PATH_PREFIX = "/calendar_item/join_meeting/"

    # Marker attribute on the auto-inserted "Join meeting" <p>, used to find
    # and replace the existing block on re-save instead of duplicating it.
    #
    # NOTE: this used to be a pair of HTML comment markers
    # (<!-- meeting_join_link --> ... <!-- /meeting_join_link -->), but the
    # description field is edited through a rich-text (contenteditable)
    # editor, and most such editors strip HTML comments when they parse
    # content into their WYSIWYG view. That meant the comments never survived
    # a single edit-and-save round-trip through the form: _without_meeting_
    # link_block found nothing to strip (no comment markers left), so
    # _with_meeting_link_block just appended a second "Join meeting" block on
    # top of the first one every time the event was saved again. A normal
    # HTML attribute on the <p> itself survives that round-trip, since
    # editors preserve element attributes even when they don't recognize them.
    MEETING_LINK_MARKER_ATTRIBUTE = "data-meeting-join-link"

    included do
      before_save :_sync_meeting_link
    end

    # Lazily creates (if needed) and returns the uuid of the PlConnect group
    # conversation powering this event's "Join meeting" link, adding any
    # attendee who isn't a member yet (e.g. someone invited to the event after
    # the meeting was first joined).
    def ensure_meeting_chat(c:, user:)
      chat = meeting_chat_uuid.present? ? PlConnectChatItem.find_by(uuid: meeting_chat_uuid, del_flag: false) : nil

      if chat.present?
        _sync_meeting_chat_members(chat, c:)
      else
        resolver = PlConnect::ConversationResolver.new(c:, user:)
        result = resolver.create_group(title: title.presence || "Meeting", member_uuids: calendar_item_join_users.pluck(:user_uuid))
        return nil unless result[:successful]

        chat = result[:element]
        update_columns(meeting_chat_uuid: chat.uuid)
      end

      chat.uuid
    end

    private

    # Keeps meeting_url and the auto-inserted "Join meeting" paragraph inside
    # description in sync with meeting_active. This callback only ever
    # manages a stable, plugin-internal URL
    # ("/calendar_item/join_meeting/<uuid>") — the actual PlConnect group
    # conversation behind it is created lazily on first click (see
    # #ensure_meeting_chat / PlConnectCalendarMeetingController#join).
    def _sync_meeting_link
      return if uuid.blank? # uuid not assigned yet; sync will run again on the next save

      generated_url = "#{MEETING_JOIN_PATH_PREFIX}#{uuid}"
      own_link = meeting_url.to_s.start_with?(MEETING_JOIN_PATH_PREFIX)

      if meeting_active?
        self.meeting_url = generated_url
        self.description = _with_meeting_link_block(description.to_s, generated_url)
      else
        self.meeting_url = nil if own_link
        self.description = _without_meeting_link_block(description.to_s)
      end
    end

    def _with_meeting_link_block(html, url)
      block = "<p #{MEETING_LINK_MARKER_ATTRIBUTE}=\"1\"><a href=\"#{ERB::Util.html_escape(url)}\" target=\"_blank\" rel=\"noopener\">Join meeting</a></p>"
      "#{_without_meeting_link_block(html)}#{block}"
    end

    def _without_meeting_link_block(html)
      # Strips ANY previously-inserted block, including ones inserted before
      # this attribute-based marker existed (matched by their old HTML
      # comments, or — for the very first editor round-trip after this
      # concern started running, before either marker existed — by a bare
      # "<p><a href=".../join_meeting/...">...</a></p>" with no marker at
      # all) and any duplicates already saved because of that bug — so a
      # record with several stray "Join meeting" blocks self-heals on its
      # very next save instead of accumulating more.
      html
        .gsub(/<p[^>]*#{Regexp.escape(MEETING_LINK_MARKER_ATTRIBUTE)}[^>]*>.*?<\/p>/m, "")
        .gsub(/<!-- meeting_join_link -->.*?<!-- \/meeting_join_link -->/m, "")
        .gsub(/<p>\s*<a[^>]*href="#{Regexp.escape(MEETING_JOIN_PATH_PREFIX)}[^"]*"[^>]*>[^<]*<\/a>\s*<\/p>/m, "")
        .rstrip
    end

    # Adds any current attendee who isn't a chat member yet. Called both
    # right after lazily creating the chat (in case member_uuids resolution
    # excluded someone, e.g. a cross-tenant attendee) and on every subsequent
    # join, so an attendee added to the event later is still picked up.
    def _sync_meeting_chat_members(chat, c:)
      calendar_item_join_users.includes(:user).find_each do |join|
        attendee = join.user
        next if attendee.blank? || chat.member?(attendee)

        chat.add_member(c:, user: attendee)
      end
    end
  end
end
