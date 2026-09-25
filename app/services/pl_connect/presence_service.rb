# frozen_string_literal: true

module PlConnect
  # PresenceService
  #
  # Tracks who is currently online, and since when they were last seen.
  #
  # == Why cache only, no database column
  # Presence is a continuous, high frequency signal: every connected client
  # refreshes it every few seconds. Persisting it would mean a write per user
  # per heartbeat and would turn a UI nicety into a permanent record of when
  # each employee sat at their desk — a behavioural profile that needs its own
  # legal basis under GDPR Art. 6 and is not covered by "operating a chat".
  #
  # Storing it in the cache with a short TTL gives data minimisation and
  # storage limitation (Art. 5 (1) c and e) for free: the entry disappears by
  # itself shortly after the user goes offline and nothing is ever written to
  # a durable store. Presence therefore cannot be reconstructed after the fact.
  #
  # == Why keys are read, never enumerated
  # ActiveSupport::Cache has no portable way to list keys, and solid_cache is
  # no exception. Presence is therefore always queried for a *known* set of
  # user uuids (the members of a conversation) via read_multi, which is a
  # single round trip and keeps the lookup O(members) instead of O(all users).
  class PresenceService
    KEY_PREFIX = "pl_connect:presence:"
    LAST_SEEN_KEY_PREFIX = "pl_connect:presence:last_seen:"

    # How long a heartbeat keeps a user marked as online. Must be noticeably
    # longer than the client heartbeat interval so a single dropped request
    # does not make a user flicker offline.
    DEFAULT_TTL_SECONDS = 75

    # How long a user still counts as "recently seen" (rendered as "away",
    # amber) after their last heartbeat, once the short online entry above has
    # already expired - e.g. a crashed tab or a lost network connection, as
    # opposed to an explicit logout/unsubscribe (#clear), which drops both
    # entries immediately and shows "offline" right away. Same GDPR reasoning
    # as DEFAULT_TTL_SECONDS above applies: still cache-only, still expires by
    # itself, just a longer grace period.
    LAST_SEEN_TTL_SECONDS = 30 * 60

    # Presence states a client may self-report. "dnd" (do not disturb) is a
    # manual override a user picks for themselves (see the presence Stimulus
    # controller); "offline" is not in the list - going offline is expressed by
    # removing the entry, not by storing a state.
    STATES = %w[online away busy dnd].freeze

    class << self
      # Records a heartbeat. Called from the presence channel on subscribe and
      # from the client's periodic ping.
      def touch(user:, state: "online")
        return if user.blank?

        safe_state = STATES.include?(state.to_s) ? state.to_s : "online"

        Rails.cache.write(
          _key(user.uuid),
          { state: safe_state, at: Time.current.to_i },
          expires_in: ttl_seconds
        )
        Rails.cache.write(_last_seen_key(user.uuid), true, expires_in: LAST_SEEN_TTL_SECONDS)
      rescue StandardError => e
        Rails.logger.error "PlConnect::PresenceService.touch: #{e.class}: #{e.message}"
      end

      # Explicitly drops the entry, e.g. on logout or channel unsubscribe. Also
      # drops the longer-lived "recently seen" entry, so an explicit logout
      # shows "offline" right away instead of lingering as "away" for up to
      # LAST_SEEN_TTL_SECONDS - see that constant's comment above.
      def clear(user:)
        return if user.blank?

        Rails.cache.delete(_key(user.uuid))
        Rails.cache.delete(_last_seen_key(user.uuid))
      rescue StandardError => e
        Rails.logger.error "PlConnect::PresenceService.clear: #{e.class}: #{e.message}"
      end

      # @return [Hash{String => String}] user uuid => state, for the uuids that
      #   are currently present. Absent uuids simply do not appear.
      def states_for(user_uuids)
        uuids = Array(user_uuids).map(&:to_s).reject(&:blank?).uniq
        return {} if uuids.empty?

        raw = Rails.cache.read_multi(*uuids.map { |uuid| _key(uuid) })

        raw.each_with_object({}) do |(key, value), result|
          uuid = key.to_s.delete_prefix(KEY_PREFIX)
          result[uuid] = value.is_a?(Hash) ? value[:state].to_s : "online"
        end
      rescue StandardError => e
        Rails.logger.error "PlConnect::PresenceService.states_for: #{e.class}: #{e.message}"
        {}
      end

      def online?(user_uuid)
        states_for([ user_uuid ]).key?(user_uuid.to_s)
      end

      # @return [Hash{String => String}] user uuid => one of "online", "busy",
      #   "away", "offline" - always one entry per requested uuid, unlike
      #   #states_for. This is the 4-colour indicator used everywhere presence
      #   is actually rendered (green/red/amber/grey):
      #     * "busy" (red)    - derived LIVE from the database: is this user an
      #       active participant of a currently running call? Deliberately not
      #       taken from the client's self-reported heartbeat state, so it
      #       cannot go stale if a tab crashes mid-call (a self-reported "busy"
      #       that never gets cleared would otherwise show red forever).
      #     * "online" (green) or a manual "dnd"/"away" override - whatever the
      #       client's own heartbeat last reported (see #states_for), when
      #       still live.
      #     * "away" (amber)  - no live heartbeat, but seen within the last
      #       LAST_SEEN_TTL_SECONDS (e.g. a crashed tab or a dropped network
      #       connection) - "was here a while ago, might still be around".
      #     * "offline" (grey) - neither: not logged in, logged out cleanly, or
      #       simply not seen for a long time.
      def display_states_for(user_uuids)
        uuids = Array(user_uuids).map(&:to_s).reject(&:blank?).uniq
        return {} if uuids.empty?

        live = states_for(uuids)
        busy = _busy_call_uuids(uuids)
        recent = _recently_seen_uuids(uuids)

        uuids.each_with_object({}) do |uuid, result|
          result[uuid] =
            if busy.include?(uuid)
              "busy"
            elsif live.key?(uuid)
              live[uuid] == "dnd" ? "busy" : live[uuid]
            elsif recent.include?(uuid)
              "away"
            else
              "offline"
            end
        end
      end

      # Configurable through the LookupItem presence_ttl_seconds; falls back to
      # the constant when the plugin configuration has not been seeded yet.
      def ttl_seconds
        configured = PLUGIN&.dig(:pl_connect_chat_item, :presence_ttl_seconds).to_i
        configured.positive? ? configured : DEFAULT_TTL_SECONDS
      end

      # Master switch, so an installation that does not want presence at all
      # can turn it off without removing the UI.
      def active?
        value = PLUGIN&.dig(:pl_connect_chat_item, :presence_active)
        return true if value.nil?

        ActiveModel::Type::Boolean.new.cast(value) ? true : false
      end

      private

      def _key(uuid)
        "#{KEY_PREFIX}#{uuid}"
      end

      def _last_seen_key(uuid)
        "#{LAST_SEEN_KEY_PREFIX}#{uuid}"
      end

      # Uuids of users who are currently an active (non-left) participant of a
      # still running call - see #display_states_for.
      def _busy_call_uuids(user_uuids)
        PlConnectCallItemJoinUser
          .joins(:pl_connect_call_item)
          .where(user_uuid: user_uuids, left_at: nil, del_flag: false)
          .merge(PlConnectCallItem.where(state: %w[ringing active], del_flag: false))
          .distinct
          .pluck(:user_uuid)
      rescue StandardError => e
        Rails.logger.error "PlConnect::PresenceService._busy_call_uuids: #{e.class}: #{e.message}"
        []
      end

      def _recently_seen_uuids(user_uuids)
        raw = Rails.cache.read_multi(*user_uuids.map { |uuid| _last_seen_key(uuid) })
        raw.keys.map { |key| key.to_s.delete_prefix(LAST_SEEN_KEY_PREFIX) }
      rescue StandardError => e
        Rails.logger.error "PlConnect::PresenceService._recently_seen_uuids: #{e.class}: #{e.message}"
        []
      end
    end
  end
end
