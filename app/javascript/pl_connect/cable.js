// pl_connect/cable.js
//
// ActionCable consumer for the Connect plugin.
//
// The core application already creates a consumer in
// system/app/javascript/channels/consumer.js, but importing it from here would
// hard-code the relative path from the plugin back into the Rails application
// (../../../../../../system/app/javascript/...). That path only holds for the
// default repository layout and breaks as soon as BOONHOFF_PLUGIN_ROOT points
// somewhere else, so the plugin creates and caches its own consumer instead.
//
// The cost is one additional WebSocket connection per browser tab; the benefit
// is that the plugin stays self-contained and can be moved or extracted without
// touching the core.
import { createConsumer } from "@rails/actioncable"

let consumer = null

export default function plConnectConsumer() {
  if (consumer === null) consumer = createConsumer()
  return consumer
}
