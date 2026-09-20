// pl_connect_chat_controller.js
//
// The chat surface of the Connect workspace.
//
// Responsibilities:
//   * open a conversation (server rendered sidebar -> message pane)
//   * load message history with cursor based paging
//   * live updates through PlConnectChatChannel
//   * composing, editing and deleting messages
//   * reactions, typing indicator, read markers, attachments
//
// == Why one controller instead of several
// Composer, message list, typing indicator and read marker all operate on the
// same piece of state: which conversation is currently open and what its last
// message is. Splitting them would mean re-implementing that state exchange
// between controllers for no gain, so they stay together and the individual
// concerns are separated by method grouping instead.
//
// == Rendering model
// The server pushes data, not HTML (see PlConnect::ChatBroadcaster). The same
// payload can mean different things depending on what the client is showing,
// so the decision is made here and MessageRenderer builds the DOM.
import { Controller } from "@hotwired/stimulus"
import plConnectConsumer from "../pl_connect/cable"
import { ENDPOINTS, apiGet, apiPost, apiUpload } from "../pl_connect/api"
import { clear, dayKey, dayLabel, debounce, el, toggle } from "../pl_connect/dom"
import MessageRenderer from "../pl_connect/message_renderer"

// How long after the last keystroke the "is typing" signal is revoked.
const TYPING_IDLE_MS = 3000
// Minimum distance between two "still typing" signals, so holding a key down
// does not flood the channel.
const TYPING_THROTTLE_MS = 2000
// Distance from the top of the message list at which older messages are
// fetched.
const LOAD_MORE_THRESHOLD_PX = 120

export default class extends Controller {
  static targets = [
    "conversationList",
    "emptyState",
    "conversation",
    "conversationTitle",
    "conversationSubtitle",
    "messages",
    "loadingOlder",
    "typing",
    "form",
    "input",
    "richContainer",
    "richToggle",
    "fileInput",
    "sendButton",
    "editNotice",
    "search",
    "searchResults",
    "totalUnread"
  ]

  static values = {
    viewerUuid: String,
    i18n: Object,
    initialChatUuid: String
  }

  connect() {
    this.renderer = new MessageRenderer({ viewerUuid: this.viewerUuidValue, i18n: this.i18nValue })

    this.chatUuid = null
    this.subscription = null
    this.messages = []
    this.hasMore = false
    this.loadingOlder = false
    this.editingUuid = null
    this.lastTypingSentAt = 0
    this.typingUsers = new Map()
    this.richMode = false

    this.stopTyping = debounce(() => this.sendTyping(false), TYPING_IDLE_MS)
    this.runSearch = debounce(() => this.performSearch(), 300)

    // Sidebar activity for conversations that are not currently open is pushed
    // through the per-user presence stream, not through the conversation
    // stream - the client is not subscribed to conversations it is not looking
    // at. The presence controller re-dispatches it as a DOM event.
    this.onActivity = (event) => this.handleActivity(event.detail)
    document.addEventListener("pl-connect:conversation-activity", this.onActivity)

    if (this.initialChatUuidValue) this.openConversation(this.initialChatUuidValue)
  }

  disconnect() {
    document.removeEventListener("pl-connect:conversation-activity", this.onActivity)
    this.teardownSubscription()
  }

  // --- conversation selection ---------------------------------------------

  // Bound to the conversation buttons in _conversation_list.html.erb.
  selectConversation(event) {
    const uuid = event.currentTarget?.dataset?.plConnectConversationUuid
    if (!uuid || uuid === this.chatUuid) return

    this.openConversation(uuid)
  }

