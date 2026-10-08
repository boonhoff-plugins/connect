# frozen_string_literal: true

# AddPlConnectPluginDocumentation
#
# English plugin documentation for Connect, added under DocumentationItem 1073
# ("Plugin", the generic home for per-plugin documentation under the "User
# Documentation" area) - a main overview item for the whole plugin plus one
# end-user guide and one administrator guide underneath it, per
# CLAUDE.md's "Plugin documentation" section.
#
# NOTE: per claude.md's "Dokumentation synchron halten" convention, this
# migration file is corrected IN PLACE (not superseded by a new migration)
# whenever the documented feature changes, so a fresh install always gets the
# current text. Already-migrated installations need the content re-applied:
# `bin/rails db:migrate:redo VERSION=20261001150000`.
#
# == Fixed uuids
# All three documentation_item uuids below are hardcoded literals, NOT
# generated at migration run time (no SecureRandom.uuid call here) - every
# installation that runs this migration ends up with the exact same uuids,
# which is what makes a later update migration able to find and update these
# exact records by uuid instead of guessing by name/parent.
class AddPlConnectPluginDocumentation < ActiveRecord::Migration[8.1]
  PARENT_ID = 1073 # "Plugin", under the "User Documentation" area (id 3)
  EXTENSION_FOLDER = "../extensions/plugins/connect/"

  MAIN_UUID = "3f9008a5-bac1-4872-b1ee-733253dd0169--documentation_item--20261001150000"
  USER_GUIDE_UUID = "49f8d7c3-0bb9-4e21-a650-578831bbec5d--documentation_item--20261001150000"
  ADMIN_GUIDE_UUID = "9fa6a64b-3006-4ac4-bc52-9223bf2d3522--documentation_item--20261001150000"

  def up
    @tenant = Tenant.find_by(code: "default") || Tenant.first
    return puts "  [SKIP] No tenant found." unless @tenant

    parent = DocumentationItem.find_by(id: PARENT_ID)
    return puts "  [SKIP] DocumentationItem #{PARENT_ID} (Plugin) not found." unless parent

    extension_item = ExtensionItem.find_by(extension_folder: EXTENSION_FOLDER, parent_id: nil, del_flag: false, active: true)

    @c = ControllerHelper.init_tenant(:default, {}, false, false)
    @c[:current_tenant] = @tenant

    main = _upsert(uuid: MAIN_UUID, parent: parent, extension_item: extension_item, name: "pl_plugin_connect",
                   title: "Connect", decimal_position: 10.0, content: _main_content)
    return unless main

    _upsert(uuid: USER_GUIDE_UUID, parent: main, extension_item: extension_item, name: "pl_plugin_connect_user_guide",
            title: "Connect &ndash; User Guide", decimal_position: 10.0, content: _user_guide_content)

    _upsert(uuid: ADMIN_GUIDE_UUID, parent: main, extension_item: extension_item, name: "pl_plugin_connect_admin_guide",
            title: "Connect &ndash; Administrator Guide", decimal_position: 20.0, content: _admin_guide_content)

    YamlHelper.update_yaml(c: @c, reference_model: DocumentationItem, reference_id: main.id,
      auto_translate: SYSTEM&.dig(:language, :auto_translate_in_another_yml_files))
    sleep 3 # YamlHelper.update_yaml writes in a background Thread - see /memories/repo/yaml-helper-async-thread.md

    puts "  [OK] Connect plugin documentation created/updated under DocumentationItem #{PARENT_ID}."
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
    [ ADMIN_GUIDE_UUID, USER_GUIDE_UUID, MAIN_UUID ].each do |uuid|
      item = DocumentationItem.find_by(uuid: uuid)
      item&.destroy
    end
    puts "  [OK] Connect plugin documentation removed."
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}#down: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  private

  def _upsert(uuid:, parent:, extension_item:, name:, title:, decimal_position:, content:)
    item = DocumentationItem.find_or_initialize_by(uuid: uuid)
    result = item.save_element(c: @c, check_uuid: false, element: {
                                 uuid: uuid,
                                 parent_id: parent.id, parent_uuid: parent.uuid,
                                 tenant_id: @tenant.id, tenant_uuid: @tenant.uuid,
                                 extension_item_id: extension_item&.id, extension_item_uuid: extension_item&.uuid,
                                 name: name, title: title, f_type: "page", language: "en",
                                 visibility: "external",
                                 decimal_position: decimal_position,
                                 content: content
                               })

    unless result[:successful]
      puts "  [ERROR] #{name}: #{result[:successful_text]}"
      return nil
    end

    result[:element]
  end

  def _main_content
    <<~'HTML'
      <h1>Connect</h1>

      <p>
        Connect is a real-time messaging and calling plugin: direct (1:1), group, channel
        and team conversations, audio/video calls with optional screen sharing, voicemail for
        unanswered calls, and a presence/status indicator that shows whether a colleague is
        available, away, on a call, or has asked not to be disturbed.
      </p>

      <ul>
        <li><a href="/documentation_item/show_element/pl_plugin_connect_user_guide">User Guide</a>
          &ndash; chatting, calling, presence/status, voicemail, as experienced by any user.</li>
        <li><a href="/documentation_item/show_element/pl_plugin_connect_admin_guide">Administrator Guide</a>
          &ndash; master switches, participant limits, the optional SFU media server for large
          conferences, and the replaceable voicemail greeting.</li>
      </ul>

      <h2>Data protection (GDPR)</h2>
      <p>
        Only metadata is ever persisted on the server (conversation membership, message text,
        call timestamps/duration/state, mute flags). Call audio/video/screen content is never
        stored - it is relayed either directly between participants' browsers (WebRTC mesh,
        small calls) or through the optional self-hosted SFU media server (large conferences),
        neither of which record anything. Presence (online/away) lives in a short-lived cache
        only and self-expires; a manually chosen status (Away/Do Not Disturb/Offline) is the
        one explicit, durable preference stored for a user, exactly like any other personal
        setting.
      </p>
    HTML
  end

  def _user_guide_content
    <<~'HTML'
      <h1>Connect &ndash; User Guide</h1>

      <h2>Conversations</h2>
      <p>
        Start a direct conversation with a colleague, or a group/channel/team conversation with
        several people, from the "+" button above the conversation list. The search field at the
        top of the workspace finds both people and past messages across your own conversations.
      </p>

      <h2>Presence &amp; status</h2>
      <p>
        A small colored dot next to a person's name shows whether they are currently reachable -
        in the conversation list, at the top of an open conversation, and in search results:
      </p>
      <ul>
        <li><strong>Green</strong> &ndash; online right now.</li>
        <li><strong>Amber</strong> &ndash; away (their tab is in the background, or they were
          active recently but are not connected right now).</li>
        <li><strong>Red</strong> &ndash; busy: either actually on a call right now, or they have
          manually set "Do not disturb" (see below).</li>
        <li><strong>Grey</strong> &ndash; offline: not logged in, logged out, or they have
          manually chosen to appear offline.</li>
      </ul>
      <p>
        Click your own name/avatar in the top right to set your own status: <strong>Online</strong>
        (automatic - follows whether your browser tab is active), <strong>Away</strong>,
        <strong>Do not disturb</strong>, or <strong>Offline</strong>. A manually chosen status is
        saved for you specifically - it survives a page reload and is visible to every colleague
        wherever your presence is shown, until you pick "Online" again. Other users' dots refresh
        automatically every so often, so a colleague's status change reaches your screen without
        needing to reload.
      </p>

      <h2>Calls</h2>
      <p>
        Open a conversation and use the phone or camera icon in its header to start an audio or
        video call. In a direct conversation this rings the other person; in a group/channel/team
        conversation the call starts immediately and other members can join in at any time while
        it is running. During a call you can mute your microphone, turn your camera on/off, and
        share your screen.
      </p>
      <p>
        You can ring a specific colleague into an already-running call via the "invite" button -
        search widens from the conversation's own members to anyone in your organisation, and
        inviting someone not yet part of the conversation adds them to it automatically (not
        possible for a direct 1:1 call, which only ever has the original two participants).
      </p>
      <p>
        Group calls normally connect every participant directly to every other one; once a
        conversation grows past what that can comfortably handle, an administrator can enable a
        media-server mode that scales much further (see the Administrator Guide) - this is
        transparent to you, the controls stay the same either way.
      </p>

      <h2>Do Not Disturb &amp; missed calls</h2>
      <p>
        If you set your own status to "Do not disturb", a direct call to you is never actually
        rung - the caller is redirected straight to your voicemail greeting instead, exactly as
        if you had not answered. Either way, you will always find a "Missed call" note in the
        conversation afterwards, whether or not the caller actually left a recorded message.
      </p>

      <h2>Voicemail</h2>
      <p>
        When a direct call goes unanswered (or the callee has Do Not Disturb enabled), the caller
        hears a short spoken announcement followed by a tone, and can then leave a message -
        recording stops automatically after a configured maximum length, or as soon as they hang
        up. The recording appears in the conversation as a normal chat message with an audio
        player, exactly like any other voice attachment.
      </p>
    HTML
  end

  def _admin_guide_content
    <<~'HTML'
      <h1>Connect &ndash; Administrator Guide</h1>

      <p>
        Every setting below lives under the <strong>Lookup Item configuration</strong> group
        <code>pl_connect_connect</code> (lookup_item 3699) and takes effect immediately once
        saved - no restart required.
      </p>

      <h2>Master switches</h2>
      <ul>
        <li><code>webrtc_calls_active</code> (pl_connect_chat_item group) &ndash; turns audio/video
          calling on or off for the whole installation.</li>
        <li><code>presence_active</code> (pl_connect_chat_item group) &ndash; turns the online/away/
          busy/offline indicator on or off.</li>
        <li><code>voicemail_active</code> &ndash; turns the unanswered-call voicemail prompt on or
          off; also governs the immediate Do-Not-Disturb-triggered voicemail.</li>
        <li><code>ringtone_active</code> / <code>ringback_active</code> &ndash; the audible tones
          played to the callee/caller while a direct call is ringing (synthesised in the browser,
          no audio file involved).</li>
      </ul>

      <h2>Required: reverse proxy must forward WebSocket traffic (ActionCable)</h2>
      <p>
        Presence/status, chat message delivery and call signalling (invites, accept/decline, mute
        state) all travel over the Rails app's ActionCable WebSocket endpoint at
        <code>/cable</code> - the same host/port as the rest of the application, not a separate
        server. A reverse proxy placed in front of Rails (nginx, Apache, a managed load balancer,
        ...) forwards plain HTTP requests correctly by default, but does <strong>not</strong>
        forward WebSocket upgrade requests unless explicitly configured to - every one of the
        symptoms below has the exact same root cause.
      </p>

      <h3>Symptoms of a missing/incorrect WebSocket proxy</h3>
      <ul>
        <li>The presence/status indicator never changes, for anyone.</li>
        <li>Calls cannot be started, or an incoming call never shows up for the other side.</li>
        <li>Every outgoing direct call rings for exactly <code>voicemail_timeout_seconds</code>
          (30 by default) and then falls back to voicemail - because the invite never reached the
          callee in the first place, so the call simply times out every single time rather than
          being declined or missed.</li>
        <li>The browser's developer console shows the page trying to open
          <code>wss://yourdomain.example/cable</code> and failing (e.g. Firefox's
          <code>NS_ERROR_WEBSOCKET_CONNECTION_REFUSED</code>, Chrome's
          <code>WebSocket connection to '...' failed</code>).</li>
      </ul>

      <h3>How to verify which side is broken</h3>
      <p>
        From the server itself, bypassing the proxy entirely, send a real WebSocket handshake
        directly to the Rails app (a plain <code>curl</code> GET without upgrade headers always
        returns 404 here and proves nothing either way):
      </p>
      <pre><code>curl -i -N \
  -H "Connection: Upgrade" -H "Upgrade: websocket" \
  -H "Sec-WebSocket-Version: 13" -H "Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==" \
  http://127.0.0.1:3000/cable</code></pre>
      <p>
        <code>HTTP/1.1 101 Switching Protocols</code> means Rails/Puma itself is fine and the
        reverse proxy in front of it is the problem. Anything else (connection refused, a
        different error) means the issue is on the Rails/Puma side instead (process not running,
        wrong port, or the <code>solid_cable</code> adapter/database misconfigured - see
        <code>system/config/cable.yml</code>).
      </p>

      <h3>nginx</h3>
      <p>
        Once (in the <code>http {}</code> block of <code>nginx.conf</code>):
      </p>
      <pre><code>map $http_upgrade $connection_upgrade {
    default upgrade;
    ''      close;
}</code></pre>
      <p>
        In the same <code>server {}</code> block that already proxies the application
        (<code>sites-enabled/...</code>), <strong>before</strong> the general
        <code>location / { ... }</code>:
      </p>
      <pre><code>location /cable {
    proxy_pass http://127.0.0.1:3000;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection $connection_upgrade;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_read_timeout 3600s;
}</code></pre>
      <p>
        <code>proxy_read_timeout</code> matters: WebSocket connections are long-lived, and
        nginx's default 60-second read timeout would otherwise silently disconnect an idle one.
        Apply with <code>nginx -t &amp;&amp; systemctl reload nginx</code> (reload, not restart).
      </p>

      <h3>Apache (httpd)</h3>
      <p>
        Requires <code>mod_proxy_wstunnel</code> (<code>a2enmod proxy_wstunnel</code> on
        Debian/Ubuntu). Inside the existing <code>&lt;VirtualHost&gt;</code> that already proxies
        to the app:
      </p>
      <pre><code>ProxyPass /cable ws://127.0.0.1:3000/cable
