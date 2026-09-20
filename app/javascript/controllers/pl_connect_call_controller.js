// pl_connect_call_controller.js
//
// WebRTC signalling client for audio/video calls with screen sharing. Calls
// are a full mesh: every participant holds one direct RTCPeerConnection to
// every other participant (n*(n-1) connections in total), keyed by the
// other side's user_uuid - a 1:1 call is simply the n == 2 case of the same
// code path. PlConnectCallItem::MESH_PARTICIPANT_LIMIT caps how large a call
// is allowed to grow, because a plain mesh does not scale past a handful of
// participants (see PlConnect::CallService).
//
// Mounted on the same layout wrapper as pl-connect-chat and pl-connect-presence
// (see app/views/layouts/pl_connect.html.erb) so it can:
//   * react to an incoming call regardless of which section/conversation the
//     user currently has open (pl-connect:call-invite, from the presence
//     stream - see pl_connect_presence_controller.js)
//   * react to the call's lifecycle for the conversation that IS currently
//     open (pl-connect:call-event, forwarded from the chat stream - see
//     pl_connect_chat_controller.js)
//   * be triggered from the call/video buttons that live inside the message
//     pane partial, a child of this same wrapper element
//
// == Mesh join algorithm
// Whenever a new participant subscribes to the call's ActionCable stream, the
// channel broadcasts "peer-joined" to everyone already in the room. Every
// already-present participant reacts by creating its own new
// RTCPeerConnection for that one newcomer and sending it an SDP offer -
// addressed to that specific user_uuid via target_user_uuid, so the offer
// does not get misinterpreted by any third participant. The newcomer never
// initiates anything itself: it simply answers each offer it receives, one
// per already-present peer, until it holds a connection to everyone. This
// means there is no caller/callee role distinction any more - the only rule
// is "whoever was already there offers to whoever just arrived".
//
// == Design boundaries
//   * Both audio and video tracks are always requested up front
//     (getUserMedia({ audio: true, video: true })) and muting/camera-off is
//     done by disabling the local track, never by renegotiating a peer
//     connection. This keeps every SDP offer/answer exchange a strict
//     one-shot: no later "add track" renegotiation is needed for mute/camera,
//     and screen sharing swaps the *content* of the existing video track via
//     RTCRtpSender.replaceTrack() on every peer connection (also
//     renegotiation free).
//
// == Data protection
// No media (audio/video/screen) ever passes through the server - only the
// SDP/ICE signalling metadata does, and only for the duration of connection
// setup. Persisted call metadata (who called whom, when, how long) is written
// by PlConnect::CallService, not by this controller.
import { Controller } from "@hotwired/stimulus"
import plConnectConsumer from "../pl_connect/cable"
import { ENDPOINTS, apiPost } from "../pl_connect/api"
import { toggle } from "../pl_connect/dom"

export default class extends Controller {
    static targets = [
        "incomingBanner", "incomingLabel",
        "activePanel", "statusLabel", "remoteVideos", "localVideo",
        "audioButton", "videoButton", "screenButton"
    ]

    static values = {
        active: Boolean,
        viewerUuid: String,
        i18n: Object,
        iceServers: Array,
        // Set server side (PlConnectWorkspaceController#_resolve_pending_call)
        // from ?start_call=audio|video after the shared user picker opens/
        // creates a 1:1 chat. Only "audio", "video" or "" - never trusted
        // beyond that (see handleConversationOpened).
        pending: String
    }

    connect() {
        this.callUuid = null
        this.chatUuid = null
        this.incomingInvite = null
        // user_uuid -> { pc: RTCPeerConnection, videoEl: HTMLVideoElement|null }
        this.peers = new Map()
        this.localStream = null
        this.screenStream = null
        this.callSubscription = null
        this.audioActive = true
        this.videoActive = false
        this.screenActive = false

        this.onInvite = (event) => this.handleInvite(event)
        this.onCallEvent = (event) => this.handleCallEvent(event)
        this.onConversationOpened = () => this.handleConversationOpened()
        document.addEventListener("pl-connect:call-invite", this.onInvite)
        document.addEventListener("pl-connect:call-event", this.onCallEvent)
        document.addEventListener("pl-connect:conversation-opened", this.onConversationOpened)
    }

    disconnect() {
        document.removeEventListener("pl-connect:call-invite", this.onInvite)
        document.removeEventListener("pl-connect:call-event", this.onCallEvent)
        document.removeEventListener("pl-connect:conversation-opened", this.onConversationOpened)
        this.teardownCall()
    }