  async openConversation(uuid) {
    // The controller is attached to the workspace layout so that the search
    // field in the top bar and the unread badge in the rail share its scope.
    // Sections without a message pane (calendar, calls) therefore run the same
    // controller but have nowhere to render a conversation into.
    if (!this.hasMessagesTarget) return

    this.teardownSubscription()

    this.chatUuid = uuid
    this.editingUuid = null
    this.messages = []
    this.typingUsers.clear()

    this.highlightConversation(uuid)
    toggle(this.emptyStateTarget, false)
    toggle(this.conversationTarget, true)
    clear(this.messagesTarget)
    this.renderTyping()

    const result = await apiGet(ENDPOINTS.messages, { chat_uuid: uuid })

    // A conversation can be closed again while its history is still loading.
    if (this.chatUuid !== uuid) return

    if (result.successful !== true) {
      this.showPaneError(result)
      return
    }

    this.applyConversationHeader(result.chat)
    this.messages = result.messages || []
    this.hasMore = result.has_more === true

    this.renderAllMessages()
    this.scrollToBottom()
    this.subscribeToChat(uuid)
    this.markRead()
    this.focusComposer()

    // Lets pl_connect_call_controller.js start a call that was requested
    // before this conversation finished loading (the shared user picker's
    // "start a call" flow navigates here with ?start_call=audio|video).
    document.dispatchEvent(new CustomEvent("pl-connect:conversation-opened", { detail: { uuid } }))
  }

  highlightConversation(uuid) {
    this.conversationButtons().forEach((button) => {
      const active = button.dataset.plConnectConversationUuid === uuid
      button.classList.toggle("bg-base-200", active)
      button.setAttribute("aria-current", active ? "true" : "false")
    })
  }

  conversationButtons() {
    if (!this.hasConversationListTarget) return []
    return Array.from(this.conversationListTarget.querySelectorAll("[data-pl-connect-conversation-uuid]"))
  }

  conversationButton(uuid) {
    return this.conversationButtons().find((button) => button.dataset.plConnectConversationUuid === uuid) || null
  }

  applyConversationHeader(chat) {
    if (!chat) return

    if (this.hasConversationTitleTarget) this.conversationTitleTarget.textContent = chat.title || ""

    if (this.hasConversationSubtitleTarget) {
      const parts = []
      if (chat.f_type) parts.push(this.i18nValue[`type_${chat.f_type}`] || chat.f_type)
      if (chat.message_count) parts.push(`${chat.message_count} ${this.i18nValue.messages || ""}`.trim())
      this.conversationSubtitleTarget.textContent = parts.join(" · ")
    }

    // A read-only or archived conversation must not offer a composer - the
    // server would reject the message anyway, and a disabled control is more
    // honest than an error after the fact.
    const writable = chat.read_only !== true && chat.archived !== true
    toggle(this.formTarget, writable)
  }

  showPaneError(result) {
    clear(this.messagesTarget)
    this.messagesTarget.appendChild(
      el("p", {
        class: "p-6 text-center text-sm text-error",
        text: result.successful_text === "unauthorized"
          ? (this.i18nValue.session_expired || "")
          : (this.i18nValue.load_failed || "")
      })
    )
  }

  // --- history / paging ----------------------------------------------------

  onMessagesScroll() {
    if (this.loadingOlder || !this.hasMore || this.chatUuid === null) return
    if (this.messagesTarget.scrollTop > LOAD_MORE_THRESHOLD_PX) return

    this.loadOlder()
  }

  async loadOlder() {
    const oldest = this.messages[0]
    if (!oldest) return

    this.loadingOlder = true
    toggle(this.loadingOlderTarget, true)

    const uuid = this.chatUuid
    const result = await apiGet(ENDPOINTS.messages, { chat_uuid: uuid, before_uuid: oldest.uuid })

    toggle(this.loadingOlderTarget, false)
    this.loadingOlder = false

    if (this.chatUuid !== uuid || result.successful !== true) return

    const older = result.messages || []
    if (older.length === 0) {
      this.hasMore = false
      return
    }

    // Keep the viewport anchored on the message the user was looking at:
    // measure the scroll height before and after prepending and restore the
    // difference, otherwise the list jumps on every page load.
    const previousHeight = this.messagesTarget.scrollHeight
    const previousTop = this.messagesTarget.scrollTop

    this.messages = older.concat(this.messages)
    this.hasMore = result.has_more === true
    this.renderAllMessages()

    this.messagesTarget.scrollTop = previousTop + (this.messagesTarget.scrollHeight - previousHeight)
  }

