# AGENTS — plugin "connect"

Baseline for AI assistants (Claude, Codex, Gemini, Mistral, Copilot, ...)
working inside this extension folder.

Read first — repository root, two levels above this folder:

- `../../AGENTS.md`
- `../../AI_CORE.md`
- `../../CLAUDE.md`

When this folder is consumed outside the main repository (exported ZIP,
separate checkout), those root files may be absent. The binding rules are
therefore restated here in condensed form. If both exist and conflict, the
repository root files win.

## What this folder is

- Extension of type `plugin` of the Boonhoff Rails system.
- Main Rails app: `system/`, project customizations: `custom/`, extensions:
  `extensions/plugins` and `extensions/tenants`.
- Run Rails commands from `system/`.
- The extension's routes are registered in `config/routes.rb` via
  `create_resource_routes`.
- `.extension_metadata` declares the identity (name, type, target_path,
  version) and, optionally, the subscribed hook events.

## Extension mechanism (never break these)

- Never add plugin-specific behavior to core files (`system/app/**`,
  `system/config/routes.rb`).
- Extend a core model via a Concern under `app/models/concerns/`, mixed in
  through `config/initializers/*.rb` via `Rails.application.config.to_prepare`;
  never reopen the core model file itself.
- New endpoints: own controller under `app/controllers/` plus a route in this
  extension's `config/routes.rb`.
- JavaScript: own Stimulus controllers in `app/javascript/controllers/`
  (auto-bundled via `Boonhoff::ExtensionJavascriptManifest`); plugin UI on
  core pages via `app/views/extension_shell_widgets/` fragments
  (auto-rendered, see `Boonhoff::ExtensionShellWidgets`).
- i18n: own files in `config/locales/`, keep `en` and `de` in sync; never add
  extension strings to core locale files.
- DB fields for plugin features: tag the owning `TableItem`/`PageItem` with
  this extension's `extension_item_uuid` (its "Plugin: <Name>" ExtensionItem),
  never the "system" one.
- When replacing core-hardcoded logic with the plugin-owned equivalent:
  build and verify the plugin-owned replacement first, then remove the
  core version. Never remove core functionality before its replacement
  exists and works.

## Data and migrations

- Persist app records via `save_element`; no direct `.save`/`.update`.
- Migrations: idempotent, meaningful `down` method, safe tenant/context
  initialization in `up`, hardcoded UUID literals (never `SecureRandom.uuid`
  at migration run time).
- Keep DB code portable across MySQL, PostgreSQL and SQLite.

## Hooks

- Hook registrations live in `config/hooks/*.rb` (auto-loaded at boot and on
  development reload; every handler receives the kwargs hash of its
  predecessor and must return the complete kwargs hash).
- Declare subscribed events in the `hooks:` section of
  `.extension_metadata`. Unknown events only warn; sensitive events
  (`security.*`, `gdpr.export.redact`) must always be declared, otherwise
  the subscription is refused at load time.
- `config/hooks/example_hooks.rb` is a safe no-op demonstration and may be
  replaced or deleted.

## Documentation

- Plugin documentation: own `DocumentationItem` tree under id 1073
  (`name: pl_plugin_<plugin>`, English, `visibility: "external"`), created
  by a migration inside this extension's `db/migrate/`. Edit the same
  migration in place and re-apply it instead of adding a new one.
- Documentation content is semantic HTML with relative links only.

## Security, GDPR and conventions

- GDPR compliance is mandatory; never log or expose personal data in
  plaintext.
- Documentation language follows the documentation hierarchy, not a blind
  default.
- Boolean lookup values use `*_active`; code comments are in English.