    // The chat controller owns which conversation is currently open; reading it
    // through Stimulus' own controller registry keeps the two controllers
    // decoupled (no shared state object, no duplicated tracking of "chatUuid").
    get chatController() {
        return this.application.getControllerForElementAndIdentifier(this.element, "pl-connect-chat")
    }

    // --- starting / receiving a call -----------------------------------------

    startAudioCall() {
        this.beginOutgoingCall(false)
    }

    startVideoCall() {
        this.beginOutgoingCall(true)
    }

    // Fired once the chat controller has finished opening a conversation. Only
    // acts when a call was actually requested (pendingValue set server side)
    // and clears it immediately, so switching to a different conversation
    // later never re-triggers a call by accident.
    handleConversationOpened() {
        if (!this.pendingValue) return

        const video = this.pendingValue === "video"
        this.pendingValue = ""
        this.beginOutgoingCall(video)
    }

    async beginOutgoingCall(video) {
        if (this.activeValue !== true || this.callUuid) return

        const chatUuid = this.chatController?.chatUuid
        if (!chatUuid) return

        const result = await apiPost(ENDPOINTS.startCall, { chat_uuid: chatUuid })
        if (!result.successful) return this.toast(result.successful_text)

        this.chatUuid = chatUuid
        await this.beginSession(result.call, video)
    }

    // Presence stream: an invite for any conversation, whether or not it is
    // currently open.
    handleInvite(event) {
        const payload = event.detail
        if (!payload || !payload.call_uuid || this.callUuid) return

        this.incomingInvite = payload
        const template = this.i18nValue.incoming_call || ""
        if (this.hasIncomingLabelTarget) {
            this.incomingLabelTarget.textContent = template.replace("%{login}", payload.caller_login || "")
        }
        toggle(this.incomingBannerTarget, true)
    }

    async acceptIncoming() {
        const invite = this.incomingInvite
        this.dismissIncoming()
        if (!invite) return

        const result = await apiPost(ENDPOINTS.answerCall, {
            chat_uuid: invite.chat_uuid, call_uuid: invite.call_uuid, accept: true
        })
        if (!result.successful) return this.toast(result.successful_text)

        this.chatUuid = invite.chat_uuid
        await this.beginSession(result.call, true)
    }

    async declineIncoming() {
        const invite = this.incomingInvite
        this.dismissIncoming()
        if (!invite) return

        await apiPost(ENDPOINTS.answerCall, { chat_uuid: invite.chat_uuid, call_uuid: invite.call_uuid, accept: false })
    }

    dismissIncoming() {
        this.incomingInvite = null
        toggle(this.incomingBannerTarget, false)
    }

    // --- media + peer connection ----------------------------------------------

    async beginSession(call, video) {
        this.callUuid = call.uuid
        if (Array.isArray(call.ice_servers) && call.ice_servers.length > 0) {
            this.iceServersValue = call.ice_servers
        }

        try {
            this.localStream = await navigator.mediaDevices.getUserMedia({ audio: true, video: true })
        } catch (e) {
            this.toast(this.i18nValue.media_error)
            await apiPost(ENDPOINTS.hangupCall, { chat_uuid: this.chatUuid, call_uuid: this.callUuid })
            this.resetState()
            return
        }

        this.audioActive = true
        this.videoActive = video === true
        this.localStream.getAudioTracks().forEach((track) => { track.enabled = this.audioActive })
        this.localStream.getVideoTracks().forEach((track) => { track.enabled = this.videoActive })

        if (this.hasLocalVideoTarget) this.localVideoTarget.srcObject = this.localStream
        this.renderMediaButtons()

        if (this.hasStatusLabelTarget) this.statusLabelTarget.textContent = this.i18nValue.connecting
        toggle(this.activePanelTarget, true)

        this.subscribeCallChannel(call.uuid)
    }

    subscribeCallChannel(callUuid) {
        const controller = this

        this.callSubscription = plConnectConsumer().subscriptions.create(
            { channel: "PlConnectCallChannel", call_uuid: callUuid },
            {
                received(payload) {
                    controller.handleSignallingPayload(payload)
                }
            }
        )
    }

    async handleSignallingPayload(payload) {
        if (!payload || payload.call_uuid !== this.callUuid) return
        if (payload.user_uuid === this.viewerUuidValue) return
        // Signalling addressed to someone else must never be touched, even
        // though it is broadcast to the whole room (see PlConnectCallChannel).
        if (payload.target_user_uuid && payload.target_user_uuid !== this.viewerUuidValue) return

        switch (payload.event) {
            case "peer-joined": {
                // Whoever was already in the room offers to the newcomer - there
                // is no caller/callee role any more, only "arrived earlier".
                await this.handlePeerJoined(payload.user_uuid)
                break
            }
            case "peer-left": {
                this.handlePeerLeft(payload.user_uuid)
                break
            }
            case "signal": {
                await this.handleRemoteSignal(payload)
                break
            }
            default:
                // media_state is informational only in this phase (no remote
                // mute/camera indicator yet) - ignored rather than treated as an error.
                break
        }
    }

