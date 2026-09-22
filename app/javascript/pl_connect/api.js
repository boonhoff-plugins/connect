// pl_connect/api.js
//
// Thin client for PlConnectApiController.
//
// == CSRF
// ApplicationController runs `protect_from_forgery with: :null_session` for
// JSON requests. A request without a valid X-CSRF-Token therefore does not fail
// with 422 - it silently loses its session and is answered with 401 by the
// controller's _require_user. Every request built here sends the token, and
// this must not be "simplified away".
//
// == Error handling
// The API always answers with { successful: true|false, ... }. Transport level
// failures (network down, 401 after a session timeout, 500) are normalised into
// the same shape so callers only ever have to look at one field.

// Endpoint paths are literals on purpose: they are declared explicitly in the
// plugin's config/routes.rb and are part of the API contract, so a typo here
// should be visible in one place rather than assembled from fragments.
export const ENDPOINTS = {
  conversations: "/pl_connect_api/conversations",
  messages: "/pl_connect_api/messages",
  thread: "/pl_connect_api/thread",
  search: "/pl_connect_api/search",
  users: "/pl_connect_api/users",
  presence: "/pl_connect_api/presence",
  downloadAttachment: "/pl_connect_api/download_attachment",
  openDirect: "/pl_connect_api/open_direct",
  createGroup: "/pl_connect_api/create_group",
  createMessage: "/pl_connect_api/create_message",
  updateMessage: "/pl_connect_api/update_message",
  deleteMessage: "/pl_connect_api/delete_message",
  toggleReaction: "/pl_connect_api/toggle_reaction",
  markRead: "/pl_connect_api/mark_read",
  uploadAttachment: "/pl_connect_api/upload_attachment",
  startCall: "/pl_connect_api/start_call",
  answerCall: "/pl_connect_api/answer_call",
  hangupCall: "/pl_connect_api/hangup_call",
  callMediaState: "/pl_connect_api/call_media_state",
  uploadVoicemail: "/pl_connect_api/upload_voicemail"
}

export function csrfToken() {
  return document.querySelector("meta[name='csrf-token']")?.content || ""
}

// Builds a download URL for an attachment. Used as an href, so it has to be a
// URL rather than a fetch - the browser handles Content-Disposition itself.
export function attachmentUrl(uuid) {
  const url = new URL(ENDPOINTS.downloadAttachment, window.location.origin)
  url.searchParams.set("uuid", uuid)
  return url.toString()
}

export async function apiGet(path, params = {}) {
  const url = new URL(path, window.location.origin)

  Object.entries(params).forEach(([key, value]) => {
    if (value === null || value === undefined || value === "") return

    // Rails expects repeated "key[]" parameters for arrays.
    if (Array.isArray(value)) {
      value.forEach((entry) => url.searchParams.append(`${key}[]`, entry))
    } else {
      url.searchParams.set(key, value)
    }
  })

  return request(url.toString(), {
    method: "GET",
    headers: { Accept: "application/json", "X-CSRF-Token": csrfToken() }
  })
}

export async function apiPost(path, body = {}) {
  return request(path, {
    method: "POST",
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      "X-CSRF-Token": csrfToken()
    },
    body: JSON.stringify(body)
  })
}

// Multipart upload. Content-Type is deliberately not set: the browser has to
// generate it together with the multipart boundary.
export async function apiUpload(path, formData) {
  return request(path, {
    method: "POST",
    headers: { Accept: "application/json", "X-CSRF-Token": csrfToken() },
    body: formData
  })
}

async function request(url, options) {
  try {
    // same-origin keeps the session cookie on the request without ever sending
    // it to a third party.
    const response = await fetch(url, { credentials: "same-origin", ...options })

    if (response.status === 401) {
      return { successful: false, successful_text: "unauthorized", status: 401 }
    }

    const payload = await response.json().catch(() => null)

    if (payload === null) {
      return { successful: false, successful_text: "invalid_response", status: response.status }
    }

    return { status: response.status, ...payload }
  } catch (error) {
    // Never log the request body: message contents are personal data
    // (GDPR Art. 5 (1) c). The error class and message are enough to debug a
    // transport problem.
    console.error(`pl_connect api: ${error.name}: ${error.message}`)
    return { successful: false, successful_text: "network_error", status: 0 }
  }
}
