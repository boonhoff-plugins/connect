// pl_connect/message_renderer.js
//
// Turns the JSON produced by PlConnect::MessageSerializer into DOM nodes.
//
// == Why not innerHTML for the whole bubble
// Only `message.body` has been through PlConnect::MessageSanitizer on the
// server. Everything else (sender_login, file_name, emoji, system event data)
// is raw user input and is written via textContent. Building the bubble node by
// node makes that distinction impossible to get wrong by accident: there is
// exactly one innerHTML assignment in this file and it is commented as such.
import { attachmentUrl } from "./api"
import { el, clockTime, initials } from "./dom"

// Reactions offered by the quick picker. Kept short on purpose - a full emoji
// palette is a separate feature and would need a picker component.
export const QUICK_REACTIONS = ["👍", "🎉", "❤️", "😄", "👀", "🙏"]

export default class MessageRenderer {
  // viewerUuid - uuid of the logged in user, used to align own messages right
  // i18n       - flat object of translated strings handed over from the server
  constructor({ viewerUuid, i18n }) {
    this.viewerUuid = viewerUuid
    this.i18n = i18n || {}
  }

  // Full message row including avatar, header, body, attachments and
  // reactions. `grouped` suppresses avatar and header for consecutive messages
  // of the same sender, which is what makes a conversation readable.
  render(message, { grouped = false } = {}) {
    if (message.f_type === "system" || message.f_type === "call_event") {
      return this.renderSystem(message)
    }

    const own = message.own === true

    const row = el("div", {
      class: `group flex gap-2 px-4 ${grouped ? "mt-0.5" : "mt-4"} ${own ? "flex-row-reverse" : ""}`,
      dataset: {
        plConnectMessageUuid: message.uuid,
        plConnectMessageSender: message.sender_uuid || "",
        plConnectMessageSentAt: message.sent_at || ""
      }
    })

    row.appendChild(grouped ? el("span", { class: "w-8 shrink-0" }) : this.renderAvatar(message, own))

    const column = el("div", { class: `flex min-w-0 max-w-[75%] flex-col ${own ? "items-end" : "items-start"}` })

    if (!grouped) column.appendChild(this.renderHeader(message, own))

    column.appendChild(this.renderBubble(message, own))

    if ((message.attachments || []).length > 0) {
      column.appendChild(this.renderAttachments(message))
    }

    column.appendChild(this.renderReactions(message))
    column.appendChild(this.renderActions(message))

    row.appendChild(column)

    return row
  }

  renderAvatar(message, own) {
    return el("span", {
      class: `flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-[11px] font-semibold ${own ? "bg-primary text-primary-content" : "bg-base-300"
        }`,
      text: initials(message.sender_login),
      attrs: { title: message.sender_login || "" }
    })
  }

  renderHeader(message, own) {
    return el("div", {
      class: `mb-0.5 flex items-baseline gap-2 text-[11px] text-base-content/60 ${own ? "flex-row-reverse" : ""}`,
      children: [
        el("span", { class: "font-medium text-base-content/80", text: message.sender_login || "" }),
        el("span", { text: clockTime(message.sent_at) })
      ]
    })
  }

  renderBubble(message, own) {
    const bubble = el("div", {
      class: `lexxy-content w-fit max-w-full break-words rounded-2xl px-3 py-2 text-sm ${own ? "bg-primary text-primary-content" : "bg-base-100"
        }`
    })

    // The ONLY innerHTML in the chat UI.
    //
    // message.body was produced by PlConnect::MessageSanitizer, which runs
    // Rails::HTML5::SafeListSanitizer against an explicit allow list after
    // stripping script/style nodes with Nokogiri. Rendering it as HTML is what
    // makes formatting, links and mentions work. Do not extend this to any
    // other field, and do not remove the server side sanitising in the belief
    // that it can be done here - by the time the payload reaches this line it
    // may also have come from an ActionCable broadcast.
    bubble.innerHTML = message.body || ""

    if (message.edited_at) {
      bubble.appendChild(
        el("span", {
          class: "ml-2 align-baseline text-[10px] opacity-60",
          text: this.i18n.edited || ""
        })
      )
    }

    return bubble
  }

  renderAttachments(message) {
    const list = el("div", { class: "mt-1 flex flex-col gap-1" })

    message.attachments.forEach((attachment) => {
      const href = attachmentUrl(attachment.uuid)
      // Strip any "; codecs=..." suffix before comparing, mirroring the
      // defensive parsing AttachmentService#download_content_type already
      // does server side for the same content_type value.
      const contentType = String(attachment.content_type || "").split(";")[0].trim()

      if (attachment.inline && contentType.startsWith("audio/")) {
        // Voicemails and any other recorded/attached audio (see
        // PlConnectApiController#upload_voicemail) render as an inline
        // player rather than the generic download-link row below - a
        // voicemail the recipient cannot play without downloading it first
        // would defeat the point of the feature.
        list.appendChild(
          el("audio", {
            class: "max-w-full",
            attrs: { src: href, controls: "", preload: "none" }
          })
        )
        return
      }

      if (attachment.inline) {
        // Inline preview for images. The alt text is the file name and is set
        // through the attrs helper, i.e. as an attribute value, never as HTML.
        const image = el("img", {
          class: "max-h-64 max-w-full rounded-lg border border-base-300 object-contain",
          attrs: { src: href, alt: attachment.file_name || "", loading: "lazy" }
        })

        list.appendChild(
          el("a", { class: "block", attrs: { href: href, target: "_blank", rel: "noopener" }, children: [image] })
        )
        return
      }

      list.appendChild(
        el("a", {
          class: "flex items-center gap-2 rounded-lg border border-base-300 bg-base-100 px-2 py-1 text-xs hover:bg-base-200",
          attrs: { href: href, target: "_blank", rel: "noopener" },
          children: [
            el("i", { class: "fa-solid fa-paperclip opacity-60", attrs: { "aria-hidden": "true" } }),
            el("span", { class: "truncate", text: attachment.file_name || "" }),
            el("span", { class: "ml-auto shrink-0 opacity-60", text: attachment.human_size || "" })
          ]
        })
      )
    })

    return list
  }