    // Creates (or returns) the RTCPeerConnection dedicated to one remote
    // participant. Every local track is added once, up front - screen sharing
    // later replaces a track's content (see toggleScreen), it never adds a
    // second track, so this never needs to run again for the same peer.
    _ensurePeer(peerUuid) {
        const existing = this.peers.get(peerUuid)
        if (existing) return existing.pc

        const pc = new RTCPeerConnection({ iceServers: this.iceServersValue })
        this.localStream?.getTracks().forEach((track) => pc.addTrack(track, this.localStream))

        pc.ontrack = (event) => {
            this._getOrCreateRemoteVideo(peerUuid).srcObject = event.streams[0]
        }

        pc.onicecandidate = (event) => {
            if (event.candidate) {
                this.sendSignal({ type: "ice-candidate", target_user_uuid: peerUuid, data: event.candidate.toJSON() })
            }
        }

        pc.onconnectionstatechange = () => {
            if (["failed", "closed"].includes(pc.connectionState)) this.handlePeerLeft(peerUuid)
        }

        this.peers.set(peerUuid, { pc, videoEl: null })
        return pc
    }

    _getOrCreateRemoteVideo(peerUuid) {
        const peer = this.peers.get(peerUuid)
        if (peer?.videoEl) return peer.videoEl

        const video = document.createElement("video")
        video.autoplay = true
        video.playsInline = true
        video.className = "aspect-video w-full rounded bg-black object-cover"
        video.dataset.peerUuid = peerUuid
        if (this.hasRemoteVideosTarget) this.remoteVideosTarget.appendChild(video)
        if (peer) peer.videoEl = video
        return video
    }

    async handlePeerJoined(peerUuid) {
        const pc = this._ensurePeer(peerUuid)
        const offer = await pc.createOffer()
        await pc.setLocalDescription(offer)
        this.sendSignal({ type: "offer", target_user_uuid: peerUuid, data: offer })
    }

    handlePeerLeft(peerUuid) {
        const peer = this.peers.get(peerUuid)
        if (!peer) return

        peer.pc.close()
        peer.videoEl?.remove()
        this.peers.delete(peerUuid)
    }

    async handleRemoteSignal(payload) {
        const pc = this._ensurePeer(payload.user_uuid)

        switch (payload.type) {
            case "offer": {
                await pc.setRemoteDescription(new RTCSessionDescription(payload.data))
                const answer = await pc.createAnswer()
                await pc.setLocalDescription(answer)
                this.sendSignal({ type: "answer", target_user_uuid: payload.user_uuid, data: answer })
                break
            }
            case "answer": {
                await pc.setRemoteDescription(new RTCSessionDescription(payload.data))
                break
            }
            case "ice-candidate": {
                try {
                    await pc.addIceCandidate(new RTCIceCandidate(payload.data))
                } catch (e) {
                    // Late/duplicate candidates happen under normal ICE gathering and
                    // are safe to ignore.
                }
                break
            }
        }

        if (this.hasStatusLabelTarget) this.statusLabelTarget.textContent = this.i18nValue.connected
    }

    sendSignal(message) {
        this.callSubscription?.perform("signal", message)
    }

    // --- controls --------------------------------------------------------------

    toggleAudio() {
        if (!this.localStream) return

        this.audioActive = !this.audioActive
        this.localStream.getAudioTracks().forEach((track) => { track.enabled = this.audioActive })
        this.renderMediaButtons()
        this.persistMediaState()
    }

    toggleVideo() {
        if (!this.localStream) return

        this.videoActive = !this.videoActive
        this.localStream.getVideoTracks().forEach((track) => { track.enabled = this.videoActive })
        this.renderMediaButtons()
        this.persistMediaState()
    }

    // Screen sharing replaces the outgoing video track's content only
    // (RTCRtpSender.replaceTrack) - no renegotiation, no second video track.
    // The same replacement is applied on every peer connection in the mesh at
    // once, so all other participants see the share simultaneously.
    async toggleScreen() {
        if (!this.callUuid) return

        if (this.screenActive) {
            this.stopScreenShare()
            return
        }

        let stream
        try {
            stream = await navigator.mediaDevices.getDisplayMedia({ video: true })
        } catch (e) {
            return
        }

        const screenTrack = stream.getVideoTracks()[0]
        if (!screenTrack) return

        await this._replaceOutgoingVideoTrack(screenTrack)

        this.screenStream = stream
        this.screenActive = true
        if (this.hasLocalVideoTarget) this.localVideoTarget.srcObject = stream

        // The browser's own "stop sharing" control ends the track without going
        // through our button - this listener keeps our state in sync with that.
        screenTrack.addEventListener("ended", () => this.stopScreenShare())

        this.renderMediaButtons()
        this.persistMediaState()
    }

