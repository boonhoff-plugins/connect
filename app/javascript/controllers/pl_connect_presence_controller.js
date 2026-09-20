// pl_connect_presence_controller.js
//
// Presence heartbeat and per-user notification stream.
//
// Attached once to the workspace layout body, so it stays alive while the user
// moves between the workspace sections.
//
// == What it does
//   * subscribes to PlConnectPresenceChannel (the stream name is derived from
//     current_user on the server, so a client cannot listen to anyone else)
//   * sends a periodic heartbeat that refreshes the cache TTL; when the tab is
//     closed the entry expires on its own and the user goes offline
//   * re-dispatches "conversation.activity" events as a DOM event so the chat
//     controller can update the sidebar without owning a second subscription
//
// == Data protection
// The presence state lives in the cache only (PlConnect::PresenceService) and
// is never written to the database, so no movement profile can be
// reconstructed from it afterwards. The heartbeat is suspended while the tab is
// hidden - that also means an idle tab does not keep a user "online" for hours.
import { Controller } from "@hotwired/stimulus"
import plConnectConsumer from "../pl_connect/cable"

// Has to stay clearly below PresenceService's TTL, otherwise the entry expires
// between two beats and the user flickers offline.
const HEARTBEAT_MS = 30000

export default class extends Controller {
  static targets = [ "indicator", "label" ]

  static values = {
    active: Boolean,
    i18n: Object
  }

  connect() {
    if (this.activeValue !== true) return

    this.state = "online"
    this.subscribe()

    this.onVisibilityChange = () => this.handleVisibilityChange()
    document.addEventListener("visibilitychange", this.onVisibilityChange)
  }

  disconnect() {
    document.removeEventListener("visibilitychange", this.onVisibilityChange)
    this.stopHeartbeat()
    this.subscription?.unsubscribe()
    this.subscription = null
  }

  subscribe() {
    const controller = this

    this.subscription = plConnectConsumer().subscriptions.create("PlConnectPresenceChannel", {
      connected() {
        controller.setState("online")
        controller.startHeartbeat()
      },

      disconnected() {
        controller.stopHeartbeat()
        controller.setState("offline")
      },

      rejected() {
        controller.stopHeartbeat()
        controller.setState("offline")
      },

      received(payload) {
        controller.handlePayload(payload)
      }
    })
  }

  startHeartbeat() {
    this.stopHeartbeat()
    this.beat()
    this.heartbeatTimer = setInterval(() => this.beat(), HEARTBEAT_MS)
  }

  stopHeartbeat() {
    if (this.heartbeatTimer) clearInterval(this.heartbeatTimer)
    this.heartbeatTimer = null
  }

  beat() {
    this.subscription?.perform("heartbeat", { state: this.state })
  }

  // A hidden tab reports "away" once and then stops beating, so the entry
  // expires instead of claiming the user is at their desk.
  handleVisibilityChange() {
    if (document.visibilityState === "hidden") {
      this.setState("away")
      this.beat()
      this.stopHeartbeat()
    } else {
      this.setState("online")
      this.startHeartbeat()
    }
  }

  setState(state) {
    this.state = state
    this.renderIndicator(state)
  }

  renderIndicator(state) {
    if (this.hasIndicatorTarget) {
      this.indicatorTarget.className = `inline-block h-2 w-2 rounded-full ${this.colorFor(state)}`
    }

    if (this.hasLabelTarget) {
      this.labelTarget.textContent = this.i18nValue[state] || ""
    }
  }

  colorFor(state) {
    switch (state) {
      case "online": return "bg-success"
      case "away": return "bg-warning"
      case "busy": return "bg-error"
      default: return "bg-base-content/30"
    }
  }

  handlePayload(payload) {
    if (!payload || !payload.event) return

    // The chat controller owns the sidebar, but it is only subscribed to the
    // conversation that is currently open. Re-dispatching as a DOM event keeps
    // the two controllers decoupled and avoids a second WebSocket subscription
    // for the same data.
    if (payload.event === "conversation.activity") {
      document.dispatchEvent(
        new CustomEvent("pl-connect:conversation-activity", { bubbles: false, detail: payload })
      )
    }

    // Incoming call invites reach a user through their own presence stream
    // (rather than the conversation's chat stream) precisely because the
    // callee may not have that conversation open at all - see
    // PlConnectPresenceChannel's class doc. Note this means an installation
    // that disables presence (activeValue false) also loses the incoming-call
    // banner for a conversation the callee is not currently viewing; a call
    // for the currently open conversation still works via the chat stream.
    if (payload.event === "call.invite") {
      document.dispatchEvent(new CustomEvent("pl-connect:call-invite", { bubbles: false, detail: payload }))
    }
  }
}
