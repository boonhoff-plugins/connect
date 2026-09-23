import { Controller } from "@hotwired/stimulus";

// PlConnectCalendarMeetingController
//
// Adds a small clickable "Join meeting" icon-link onto calendar event
// elements rendered by the CORE event-calendar Stimulus controller (see
// system/app/javascript/controllers/event_calendar_controller.js), without
// that core file containing any Connect-specific code.
//
// How this hooks in:
//   The core controller dispatches a generic, plugin-agnostic
//   "event-calendar:event-mounted" CustomEvent (bubbling) whenever it mounts
//   an event element. This file listens for it at the `document` level, so
//   it works regardless of which page the calendar is rendered on (the core
//   CalendarItem#show_element page AND the Connect workspace's own calendar
//   view both use the same core controller).
//
// This module is picked up by the extension JS manifest purely because its
// filename ends in "_controller.js" (see
// system/lib/boonhoff/extension_javascript_manifest.rb); the listener below
// is attached as a module-level side effect on import, not from a mounted
// Stimulus controller instance — there is no element in the DOM that uses
// the "pl-connect-calendar-meeting" identifier. The exported class only
// exists so the generated manifest has a valid default export to register.
document.addEventListener("event-calendar:event-mounted", (event) => {
    const { info } = event.detail;
    const meetingUrl = info.event.extendedProps?.meetingUrl;
    if (!meetingUrl) return;

    // Absolutely position the icon in the event's bottom-right corner. The
    // event element needs position: relative as the positioning context;
    // FullCalendar's own event styles don't set this by default.
    info.el.style.position = "relative";

    const link = document.createElement("a");
    link.href = meetingUrl;
    link.target = "_blank";
    link.rel = "noopener";
    link.title = document.querySelector('meta[name="pl-connect-calendar-join-meeting-label"]')?.content ?? "";
    link.className = "fc-meeting-join-link fa-solid fa-video absolute bottom-0.5 right-1 z-10 text-xs opacity-80 hover:opacity-100";
    // Prevent the calendar's own eventClick handler (which would otherwise
    // open the edit dialog instead) from firing when the icon itself is
    // clicked.
    link.addEventListener("click", (clickEvent) => clickEvent.stopPropagation());

    info.el.appendChild(link);
});

export default class extends Controller { }