  renderReactions(message) {
    const container = el("div", {
      class: "mt-1 flex flex-wrap gap-1",
      dataset: { plConnectReactions: message.uuid }
    })

    this.fillReactions(container, message.uuid, message.reactions || [])

    return container
  }

  // Also used to replace the reaction row in place when a "reaction.changed"
  // event arrives, so the surrounding message does not have to be re-rendered.
  fillReactions(container, messageUuid, reactions) {
    container.replaceChildren()
    container.classList.toggle("hidden", reactions.length === 0)

    reactions.forEach((reaction) => {
      container.appendChild(
        el("button", {
          class: `btn btn-xs gap-1 ${reaction.reacted ? "btn-primary" : "btn-ghost border border-base-300"}`,
          attrs: { type: "button" },
          dataset: {
            action: "pl-connect-chat#toggleReaction",
            plConnectMessageUuid: messageUuid,
            plConnectEmoji: reaction.emoji
          },
          children: [
            el("span", { text: reaction.emoji }),
            el("span", { class: "text-[10px]", text: reaction.count })
          ]
        })
      )
    })
  }

  // Hover toolbar. Rendered for every message but only made visible on hover /
  // keyboard focus via the "group" class on the row.
  renderActions(message) {
    const bar = el("div", {
      class: "mt-0.5 flex gap-1 opacity-0 transition-opacity focus-within:opacity-100 group-hover:opacity-100"
    })

    QUICK_REACTIONS.forEach((emoji) => {
      bar.appendChild(
        el("button", {
          class: "btn btn-ghost btn-xs px-1",
          attrs: { type: "button", title: this.i18n.react || "" },
          dataset: {
            action: "pl-connect-chat#toggleReaction",
            plConnectMessageUuid: message.uuid,
            plConnectEmoji: emoji
          },
          text: emoji
        })
      )
    })

    if (message.own === true) {
      bar.appendChild(
        el("button", {
          class: "btn btn-ghost btn-xs px-1",
          attrs: { type: "button", title: this.i18n.edit || "" },
          dataset: { action: "pl-connect-chat#startEdit", plConnectMessageUuid: message.uuid },
          children: [el("i", { class: "fa-solid fa-pen text-[10px]", attrs: { "aria-hidden": "true" } })]
        })
      )

      bar.appendChild(
        el("button", {
          class: "btn btn-ghost btn-xs px-1 text-error",
          attrs: { type: "button", title: this.i18n.delete || "" },
          dataset: { action: "pl-connect-chat#deleteMessage", plConnectMessageUuid: message.uuid },
          children: [el("i", { class: "fa-solid fa-trash text-[10px]", attrs: { "aria-hidden": "true" } })]
        })
      )
    }

    return bar
  }

  // System messages ("X joined", call events). They carry no user written body,
  // so they are rendered as a centred, non-interactive line.
  renderSystem(message) {
    return el("div", {
      class: "my-3 flex justify-center px-4",
      dataset: {
        plConnectMessageUuid: message.uuid,
        plConnectMessageSentAt: message.sent_at || ""
      },
      children: [
        el("span", {
          class: "rounded-full bg-base-300/60 px-3 py-1 text-[11px] text-base-content/70",
          text: this.systemText(message)
        })
      ]
    })
  }

  // Translations for system events come from the server as a flat map keyed by
  // system_event_key ("member.joined", "call.started", ...). Placeholders are
  // filled from system_event_data, which is the payload the server stored with
  // the event. An unknown key falls back to the plain body and finally to the
  // key itself, so a missing translation is visible but never blank.
  systemText(message) {
    const key = message.system_event_key
    const template = key ? (this.i18n.system || {})[key] : null

    if (!template) return message.body_plain || key || ""

    const data = message.system_event_data || {}

    return String(template).replace(/%\{(\w+)\}/g, (match, name) => {
      const value = data[name]
      return value === undefined || value === null ? match : String(value)
    })
  }

  // Day separator between two messages that were sent on different days.
  renderDaySeparator(label) {
    return el("div", {
      class: "my-4 flex items-center gap-3 px-4",
      children: [
        el("span", { class: "h-px flex-1 bg-base-300" }),
        el("span", { class: "text-[11px] uppercase tracking-wide text-base-content/50", text: label }),
        el("span", { class: "h-px flex-1 bg-base-300" })
      ]
    })
  }
}
