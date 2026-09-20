// pl_connect/dom.js
//
// Small DOM helpers shared by the Connect controllers.
//
// == Security note
// Everything in here that accepts user supplied content writes it through
// textContent. The single exception in the whole chat UI is the message body,
// which PlConnect::MessageSanitizer has already sanitised server side; it is
// inserted in pl_connect_chat_controller.js and nowhere else. Sender logins,
// file names, conversation titles and search terms must never be passed to
// innerHTML.

// Creates an element and applies the given options in one call, so the
// rendering code reads as a tree instead of as a sequence of assignments.
//
//   el("span", { class: "badge", text: login })
//
//   options.text     -> textContent (safe for user input)
//   options.class    -> className
//   options.dataset  -> data-* attributes
//   options.attrs    -> arbitrary attributes
//   options.children -> appended child nodes
export function el(tag, options = {}) {
  const node = document.createElement(tag)

  if (options.class) node.className = options.class
  if (options.text !== undefined && options.text !== null) node.textContent = String(options.text)

  Object.entries(options.dataset || {}).forEach(([ key, value ]) => {
    if (value !== undefined && value !== null) node.dataset[key] = String(value)
  })

  Object.entries(options.attrs || {}).forEach(([ key, value ]) => {
    if (value !== undefined && value !== null) node.setAttribute(key, String(value))
  })

  ;(options.children || []).forEach((child) => {
    if (child) node.appendChild(child)
  })

  return node
}

export function clear(node) {
  if (node) node.replaceChildren()
}

export function toggle(node, visible) {
  if (node) node.classList.toggle("hidden", !visible)
}

// Two uppercase letters for an avatar placeholder. Mirrors the server side
// helper pl_connect_initials so a conversation looks identical before and
// after the first live update.
export function initials(text) {
  const value = String(text || "").trim()
  if (value === "") return "?"

  const parts = value.split(/[\s._-]+/).filter(Boolean)
  const source = parts.length > 1 ? parts[0][0] + parts[1][0] : value.slice(0, 2)

  return source.toUpperCase()
}

// Short, locale aware clock time used on every message.
export function clockTime(isoString) {
  const date = parseDate(isoString)
  if (date === null) return ""

  return date.toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" })
}

// Day separator label. Uses the browser locale instead of a hard coded format
// so the chat matches the user's regional settings.
export function dayLabel(isoString, i18n = {}) {
  const date = parseDate(isoString)
  if (date === null) return ""

  const today = new Date()
  const yesterday = new Date(today.getTime() - 86400000)

  if (isSameDay(date, today)) return i18n.today || ""
  if (isSameDay(date, yesterday)) return i18n.yesterday || ""

  return date.toLocaleDateString([], { year: "numeric", month: "long", day: "numeric" })
}

export function dayKey(isoString) {
  const date = parseDate(isoString)
  if (date === null) return ""

  return `${date.getFullYear()}-${date.getMonth()}-${date.getDate()}`
}

export function parseDate(isoString) {
  if (!isoString) return null

  const date = new Date(isoString)
  return Number.isNaN(date.getTime()) ? null : date
}

function isSameDay(a, b) {
  return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate()
}

// Trailing debounce. Used for the typing indicator and the search input so a
// fast typist does not produce one request per keystroke.
export function debounce(fn, delay) {
  let timer = null

  return (...args) => {
    if (timer !== null) clearTimeout(timer)
    timer = setTimeout(() => {
      timer = null
      fn(...args)
    }, delay)
  }
}
