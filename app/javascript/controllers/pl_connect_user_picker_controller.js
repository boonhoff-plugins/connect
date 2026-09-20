// pl_connect_user_picker_controller.js
//
// Shared "pick a colleague" modal, mounted once on the workspace layout
// wrapper (see app/views/layouts/pl_connect.html.erb) so it is reachable from
// every section, not just the chat surface. Two entry points open it:
//   * the conversation sidebar's "+" button                 (mode "chat")
//   * the Calls surface's "start audio/video call" buttons  (mode "call")
//
// == Why this navigates instead of updating the page in place
// /pl_connect_api/open_direct only returns the resulting chat - the
// conversation sidebar itself is rendered server side, once per page load
// (see PlConnectWorkspaceController#_load_conversations). Re-fetching and
// re-rendering that list here would duplicate logic that already exists on
// the server for no benefit, so picking a user simply navigates to the chat
// surface for the resulting conversation. That is also the only way to reach
// pl_connect_chat_controller.js's message pane from a section that does not
// render one (Calls, Calendar) - openConversation() is a no-op without a
// messages target.
//
// For mode "call" the target URL additionally carries ?start_call=audio|video;
// PlConnectWorkspaceController#chat_element only forwards that value once it
// has verified the caller is actually a member of the resolved chat (see
// _resolve_pending_call), and pl_connect_call_controller.js starts the call
// once the chat has finished opening (pl-connect:conversation-opened).
//
// == Security
// User logins/titles come from PlConnectApiController#users (already scoped to
// the caller's tenant/searchable set) and are rendered through el()'s
// textContent path only - never innerHTML.
import { Controller } from "@hotwired/stimulus"
import { ENDPOINTS, apiGet, apiPost } from "../pl_connect/api"
import { clear, debounce, el, initials } from "../pl_connect/dom"

const SEARCH_DEBOUNCE_MS = 250

export default class extends Controller {
    static targets = ["overlay", "input", "results", "error"]
    static values = { i18n: Object }

    connect() {
        this.mode = "chat"
        this.startCall = null
        this.runSearch = debounce(() => this.performSearch(), SEARCH_DEBOUNCE_MS)
    }

    // Bound to every trigger button:
    //   data-action="pl-connect-user-picker#open"
    //   data-pl-connect-picker-mode="chat|call"
    //   data-pl-connect-picker-start-call="audio|video" (mode "call" only)
    open(event) {
        const dataset = event.currentTarget?.dataset || {}
        this.mode = dataset.plConnectPickerMode === "call" ? "call" : "chat"
        this.startCall = dataset.plConnectPickerStartCall || null

        clear(this.resultsTarget)
        this.hideError()
        this.inputTarget.value = ""
        this.overlayTarget.classList.remove("hidden")
        this.inputTarget.focus()
    }

    close() {
        this.overlayTarget.classList.add("hidden")
    }

    closeOnBackdrop(event) {
        if (event.target === this.overlayTarget) this.close()
    }

    onKeydown(event) {
        if (event.key === "Escape") this.close()
    }

    onInput() {
        this.runSearch()
    }

    async performSearch() {
        this.hideError()

        const result = await apiGet(ENDPOINTS.users, { term: this.inputTarget.value.trim() })

        if (result.successful !== true) {
            this.renderMessage(this.i18nValue.error)
            return
        }

        this.renderResults(result.users || [])
    }

    renderResults(users) {
        clear(this.resultsTarget)

        if (users.length === 0) {
            this.renderMessage(this.i18nValue.no_results)
            return
        }

        users.forEach((user) => this.resultsTarget.appendChild(this.buildUserRow(user)))
    }

    buildUserRow(user) {
        return el("button", {
            class: "flex w-full items-center gap-3 rounded-box px-3 py-2 text-left hover:bg-base-200",
            attrs: { type: "button" },
            dataset: { action: "pl-connect-user-picker#pick", plConnectUserUuid: user.uuid },
            children: [
                el("span", {
                    class: "flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-base-300 text-xs font-semibold",
                    text: initials(user.title || user.login)
                }),
                el("span", { class: "min-w-0 flex-1 truncate text-sm", text: user.title || user.login })
            ]
        })
    }

    renderMessage(text) {
        clear(this.resultsTarget)
        this.resultsTarget.appendChild(el("p", { class: "px-3 py-6 text-center text-sm text-base-content/60", text }))
    }

    async pick(event) {
        const uuid = event.currentTarget?.dataset?.plConnectUserUuid
        if (!uuid) return

        const mode = this.mode
        const startCall = this.startCall

        const result = await apiPost(ENDPOINTS.openDirect, { partner_uuid: uuid })

        if (result.successful !== true) {
            this.showError(result.successful_text)
            return
        }

        this.close()

        const target = new URL("/pl_connect_workspace/chat_element", window.location.origin)
        target.searchParams.set("chat", result.chat.uuid)
        if (mode === "call" && startCall) target.searchParams.set("start_call", startCall)

        window.location.href = target.toString()
    }

    showError(reason) {
        if (!this.hasErrorTarget) return

        this.errorTarget.textContent = reason === "unauthorized" ? this.i18nValue.session_expired : this.i18nValue.error
        this.errorTarget.classList.remove("hidden")
    }

    hideError() {
        if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
    }
}
