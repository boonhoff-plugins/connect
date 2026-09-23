# frozen_string_literal: true

# Mixes the Connect plugin's meeting behavior into the CORE CalendarItem
# model, without ever reopening or editing system/app/models/calendar_item.rb
# directly.
#
# `to_prepare` is the correct hook here (not a plain top-level `include` in
# this file): it runs once on boot AND again after every class reload in
# development, so CalendarItem keeps the module included even after Zeitwerk
# unloads and reloads it. A plain top-level include would only run once, at
# boot, and silently disappear after the first autoreload in development.
Rails.application.config.to_prepare do
  CalendarItem.include(PlConnect::CalendarItemMeetingConcern) if defined?(CalendarItem)
end
