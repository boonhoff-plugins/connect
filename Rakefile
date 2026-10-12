# Release workflow for THIS folder's OWN git repository - fully
# self-contained (no dependency on the surrounding monorepo, system/ or
# extensions/ as siblings) so it keeps working even when this folder is
# cloned standalone onto a server that only has this one repo checked out.
# See DocumentationItem 1110 ("Extensions") for the full write-up, including
# the multi-person workflow below.
#
# Only works once this folder IS its own independent git repository (its own
# "git init"/clone, own "origin" remote) - not while it is still just a
# subdirectory of a bigger repository (e.g. right after being generated,
# before being extracted/published). release:start checks this and tells you
# so if it isn't the case yet.
#
# Usage (from this directory):
#   rake 'release:start[0.0.2]'   # branch off main, bump the gemspec, push
#   ... anyone: git fetch && git checkout 0.0.2, then git add/commit/push as usual ...
#   rake release:finish           # pull latest, squash-merge into main, tag, push, gh release
#
# Quoting the task name is only needed because of the [brackets] - most
# shells would otherwise try to glob-expand them.
Dir.chdir(__dir__)

VERSION_PATTERN = /\A\d+\.\d+\.\d+\z/

def sh!(cmd)
  sh(cmd) { |ok, _| abort "Command failed: #{cmd}" unless ok }
end

def capture(cmd)
  `#{cmd}`.strip
end

def current_branch
  capture("git rev-parse --abbrev-ref HEAD")
end

def working_tree_clean?
  capture("git status --porcelain").empty?
end

def gemspec_file
  named = "#{File.basename(Dir.pwd)}.gemspec"
  return named if File.exist?(named)

  # Fallback for the (expected) case of several gemspecs in one plugin folder
  # (one per sub-model, see connect) - the folder-name match above is tried
  # first precisely to avoid picking an arbitrary one of those instead.
  Dir.glob("*.gemspec").first || abort("No .gemspec file found in #{Dir.pwd} - is this the right directory?")
end

# A branch/tag always applies to the WHOLE repository it lives in - so
# versioning this folder only works once it is its own repository, not while
# it is still a subdirectory of a bigger one (e.g. the monorepo this was
# generated inside, before being extracted into its own repo/remote).
def ensure_own_repo!
  toplevel = capture("git rev-parse --show-toplevel")
  abort "Not inside a git repository at all." if toplevel.empty?
  return if File.realpath(toplevel) == File.realpath(Dir.pwd)

  abort <<~MSG
    This folder is not its own independent git repository yet - it is still
    part of a bigger repository rooted at:
      #{toplevel}
    Either turn this folder into its own repository first (git init + add a
    remote), or use that repository's own root-level release workflow
    instead (see DocumentationItem 1071 for the core/monorepo variant).
  MSG
end

def bump_gemspec_version(version)
  file = gemspec_file
  content = File.read(file)
  updated = content.sub(/^(\s*s\.version\s*=\s*)'[^']*'/, "\\1'#{version}'")
  abort "Could not find s.version line in #{file}" if updated == content
  File.write(file, updated)
  file
end

def update_changelog(version, notes_lines)
  header = "# Changelog\n\n"
  entry = "## [#{version}] - #{Date.today}\n\n#{notes_lines.map { |l| "- #{l}" }.join("\n")}\n\n"

  if File.exist?("CHANGELOG.md")
    existing = File.read("CHANGELOG.md").sub(/\A# Changelog\n\n/, "") # re-added below, avoids a duplicate header
    File.write("CHANGELOG.md", header + entry + existing)
  else
    File.write("CHANGELOG.md", header + entry)
  end
end

require "date"

namespace :release do
  desc "Create a version branch off main, bump the gemspec and push it (usage: rake 'release:start[0.0.2]')"
  task :start, [ :version ] do |_t, args|
    ensure_own_repo!

    version = args[:version]
    abort "Usage: rake 'release:start[0.0.2]'" if version.nil? || version.empty?
    abort "Version must look like 0.0.2 (got #{version.inspect})" unless version.match?(VERSION_PATTERN)
    abort "Working tree is not clean - commit or stash first:\n#{capture('git status --short')}" unless working_tree_clean?

    branch_exists = !capture("git branch --list #{version}").empty? || !capture("git branch -r --list origin/#{version}").empty?
    abort "Branch '#{version}' already exists (locally or on origin)." if branch_exists
    tag_exists = !capture("git tag --list v#{version}").empty?
    abort "Tag 'v#{version}' already exists - pick a new version." if tag_exists

    sh!("git checkout main")
    sh!("git pull")
    sh!("git checkout -b #{version}")

    file = bump_gemspec_version(version)
    if working_tree_clean?
      puts "#{file} already reads '#{version}' - nothing to bump, continuing."
    else
      sh!("git add #{file}")
      sh!("git commit -m 'Bump version to #{version}'")
    end
    sh!("git push -u origin #{version}")

    puts
    puts "Branch '#{version}' created and pushed. Anyone can now join in with:"
    puts "  git fetch && git checkout #{version}"
    puts "...and 'git add'/'git commit'/'git push' on it like usual."
    puts "When ready, run: rake release:finish"
  end

  desc "Pull the latest commits on the current version branch, squash-merge into main, tag, push and publish the GitHub release"
  task :finish do
    ensure_own_repo!

    version = current_branch
    abort "Not on a version branch (currently on '#{version}') - check out the branch created by release:start first." \
      unless version.match?(VERSION_PATTERN)
    abort "Working tree is not clean - commit your changes first:\n#{capture('git status --short')}" unless working_tree_clean?

    sh!("git pull") # picks up anyone else's commits pushed to this same branch

    notes_lines = capture("git log main..#{version} --format=%s --reverse").split("\n")
    notes_lines = [ "No changes recorded." ] if notes_lines.empty?

    puts "About to release v#{version}:"
    puts(notes_lines.map { |l| "  - #{l}" })
    print "Merge '#{version}' into main, tag, push and publish the GitHub release? [y/N] "
    confirmation = ENV["FORCE"] == "1" ? "y" : $stdin.gets.to_s.strip.downcase
    abort "Aborted." unless confirmation == "y"

    sh!("git checkout main")
    sh!("git pull")
    sh!("git merge --squash #{version}")

    file = bump_gemspec_version(version) # defensive - keeps it correct even if it drifted on the branch
    update_changelog(version, notes_lines)
    sh!("git add #{file} CHANGELOG.md")
    sh!("git commit -m 'Release #{version}'")

    sh!("git tag -a v#{version} -m 'Release v#{version}'")
    sh!("git push origin main --tags")

    notes = notes_lines.map { |l| "- #{l}" }.join("\n")
    sh!("gh release create v#{version} --title 'v#{version}' --notes #{notes.inspect}")

    sh!("git branch -d #{version}")
    sh!("git push origin --delete #{version}")

    puts
    puts "Released v#{version}."
  end
end