    async stopScreenShare() {
        if (!this.screenActive) return

        this.screenStream?.getTracks().forEach((track) => track.stop())
        this.screenStream = null
        this.screenActive = false

        const cameraTrack = this.localStream?.getVideoTracks()[0]
        if (cameraTrack) await this._replaceOutgoingVideoTrack(cameraTrack)

        if (this.hasLocalVideoTarget) this.localVideoTarget.srcObject = this.localStream
        this.renderMediaButtons()
        this.persistMediaState()
    }

    async _replaceOutgoingVideoTrack(track) {
        await Promise.all(Array.from(this.peers.values()).map((peer) => {
            const sender = peer.pc.getSenders().find((s) => s.track && s.track.kind === "video")
            return sender?.replaceTrack(track)
        }))
    }

    async hangup() {
        if (!this.callUuid) return

        const chatUuid = this.chatUuid
        const callUuid = this.callUuid
        this.teardownCall()

        await apiPost(ENDPOINTS.hangupCall, { chat_uuid: chatUuid, call_uuid: callUuid })
    }

    persistMediaState() {
        if (!this.callUuid) return

        apiPost(ENDPOINTS.callMediaState, {
            chat_uuid: this.chatUuid,
            call_uuid: this.callUuid,
            audio_active: this.audioActive,
            video_active: this.videoActive,
            screen_active: this.screenActive
        })
    }

    renderMediaButtons() {
        this.setButtonState(this.audioButtonTarget, this.hasAudioButtonTarget, this.audioActive,
            this.i18nValue.mute, this.i18nValue.unmute)
        this.setButtonState(this.videoButtonTarget, this.hasVideoButtonTarget, this.videoActive,
            this.i18nValue.camera_off, this.i18nValue.camera_on)
        this.setButtonState(this.screenButtonTarget, this.hasScreenButtonTarget, this.screenActive,
            this.i18nValue.stop_share, this.i18nValue.share_screen)
    }

    setButtonState(target, hasTarget, active, activeTitle, inactiveTitle) {
        if (!hasTarget) return

        target.classList.toggle("btn-active", active)
        target.title = active ? activeTitle : inactiveTitle
    }

    // --- lifecycle from the chat stream ----------------------------------------

    // call.started/accepted/declined/left/ended/missed - broadcast on the chat
    // stream (see PlConnect::ChatBroadcaster#call_state), forwarded here by
    // pl_connect_chat_controller.js for whichever conversation is open.
    handleCallEvent(event) {
        const payload = event.detail
        if (!payload || !payload.call_uuid) return

        if (this.incomingInvite && this.incomingInvite.call_uuid === payload.call_uuid &&
            ["call.declined", "call.ended", "call.missed", "call.left"].includes(payload.event)) {
            this.dismissIncoming()
        }

        if (payload.call_uuid !== this.callUuid) return

        switch (payload.event) {
            case "call.accepted":
                if (this.hasStatusLabelTarget) this.statusLabelTarget.textContent = this.i18nValue.connected
                break
            case "call.declined":
                if (payload.user_uuid !== this.viewerUuidValue) {
                    this.toast(this.i18nValue.call_declined)
                    this.teardownCall()
                }
                break
            case "call.missed":
            case "call.ended":
                this.teardownCall()
                break
            default:
                break
        }
    }

    // --- teardown ---------------------------------------------------------------

    teardownCall() {
        this.callSubscription?.unsubscribe()
        this.callSubscription = null

        this.peers.forEach((peer) => peer.pc.close())
        this.peers.clear()

        this.localStream?.getTracks().forEach((track) => track.stop())
        this.localStream = null

        this.screenStream?.getTracks().forEach((track) => track.stop())
        this.screenStream = null

        if (this.hasLocalVideoTarget) this.localVideoTarget.srcObject = null
        if (this.hasRemoteVideosTarget) this.remoteVideosTarget.replaceChildren()
        if (this.hasActivePanelTarget) toggle(this.activePanelTarget, false)

        this.resetState()
    }

    resetState() {
        this.callUuid = null
        this.chatUuid = null
        this.audioActive = true
        this.videoActive = false
        this.screenActive = false
    }

    // Minimal, dependency free notification. The workspace has no toast system
    // of its own yet - this keeps a failure visible without adding one.
    toast(message) {
        if (message) window.alert(message)
    }
}