  // --- rendering -----------------------------------------------------------

  // Full re-render. Used after the initial load and after prepending a page of
  // older messages, because both change the grouping of the very first rows.
  renderAllMessages() {
    clear(this.messagesTarget)

    let previous = null

    this.messages.forEach((message) => {
      const separator = this.daySeparatorFor(previous, message)
      if (separator) this.messagesTarget.appendChild(separator)

      this.messagesTarget.appendChild(
        this.renderer.render(message, { grouped: this.isGrouped(previous, message, separator !== null) })
      )

      previous = message
    })
  }

  appendMessage(message) {
    const previous = this.messages[this.messages.length - 1] || null
    const separator = this.daySeparatorFor(previous, message)

    if (separator) this.messagesTarget.appendChild(separator)

    this.messagesTarget.appendChild(
      this.renderer.render(message, { grouped: this.isGrouped(previous, message, separator !== null) })
    )

    this.messages.push(message)
  }

  daySeparatorFor(previous, message) {
    const key = dayKey(message.sent_at)
    if (key === "") return null
    if (previous !== null && dayKey(previous.sent_at) === key) return null

    return this.renderer.renderDaySeparator(dayLabel(message.sent_at, this.i18nValue))
  }

  // Consecutive messages of the same sender within five minutes are shown
  // without a repeated avatar and header.
  isGrouped(previous, message, dayChanged) {
    if (dayChanged || previous === null) return false
    if (previous.f_type !== message.f_type) return false
    if (message.f_type !== "message") return false
    if (previous.sender_uuid !== message.sender_uuid) return false

    const gap = new Date(message.sent_at).getTime() - new Date(previous.sent_at).getTime()
    return Number.isFinite(gap) && gap >= 0 && gap < 300000
  }

