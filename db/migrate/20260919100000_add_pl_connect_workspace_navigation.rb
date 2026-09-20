# frozen_string_literal: true

# AddPlConnectWorkspaceNavigation
#
# Makes the Connect workspace reachable and governable:
#
#   1. Renames the legacy plugin role so it matches what the framework actually
#      checks. PermissionControllerConcern#user_has_permission? looks for the
#      role names "plugin_<controller_name>", "tenant_<controller_name>" and
#      "<controller_name>". The role generated during scaffolding was called
#      "plugin/pl_connect_connect" (with a slash) and for a controller that no
#      longer exists, so it could never grant access to anything. Renaming it to
#      "plugin_pl_connect_workspace" turns it into the real gate for the
#      workspace - and keeps the existing link_item_join_roles row intact, which
#      a delete-and-recreate would have thrown away.
#
#   2. Adds the navigation entry for the workspace below the existing "Connect"
#      navigation group.
#
#   3. Restricts that entry to the same role, so navigation visibility and
#      controller permission are decided by one single role instead of drifting
#      apart.
class AddPlConnectWorkspaceNavigation < ActiveRecord::Migration[8.1]
  # Old and new name of the plugin role.
  LEGACY_ROLE_NAME = "plugin/pl_connect_connect"
  ROLE_NAME = "plugin_pl_connect_workspace"

  # Navigation group created during scaffolding ("Connect"), used as the parent
  # of the new entry. Looked up by name rather than by id so the migration also
  # works on a freshly installed system where the ids differ.
  NAV_GROUP_NAME = "group_nav_pl_connect_connect"
  LINK_NAME = "link_nav_pl_connect_workspace"

  def up
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    role = _upgrade_role
    link = _create_navigation_link
    _restrict_link_to_role(link: link, role: role) if link.present? && role.present?
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def down
    @c = ControllerHelper.init_tenant(:default, {}, true, true)

    link = LinkItem.find_by(name: LINK_NAME)
    if link.present?
      LinkItemJoinRole.where(link_item_id: link.id).destroy_all
      link.destroy
    end

    # Restore the scaffolded role name. The role itself is deliberately kept:
    # it is still referenced by the navigation group's join row.
    role = Role.find_by(name: ROLE_NAME)
    role&.update_columns(name: LEGACY_ROLE_NAME, title: "PlConnectConnect")
  rescue StandardError => e
    puts "  [EXCEPTION] #{e.message}"
    Rails.logger.error "#{self.class.name}: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  private

  # Renames the scaffolded role to the name the permission check expects.
  # Idempotent: if the role already carries the new name nothing is written.
  def _upgrade_role
    role = Role.find_by(name: ROLE_NAME) || Role.find_by(name: LEGACY_ROLE_NAME)

    if role.blank?
      puts "  [SKIP] Neither #{ROLE_NAME} nor #{LEGACY_ROLE_NAME} found."
      return nil
    end

    return role if role.name == ROLE_NAME

    result = role.save_element(c: @c, element: {
      name: ROLE_NAME,
      title: "Connect Workspace",
      description: "Grants access to the Connect workspace (chat, calendar, calls). " \
                   "The name must stay in sync with the controller name pl_connect_workspace, " \
                   "because the permission check derives the role name from it."
    })

    puts result[:successful] ? "  [OK] Role renamed to #{ROLE_NAME}." : "  [ERROR] #{result[:successful_text]}"
    result[:successful] ? result[:element] : nil
  end

  # Creates the navigation entry below the "Connect" group.
  def _create_navigation_link
    group = LinkItem.find_by(name: NAV_GROUP_NAME)
    if group.blank?
      puts "  [SKIP] Navigation group #{NAV_GROUP_NAME} not found."
      return nil
    end

    link = LinkItem.find_or_initialize_by(parent_id: group.id, name: LINK_NAME)

    result = link.save_element(c: @c, element: {
      # parent_id and parent_uuid always have to be written together: the save
      # pipeline resolves the parent from the uuid first and would otherwise
      # silently restore a stale parent_id.
      parent_id: group.id,
      parent_uuid: group.uuid,
      f_type: "link",
      title: "<i class=\"fa-solid fa-bolt\"></i> Connect",
      description: "Opens the Connect workspace (chat, calendar, calls) as a full screen surface.",
      controller_name: "pl_connect_workspace",
      action_name: "index_element",
      # Deliberately not a turbo link: the workspace uses its own full screen
      # layout. A turbo frame visit would inject the workspace into the
      # "main_content" frame of the regular layout and strip its shell.
      is_turbo_link: false,
      include_search_link: false,
      target: "_self",
      decimal_position: 10.0,
      active: true,
      tenant_id: group.tenant_id,
      tenant_uuid: group.tenant_uuid,
      tenant_independent: group.tenant_independent,
      extension_item_id: group.extension_item_id,
      extension_item_uuid: group.extension_item_uuid
    })

    unless result[:successful]
      puts "  [ERROR] #{result[:successful_text]}"
      return nil
    end

    puts "  [OK] Navigation entry #{LINK_NAME} saved."
    element = result[:element]

    # Keeps de.yml/en.yml in sync with the record - without this the change
    # would only exist in the database.
    YamlHelper.update_yaml(
      c: @c, reference_model: LinkItem, reference_id: element.id,
      auto_translate: SYSTEM&.dig(:language, :auto_translate_in_another_yml_files)
    )

    element
  end

  # Couples the navigation entry to the plugin role. Without a join row the
  # visibility logic treats a link as public, so this is what actually hides the
  # entry from users who are not allowed into the workspace.
  def _restrict_link_to_role(link:, role:)
    join = LinkItemJoinRole.find_or_initialize_by(link_item_id: link.id, role_id: role.id)
    return puts "  [OK] Role assignment already present." if join.persisted?

    result = join.save_element(c: @c, element: {
      link_item_id: link.id,
      link_item_uuid: link.uuid,
      role_id: role.id,
      role_uuid: role.uuid,
      tenant_id: link.tenant_id,
      tenant_uuid: link.tenant_uuid,
      active: true,
      del_flag: false
    })

    puts result[:successful] ? "  [OK] Role assigned to navigation entry." : "  [ERROR] #{result[:successful_text]}"
  end
end
