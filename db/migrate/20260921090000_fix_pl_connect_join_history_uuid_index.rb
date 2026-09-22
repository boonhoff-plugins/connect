# frozen_string_literal: true

# FixPlConnectJoinHistoryUuidIndex
#
# Bug: 20260919083000_create_pl_connect_remaining_join_tables.rb's
# _create_join_history_table added `add_index join_history_table, :uuid,
# unique: true` for all 4 join-history tables it creates. That is wrong for a
# HISTORY table: SaveHistoryModelConcern#create_history_instance copies the
# original record's own (unchanged) `uuid` into every new history row, so a
# unique index on `uuid` alone allows only the FIRST history snapshot of any
# given record - the second save (e.g. accepting/hanging up a call, which
# updates the same PlConnectCallItemJoinUser row again) raises
# ActiveRecord::RecordNotUnique, which CallService/ChatItem's generic
# `rescue StandardError` turns into "The call could not be processed."
#
# Every other history table in this codebase (core-generated ones, e.g.
# calendar_item_join_group_histories) either has NO index on `uuid` at all, or
# (for models with a `version` column) a composite `["uuid", "version"]`
# index - never a plain unique index on `uuid` by itself. This migration
# removes the erroneous unique index from all 4 affected tables to match that
# convention; `original_id` (already indexed, non-unique) remains the correct
# way to look up a record's history rows.
#
# Affected tables (all created by 20260919083000):
#   * pl_connect_call_item_join_user_histories
#   * pl_connect_chat_item_join_group_histories
#   * pl_connect_chat_item_join_role_histories
#   * pl_connect_chat_item_join_tenant_histories
class FixPlConnectJoinHistoryUuidIndex < ActiveRecord::Migration[8.1]
  TABLES = %w[
    pl_connect_call_item_join_user_histories
    pl_connect_chat_item_join_group_histories
    pl_connect_chat_item_join_role_histories
    pl_connect_chat_item_join_tenant_histories
  ].freeze

  def up
    TABLES.each do |table|
      next unless data_source_exists?(table)

      if index_exists?(table, :uuid)
        remove_index table, :uuid
        puts "  [OK] Removed unique uuid index on #{table}"
      else
        puts "  [SKIP] #{table}: no uuid index found"
      end
    end
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end

  # Restores the original (buggy) unique index, matching the exact index name
  # the create-table migration used, so `db:migrate:redo` round-trips cleanly.
  def down
    TABLES.each do |table|
      next unless data_source_exists?(table)
      next if index_exists?(table, :uuid)

      add_index table, :uuid, unique: true
      puts "  [OK] Restored unique uuid index on #{table}"
    end
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}#down: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end
end