  messageNode(uuid) {
    return this.messagesTarget.querySelector(`[data-pl-connect-message-uuid="${CSS.escape(uuid)}"]`)
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  isScrolledToBottom() {
    const node = this.messagesTarget
    return node.scrollHeight - node.scrollTop - node.clientHeight < 80
  }

  // --- composing -----------------------------------------------------------

  // Enter sends, Shift+Enter inserts a newline - the convention every chat
  // client uses. Escape leaves edit mode.
  onComposerKeydown(event) {
    if (event.key === "Escape" && this.editingUuid !== null) {
      event.preventDefault()
      this.cancelEdit()
      return
    }

    if (event.key !== "Enter" || event.shiftKey || this.richMode) return

    event.preventDefault()
    this.submit()
  }

  onComposerInput() {
    this.autoGrow()
    this.sendTypingThrottled()
    this.stopTyping()
  }

  autoGrow() {
    const node = this.inputTarget
    node.style.height = "auto"
    // Capped so a long message cannot push the message list off screen.
    node.style.height = `${Math.min(node.scrollHeight, 200)}px`
  }

  // Bound to the form's submit event as well as to the send button.
  submit(event) {
    if (event) event.preventDefault()

    const body = this.readComposer()
    if (body.trim() === "") return

    if (this.editingUuid !== null) {
      this.submitEdit(body)
    } else {
      this.submitNew(body)
    }
  }

  async submitNew(body) {
    const uuid = this.chatUuid
    if (uuid === null) return

    // Captured before clearComposer() runs: that call resets the file input's
    // .value (the only way to un-select files in a <input type="file">), which
    // would otherwise wipe the selection before uploadPendingFiles() gets to
    // read it.
    const files = this.pendingFiles()

    this.setComposerBusy(true)
    const result = await apiPost(ENDPOINTS.createMessage, { chat_uuid: uuid, body: body })
    this.setComposerBusy(false)

    if (result.successful !== true) {
      this.flashComposerError(result)
      return
    }

    this.clearComposer()
    this.sendTyping(false)

    // The sender also receives the broadcast, but rendering immediately keeps
    // the UI responsive when the WebSocket is slow. handleIncoming() drops the
    // duplicate by uuid.
    if (this.chatUuid === uuid && !this.messageNode(result.message.uuid)) {
      this.appendMessage(result.message)
      this.scrollToBottom()
    }

    if (files.length > 0) await this.uploadPendingFiles(result.message.uuid, files)
  }

  async submitEdit(body) {
    const uuid = this.chatUuid
    const messageUuid = this.editingUuid

    this.setComposerBusy(true)
    const result = await apiPost(ENDPOINTS.updateMessage, {
      chat_uuid: uuid,
      message_uuid: messageUuid,
      body: body
    })
    this.setComposerBusy(false)

    if (result.successful !== true) {
      this.flashComposerError(result)
      return
    }

    this.cancelEdit()
    this.replaceMessage(result.message)
  }

  startEdit(event) {
    const uuid = event.currentTarget?.dataset?.plConnectMessageUuid
    const message = this.messages.find((entry) => entry.uuid === uuid)
    if (!message || message.own !== true) return

    this.editingUuid = uuid
    this.writeComposer(message.body_plain || "")
    toggle(this.editNoticeTarget, true)
    this.focusComposer()
  }

  cancelEdit() {
    this.editingUuid = null
    this.clearComposer()
    toggle(this.editNoticeTarget, false)
  }

  async deleteMessage(event) {
    const uuid = event.currentTarget?.dataset?.plConnectMessageUuid
    if (!uuid) return
    if (!window.confirm(this.i18nValue.confirm_delete || "")) return

    const result = await apiPost(ENDPOINTS.deleteMessage, { chat_uuid: this.chatUuid, message_uuid: uuid })
    if (result.successful !== true) return

    this.removeMessage(uuid)
  }

  replaceMessage(message) {
    const index = this.messages.findIndex((entry) => entry.uuid === message.uuid)
    if (index === -1) return

    this.messages[index] = message

    const node = this.messageNode(message.uuid)
    if (node) node.replaceWith(this.renderer.render(message))
  }

  removeMessage(uuid) {
    this.messages = this.messages.filter((entry) => entry.uuid !== uuid)
    this.messageNode(uuid)?.remove()
  }

  // --- composer modes ------------------------------------------------------

  // Hybrid composer: a plain textarea for normal typing and a Lexxy editor for
  // formatted messages. The rich editor is only instantiated when it is first
  // requested - mounting a full Lexical instance for every conversation would
  // be a noticeable cost for something most messages do not need.
  toggleRichMode(event) {
    if (event) event.preventDefault()

    this.richMode = !this.richMode

    if (this.richMode) {
      this.mountRichEditor()
      this.richEditor.value = this.plainToHtml(this.inputTarget.value)
    } else if (this.richEditor) {
      this.inputTarget.value = this.htmlToPlain(this.richEditor.value)
      this.autoGrow()
    }

    toggle(this.inputTarget, !this.richMode)
    toggle(this.richContainerTarget, this.richMode)
    this.richToggleTarget.classList.toggle("btn-active", this.richMode)
    this.focusComposer()
  }

  mountRichEditor() {
    if (this.richEditor) return

    // <lexxy-editor> is a form associated custom element registered by
    // lexxy_config.js, which is part of the application bundle. It exposes a
    // .value property holding sanitisable HTML, which is exactly the shape
    // PlConnect::MessageSanitizer expects on the server.
    this.richEditor = document.createElement("lexxy-editor")
    this.richEditor.setAttribute("placeholder", this.i18nValue.composer_placeholder || "")
    this.richEditor.style.setProperty("--lexxy-content-max-height", "200px")

    this.richContainerTarget.appendChild(this.richEditor)
  }

  readComposer() {
    if (this.richMode && this.richEditor) return this.richEditor.value || ""
    return this.inputTarget.value || ""
  }

  writeComposer(text) {
    if (this.richMode && this.richEditor) {
      this.richEditor.value = this.plainToHtml(text)
      return
    }

    this.inputTarget.value = text
    this.autoGrow()
  }

  clearComposer() {
    this.inputTarget.value = ""
    this.autoGrow()
    if (this.richEditor) this.richEditor.value = "<p><br></p>"
    if (this.hasFileInputTarget) this.fileInputTarget.value = ""
    this.renderPendingFiles()
  }

  focusComposer() {
    if (this.richMode && this.richEditor) {
      this.richEditor.focus?.()
      return
    }

    this.inputTarget.focus()
  }

  setComposerBusy(busy) {
    this.inputTarget.disabled = busy
    if (this.hasSendButtonTarget) this.sendButtonTarget.disabled = busy
  }

  flashComposerError(result) {
    const text = result.successful_text === "unauthorized"
      ? (this.i18nValue.session_expired || "")
      : (result.successful_text || this.i18nValue.send_failed || "")

    this.inputTarget.setAttribute("title", text)
    this.inputTarget.classList.add("input-error")
    setTimeout(() => this.inputTarget.classList.remove("input-error"), 2500)
  }

  // A textarea holds plain text; the server sanitiser works on HTML. Escaping
  // here prevents a literal "<b>" typed by the user from turning into markup.
  plainToHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return `<p>${div.innerHTML.replace(/\n/g, "<br>")}</p>`
  }

