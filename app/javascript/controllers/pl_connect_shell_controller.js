// pl_connect_shell_controller.js
//
// Main-app shell notifications for the Connect plugin - see
// extension_shell_widgets/_pl_connect.html.erb for the wrapper this mounts
// on and system/lib/boonhoff/extension_shell_widgets.rb for the generic hook.
//
// == What it does
//   * on connect (i.e. once per full page load - the widget is
//     data-turbo-permanent, so a soft Turbo navigation does not remount it)
//     fetches the conversation list and shows a toast for every conversation
//     that already has unread messages waiting, so a user landing on any page
//     right after logging in is told about messages that arrived while they
//     were away - not just ones that arrive while the page stays open
//   * listens on `document` for "pl-connect:conversation-activity" - the DOM
//     event pl_connect_presence_controller.js already re-dispatches from the
//     per-user PlConnectPresenceChannel stream (see that controller for why
//     it is re-dispatched rather than subscribed to twice)
//   * renders a small dismissible toast for it, unless the conversation is
//     muted
//   * clicking a toast deep-links into the workspace
//     (/pl_connect_workspace/chat_element?chat=<uuid>), the same pattern
//     pl_connect_user_picker_controller.js already uses for "open this
//     conversation" - PlConnectWorkspaceController#_resolve_initial_chat
//     re-validates membership server-side, so the uuid alone grants nothing
//
// == Security
// Toast content (title, sender_login, preview) is inserted with textContent
// only, never innerHTML - the preview is already plain text
// (MessageSanitizer.preview), but this stays a second, independent guarantee
// against it ever becoming a markup injection point.
import { Controller } from "@hotwired/stimulus"
import { ENDPOINTS, apiGet } from "../pl_connect/api"

const AUTO_DISMISS_MS = 8000
const MAX_STACKED_TOASTS = 3

export default class extends Controller {
  static targets = ["toasts"]

  static values = {
    i18n: Object
  }

  connect() {
    this.onConversationActivity = (event) => this.handleConversationActivity(event)
    document.addEventListener("pl-connect:conversation-activity", this.onConversationActivity)

    this.loadUnreadOnStartup()
  }

  disconnect() {
    document.removeEventListener("pl-connect:conversation-activity", this.onConversationActivity)
  }

  // Catches up on messages that arrived while the user was logged out or the
  // browser was closed - the live "conversation.activity" broadcast above only
  // ever reaches a tab that is already open and subscribed, so without this a
  // user would only find out about backlog by opening the workspace itself.
  async loadUnreadOnStartup() {
    const result = await apiGet(ENDPOINTS.conversations, { archived: false })
    if (!result.successful) return

    result.conversations
      .filter((conversation) => conversation.unread_count > 0 && !conversation.muted)
      .forEach((conversation) => {
        this.renderToast({
          chat_uuid: conversation.uuid,
          title: conversation.title,
          preview: conversation.last_message_preview
        })
      })
  }

  handleConversationActivity(event) {
    const payload = event.detail
    if (!payload || !payload.chat_uuid || payload.muted === true) return

    this.renderToast(payload)
  }


  renderToast(payload) {
    if (!this.hasToastsTarget) return

    while (this.toastsTarget.children.length >= MAX_STACKED_TOASTS) {
      const oldest = this.toastsTarget.firstElementChild
      clearTimeout(oldest._plConnectDismissTimer)
      oldest.remove()
    }

    const toast = document.createElement("div")
    toast.className =
      "w-full max-w-xs cursor-pointer rounded-box bg-base-100 p-3 shadow-xl ring-1 ring-base-300 hover:ring-primary"
    toast.setAttribute("role", "button")

    const title = document.createElement("p")
    title.className = "truncate text-sm font-semibold"
    title.textContent = payload.title || this.i18nValue.new_message || ""
    toast.appendChild(title)

    if (payload.sender_login || payload.preview) {
      const body = document.createElement("p")
      body.className = "mt-1 truncate text-xs text-base-content/70"
      body.textContent = [payload.sender_login, payload.preview].filter(Boolean).join(": ")
      toast.appendChild(body)
    }

    toast._plConnectDismissTimer = setTimeout(() => toast.remove(), AUTO_DISMISS_MS)

    toast.addEventListener("click", () => {
      window.location.href = `/pl_connect_workspace/chat_element?chat=${encodeURIComponent(payload.chat_uuid)}`
    })

    this.toastsTarget.appendChild(toast)
  }
}