ProxyPassReverse /cable ws://127.0.0.1:3000/cable</code></pre>

      <h3>Caddy</h3>
      <p>
        Caddy's <code>reverse_proxy</code> forwards WebSocket upgrades automatically - no special
        <code>/cable</code> block is needed as long as the existing directive already proxies the
        whole domain to the app:
      </p>
      <pre><code>yourdomain.example {
    reverse_proxy 127.0.0.1:3000
}</code></pre>

      <h3>Traefik</h3>
      <p>
        No special configuration either - Traefik detects and forwards the
        <code>Connection: Upgrade</code> handshake automatically for any router already pointing
        at the app's service/port.
      </p>

      <h2>Conference size: mesh vs. media server (SFU)</h2>
      <p>
        By default, group/channel/team calls connect every participant's browser directly to
        every other one (a "mesh"). This does not scale far - <code>webrtc_mesh_participant_limit</code>
        caps it (admin-configurable, but never above the technical ceiling of 8 participants built
        into the plugin).
      </p>
      <p>
        For larger conferences, Connect can instead relay the call through a self-hosted SFU
        media server (<a href="https://livekit.io/">LiveKit</a>), so every browser only ever holds
        one connection regardless of how many people are in the call. <strong>This is entirely
        optional and off by default</strong> - no SFU server is bundled or started automatically,
        and simply flipping the switch below does nothing harmful by itself: conferences keep
        using the mesh until a real, reachable server and valid credentials are configured.
      </p>

      <h3>Step-by-step: activating the SFU</h3>
      <ol>
        <li>
          <strong>Start a LiveKit server.</strong> A ready-to-edit starting point ships with the
          installation: <code>custom/docker-compose.livekit.yml</code> and
          <code>custom/livekit.yaml</code>. From the <code>custom/</code> directory:
          <pre><code>docker run --rm livekit/livekit-server generate-keys</code></pre>
          This prints an API key and an API secret - copy both, you need them in steps 2 and 4.
        </li>
        <li>
          <strong>Fill in the generated key/secret</strong> in <code>custom/livekit.yaml</code>,
          replacing the two placeholder values (<code>REPLACE_WITH_GENERATED_API_KEY</code> /
          <code>REPLACE_WITH_GENERATED_API_SECRET</code>) under its <code>keys:</code> section.
        </li>
        <li>
          <strong>Start the server</strong> from the <code>custom/</code> directory:
          <pre><code>docker compose -f docker-compose.livekit.yml up -d</code></pre>
          (or <code>docker-compose</code> for the older standalone binary). This exposes port
          <code>7880</code> (the client WebSocket), <code>7881</code> (TCP fallback) and a UDP
          range <code>50000-50100</code> (the actual WebRTC media) on the host.
        </li>
        <li>
          <strong>Confirm it is actually running</strong> before touching any configuration:
          <pre><code>docker compose -f docker-compose.livekit.yml logs -f</code></pre>
          should show LiveKit starting up with no errors, and <code>docker ps</code> should list
          the <code>boonhoff_livekit</code> container as <code>Up</code>.
        </li>
        <li>
          <strong>Now, and only now</strong>, go to the admin UI, open Lookup Item <strong>3699
          (<code>pl_connect_connect</code>)</strong> and set all four of the following - the SFU
          path is only used once every single one of them is filled in correctly:
          <ul>
            <li><code>sfu_active</code> &rarr; <code>true</code></li>
            <li><code>sfu_url</code> &rarr; the WebSocket URL the <em>browser</em> connects to,
              e.g. <code>ws://localhost:7880</code> for a local/development server, or
              <code>wss://livekit.yourdomain.example</code> for anything reachable over the
              public internet (see the TLS note below - <code>ws://</code> only ever works for
              <code>localhost</code>).</li>
            <li><code>sfu_api_key</code> &rarr; the API key from step 1.</li>
            <li><code>sfu_api_secret</code> &rarr; the API secret from step 1.</li>
          </ul>
        </li>
        <li>
          <strong>Verify end to end:</strong> start (or join) a group/channel/team call with at
          least one other participant and check the browser's developer console - a successful
          SFU connection logs a LiveKit <code>Room</code> connecting to the configured
          <code>sfu_url</code>, and the call keeps working well past the old mesh ceiling of 8
          participants (up to <code>sfu_max_participants</code>, capped at 100). If the console
          instead shows a WebSocket connection error, see Troubleshooting below - the call
          silently falls back to nothing rather than crashing, so a misconfiguration shows up as
          "the conference behaves like before", not as an error dialog.
        </li>
      </ol>

      <h3>TLS in production</h3>
      <p>
        Browsers only allow an insecure <code>ws://</code> WebSocket from a page that was itself
        loaded over plain <code>http://</code> on <code>localhost</code> - anywhere else
        (including a real domain reachable over the internet, even internally) requires
        <code>wss://</code> (TLS) or the browser will refuse to connect at all. In production, put
        the LiveKit server behind the same reverse proxy/TLS termination already used for the
        Rails app (or any proxy capable of forwarding WebSocket upgrades to port 7880), and use
        that public, TLS-terminated hostname as <code>sfu_url</code> (<code>wss://...</code>). The
        UDP media port range (<code>50000-50100</code> by default, widen it for a busier
        installation) must still be reachable directly on the LiveKit host - it is not proxied.
      </p>

      <h3>Configurable values</h3>
      <ul>
        <li><code>sfu_active</code> &ndash; master switch for this mode.</li>
        <li><code>sfu_url</code> &ndash; the LiveKit server's WebSocket URL the browser connects to.</li>
        <li><code>sfu_api_key</code> / <code>sfu_api_secret</code> &ndash; credentials used server
          side to mint short-lived, per-user access tokens (never sent to the browser as-is).</li>
        <li><code>sfu_max_participants</code> &ndash; ceiling for SFU-relayed conferences
          (configurable, capped at 100).</li>
      </ul>
      <p>
        Direct (1:1) calls always use the plain mesh regardless of this setting - two participants
        is exactly what a mesh is good at.
      </p>

      <h3>Troubleshooting</h3>
      <ul>
        <li><strong>Conferences still behave like the old mesh (stuck at 8 participants)</strong>
          &ndash; one of the four values above is still blank, or <code>sfu_active</code> is still
          <code>false</code>; all four are required together, there is no partial activation.</li>
        <li><strong>Browser console shows a WebSocket connection error/refusal</strong> &ndash;
          almost always either the LiveKit container is not actually running (check
          <code>docker ps</code>/the logs), the configured <code>sfu_url</code> does not match
          where it is actually reachable from the browser's network, or <code>ws://</code> was
          used for a non-<code>localhost</code> address (needs <code>wss://</code>, see the TLS
          note above).</li>
        <li><strong>Connects, but no audio/video from other participants</strong> &ndash; the UDP
          media port range is not reachable (firewall, NAT, or a cloud security group blocking
          it) - the signalling (WebSocket) connection can succeed independently of the media
          path, so this looks like a partial success rather than an outright failure.</li>
        <li><strong>Token/authentication errors</strong> &ndash; <code>sfu_api_key</code>/
          <code>sfu_api_secret</code> do not match the <code>keys:</code> entry actually loaded by
          the running LiveKit server (e.g. <code>livekit.yaml</code> was edited after the
          container was already started - restart it to pick up the change).</li>
      </ul>

      <h2>Voicemail greeting &amp; timing</h2>
      <ul>
        <li><code>voicemail_timeout_seconds</code> &ndash; how long an unanswered direct call rings
          before the caller is prompted for a voicemail.</li>
        <li><code>voicemail_max_duration_seconds</code> &ndash; maximum length of a single
          recording.</li>
        <li><code>voicemail_greeting_audio</code> &ndash; the spoken announcement played to the
          caller before the beep. Upload a different audio file here (any format a browser can
          play) to replace it, in any language - no deploy or restart needed.</li>
      </ul>

      <h2>Data protection (GDPR)</h2>
      <p>
        Presence (online/away) is cache-only with a short expiry by design, so it cannot be
        reconstructed into a movement profile after the fact. A user's own manually chosen status
        (Away/Do Not Disturb/Offline) is the one piece of presence-related data stored durably -
        it is an explicit user preference, not a behavioural signal, comparable to any other
        personal setting. Call media (audio/video/screen) is never recorded or stored server
        side, whether relayed via the mesh or the optional SFU - only call metadata (who, when,
        how long, mute state) is persisted, under the same legal basis as ordinary chat messages.
      </p>
    HTML
  end
end