  htmlToPlain(html) {
    const div = document.createElement("div")
    div.innerHTML = html || ""
    return div.textContent || ""
  }

  // --- attachments ---------------------------------------------------------

  pendingFiles() {
    if (!this.hasFileInputTarget || !this.fileInputTarget.files) return []
    return Array.from(this.fileInputTarget.files)
  }

  onFilesSelected() {
    this.renderPendingFiles()
  }

  renderPendingFiles() {
    const list = this.element.querySelector("[data-pl-connect-pending-files]")
    if (!list) return

    clear(list)
    const files = this.pendingFiles()
    toggle(list, files.length > 0)

    files.forEach((file) => {
      list.appendChild(
        el("span", {
          class: "badge badge-ghost gap-1 text-[11px]",
          children: [
            el("i", { class: "fa-solid fa-paperclip", attrs: { "aria-hidden": "true" } }),
            // File names are user supplied - textContent only.
            el("span", { class: "max-w-[10rem] truncate", text: file.name })
          ]
        })
      )
    })
  }

  // Attachments are uploaded after the message exists, because the server side
  // AttachmentService validates them against the message they belong to.
  //
  // `files` must be captured by the caller before clearComposer() runs -
  // clearing the file input's .value (the only way to un-select files) would
  // otherwise wipe the selection first.
  async uploadPendingFiles(messageUuid, files) {
    for (const file of files) {
      const formData = new FormData()
      formData.append("chat_uuid", this.chatUuid)
      formData.append("message_uuid", messageUuid)
      formData.append("file", file)

      const result = await apiUpload(ENDPOINTS.uploadAttachment, formData)
      if (result.successful === true) this.replaceMessage(result.message)
    }

    this.fileInputTarget.value = ""
    this.renderPendingFiles()
    this.scrollToBottom()
  }

  // --- reactions -----------------------------------------------------------

  async toggleReaction(event) {
    const button = event.currentTarget
    const messageUuid = button?.dataset?.plConnectMessageUuid
    const emoji = button?.dataset?.plConnectEmoji
    if (!messageUuid || !emoji) return

    const result = await apiPost(ENDPOINTS.toggleReaction, {
      chat_uuid: this.chatUuid,
      message_uuid: messageUuid,
      emoji: emoji
    })

    if (result.successful !== true) return

    this.applyReactions(messageUuid, result.reactions || [])
  }

