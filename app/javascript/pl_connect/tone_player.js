// pl_connect/tone_player.js
//
// Ringtone/ringback tones synthesised with the Web Audio API instead of
// shipping audio asset files - two oscillators cycled on/off, the classic
// telephony "dual tone" cadence. Nothing here touches the microphone or the
// network: it is pure local audio output, so it needs no permission and no
// asset licensing.
class TonePlayer {
    constructor({ frequencies, onMs, offMs, gain = 0.12 }) {
        this.frequencies = frequencies
        this.onMs = onMs
        this.offMs = offMs
        this.gain = gain
        this.context = null
        this.timer = null
    }

    start() {
        if (this.timer || this.context) return

        const AudioContextClass = window.AudioContext || window.webkitAudioContext
        if (!AudioContextClass) return // browser without Web Audio support: fail silent, never breaks the call itself

        this.context = new AudioContextClass()
        this._cycle()
    }

    stop() {
        if (this.timer) clearTimeout(this.timer)
        this.timer = null

        if (this.context) this.context.close().catch(() => { })
        this.context = null
    }

    _cycle() {
        this._beep()
        this.timer = setTimeout(() => this._cycle(), this.onMs + this.offMs)
    }

    _beep() {
        if (!this.context) return

        const gainNode = this.context.createGain()
        gainNode.gain.value = this.gain
        gainNode.connect(this.context.destination)

        const stopAt = this.context.currentTime + this.onMs / 1000

        this.frequencies.forEach((frequency) => {
            const oscillator = this.context.createOscillator()
            oscillator.frequency.value = frequency
            oscillator.connect(gainNode)
            oscillator.start()
            oscillator.stop(stopAt)
        })
    }
}

// Caller-side feedback while an outgoing direct call is ringing.
export function createRingbackPlayer() {
    return new TonePlayer({ frequencies: [440, 480], onMs: 2000, offMs: 4000 })
}

// Callee-side alert while a direct call invite is showing.
export function createRingtonePlayer() {
    return new TonePlayer({ frequencies: [440, 480], onMs: 1000, offMs: 1000 })
}

// One-shot "record now" beep played after the voicemail greeting (see
// pl_connect_call_controller.js#playVoicemailGreeting) - the classic single
// tone, not the on/off cadence of the ringtone/ringback above. Resolves once
// the tone has finished playing so the caller only starts awaiting after it.
export function playBeep({ frequency = 1000, durationMs = 400, gain = 0.2 } = {}) {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext
    if (!AudioContextClass) return Promise.resolve() // no Web Audio support: skip straight to recording

    const context = new AudioContextClass()

    return new Promise((resolve) => {
        const gainNode = context.createGain()
        gainNode.gain.value = gain
        gainNode.connect(context.destination)

        const oscillator = context.createOscillator()
        oscillator.frequency.value = frequency
        oscillator.connect(gainNode)
        oscillator.onended = () => {
            context.close().catch(() => { })
            resolve()
        }
        oscillator.start()
        oscillator.stop(context.currentTime + durationMs / 1000)
    })
}
