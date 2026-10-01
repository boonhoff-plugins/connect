source 'https://rubygems.org'

# Server-side SDK for LiveKit (self-hosted SFU media server) - mints short-lived
# per-user access tokens and manages rooms for conference calls once they
# outgrow the plain WebRTC mesh. Activated via lookup_item:
# plugin_configuration.pl_connect_connect.sfu_active = true (see
# PlConnect::CallService.sfu_configured?/PlConnect::SfuService). Zero overhead
# when inactive - no network calls are made, direct 1:1 calls never use it.
# Declared here (not system/Gemfile) so installing this plugin on another
# system via its own Gemfile (auto eval_gemfile'd, see system/Gemfile) brings
# the dependency with it.
# https://github.com/livekit/server-sdk-ruby
gem "livekit-server-sdk", require: "livekit"
