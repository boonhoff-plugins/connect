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

    # How long a heartbeat keeps a user marked as online. Must be noticeably
    # longer than the client heartbeat interval so a single dropped request
    # does not make a user flicker offline.
    DEFAULT_TTL_SECONDS = 75

    # Presence states a client may report. "offline" is not in the list — going
    # offline is expressed by removing the entry, not by storing a state.
    STATES = %w[online away busy].freeze

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
      rescue StandardError => e
        Rails.logger.error "PlConnect::PresenceService.touch: #{e.class}: #{e.message}"
      end

      # Explicitly drops the entry, e.g. on logout or channel unsubscribe.
      def clear(user:)
        return if user.blank?

        Rails.cache.delete(_key(user.uuid))
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
    end
  end
end