  applyReactions(messageUuid, reactions) {
    const message = this.messages.find((entry) => entry.uuid === messageUuid)
    if (message) message.reactions = reactions

    const container = this.messagesTarget.querySelector(
      `[data-pl-connect-reactions="${CSS.escape(messageUuid)}"]`
    )
    if (container) this.renderer.fillReactions(container, messageUuid, reactions)
  }

  // --- read state ----------------------------------------------------------

  async markRead() {
    const last = this.messages[this.messages.length - 1]
    if (this.chatUuid === null || !last) return

    const result = await apiPost(ENDPOINTS.markRead, { chat_uuid: this.chatUuid, message_uuid: last.uuid })
    if (result.successful !== true) return

    this.setConversationUnread(this.chatUuid, 0)
    this.setTotalUnread(result.unread_total)
  }

  setConversationUnread(uuid, count) {
    const button = this.conversationButton(uuid)
    if (!button) return

    let badge = button.querySelector("[data-pl-connect-unread]")

    if (count <= 0) {
      badge?.remove()
      return
    }

    if (!badge) {
      badge = el("span", {
        class: "badge badge-primary badge-sm ml-auto shrink-0",
        dataset: { plConnectUnread: "true" }
      })
      button.querySelector("[data-pl-connect-preview-row]")?.appendChild(badge)
    }

    badge.textContent = count > 99 ? "99+" : String(count)
  }

  setTotalUnread(total) {
    if (!this.hasTotalUnreadTarget) return

    const value = Number(total) || 0
    this.totalUnreadTarget.textContent = value > 99 ? "99+" : String(value)
    toggle(this.totalUnreadTarget, value > 0)
  }

  // --- typing indicator ----------------------------------------------------

  sendTypingThrottled() {
    const now = Date.now()
    if (now - this.lastTypingSentAt < TYPING_THROTTLE_MS) return

    this.lastTypingSentAt = now
    this.sendTyping(true)
  }

  sendTyping(active) {
    if (this.subscription === null) return

    // Typing is pure signalling and is never persisted on the server, so this
    // cannot be used to reconstruct when somebody was writing.
    this.subscription.perform("typing", { active: active })
    if (!active) this.lastTypingSentAt = 0
  }

  handleTyping(payload) {
    if (payload.user_uuid === this.viewerUuidValue) return

    if (payload.active) {
      this.typingUsers.set(payload.user_uuid, payload.user_login || "")
      // Safety net: if the "stopped typing" event is lost (tab crash, dropped
      // frame) the indicator would otherwise stay forever.
      clearTimeout(this.typingTimers?.get(payload.user_uuid))
      this.typingTimers = this.typingTimers || new Map()
      this.typingTimers.set(
        payload.user_uuid,
        setTimeout(() => {
          this.typingUsers.delete(payload.user_uuid)
          this.renderTyping()
        }, TYPING_IDLE_MS + 2000)
      )
    } else {
      this.typingUsers.delete(payload.user_uuid)
    }

    this.renderTyping()
  }

  renderTyping() {
    const logins = Array.from(this.typingUsers.values()).filter(Boolean)

    toggle(this.typingTarget, logins.length > 0)
    if (logins.length === 0) return

    const template = logins.length === 1 ? this.i18nValue.typing_one : this.i18nValue.typing_many
    this.typingTarget.textContent = String(template || "").replace("%{names}", logins.join(", "))
  }

  // --- live updates --------------------------------------------------------

  subscribeToChat(uuid) {
    const controller = this

    this.subscription = plConnectConsumer().subscriptions.create(
      { channel: "PlConnectChatChannel", chat_uuid: uuid },
      {
        received(payload) {
          controller.handleIncoming(payload)
        }
      }
    )
  }

  teardownSubscription() {
    if (this.subscription === null) return

    this.sendTyping(false)
    this.subscription.unsubscribe()
    this.subscription = null
  }

  handleIncoming(payload) {
    if (!payload || payload.chat_uuid !== this.chatUuid) return

    switch (payload.event) {
      case "message.created": {
        // The sender already rendered this message optimistically.
        if (this.messageNode(payload.message.uuid)) return

        const wasAtBottom = this.isScrolledToBottom()
        this.appendMessage(payload.message)
        if (wasAtBottom) {
          this.scrollToBottom()
          this.markRead()
        }
        break
      }
      case "message.updated":
        this.replaceMessage(payload.message)
        break
      case "message.deleted":
        this.removeMessage(payload.message_uuid)
        break
      case "reaction.changed":
        this.applyReactions(payload.message_uuid, payload.reactions || [])
        break
      case "typing":
        this.handleTyping(payload)
        break
      default:
        // Call lifecycle events (call.started/accepted/declined/ended/missed/
        // left) are broadcast on this same chat stream so every member sees
        // them, but the actual call UI belongs to pl-connect-call. Forwarding
        // as a DOM event keeps the two controllers independent - see
        // pl_connect_call_controller.js for the consumer.
        if (typeof payload.event === "string" && payload.event.startsWith("call.")) {
          document.dispatchEvent(new CustomEvent("pl-connect:call-event", { detail: payload }))
        }
        // read / member.changed are handled in later phases. Ignoring an
        // unknown event here keeps it from breaking the open conversation.
        break
    }
  }

  // Sidebar update for a conversation the user is not currently looking at.
  handleActivity(payload) {
    if (!payload || !payload.chat_uuid) return
    if (payload.chat_uuid === this.chatUuid) return

    this.setConversationUnread(payload.chat_uuid, Number(payload.unread_count) || 0)

    const button = this.conversationButton(payload.chat_uuid)
    const preview = button?.querySelector("[data-pl-connect-preview-text]")
    // The preview is plain text produced by MessageSanitizer.preview.
    if (preview && payload.preview) preview.textContent = payload.preview
  }

  // --- search --------------------------------------------------------------

  onSearchInput() {
    this.runSearch()
  }

  async performSearch() {
    // Search lives in the layout top bar, so the targets exist on every
    // workspace section - but the guard keeps the controller usable if a
    // section ever drops the field.
    if (!this.hasSearchTarget || !this.hasSearchResultsTarget) return

    const term = this.searchTarget.value.trim()

    if (term.length < 2) {
      clear(this.searchResultsTarget)
      toggle(this.searchResultsTarget, false)
      return
    }

    const result = await apiGet(ENDPOINTS.search, { term: term })
    if (result.successful !== true) return

    clear(this.searchResultsTarget)
    toggle(this.searchResultsTarget, true)

    const hits = result.messages || []

    if (hits.length === 0) {
      this.searchResultsTarget.appendChild(
        el("p", { class: "px-3 py-4 text-center text-xs text-base-content/60", text: this.i18nValue.no_results || "" })
      )
      return
    }

    hits.forEach((message) => {
      this.searchResultsTarget.appendChild(
        el("button", {
          class: "flex w-full flex-col items-start gap-0.5 px-3 py-2 text-left hover:bg-base-200",
          attrs: { type: "button" },
          dataset: { action: "pl-connect-chat#openSearchHit", plConnectConversationUuid: message.chat_uuid },
          children: [
            el("span", { class: "text-[11px] font-medium text-base-content/70", text: message.sender_login || "" }),
            // Search hits are rendered from body_plain, never from body: a hit
            // list is not a place to execute conversation markup.
            el("span", { class: "line-clamp-2 text-xs text-base-content/80", text: message.body_plain || "" })
          ]
        })
      )
    })
  }

  openSearchHit(event) {
    const uuid = event.currentTarget?.dataset?.plConnectConversationUuid
    if (!uuid) return

    clear(this.searchResultsTarget)
    toggle(this.searchResultsTarget, false)
    this.searchTarget.value = ""

    this.openConversation(uuid)
  }
}
