#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Make every Swift file under MakeReady/UI2Preview/ a member of the MakeReady
# target (docs/ui2/preview-build.md §2).
#
# The project has no file-system-synchronised groups (objectVersion 56), so a
# generated file is invisible to the compiler until it is referenced here. This
# script SYNCS the folder rather than adding one file: it is idempotent, so
# /ui2-component-build re-runs it after writing each new preview view without
# tracking what it added last time.

require 'xcodeproj'
require 'pathname'

repo_root   = Pathname.new(__dir__).parent.parent
project_path = repo_root.join('iphone/MakeReady.xcodeproj')
preview_dir  = repo_root.join('iphone/MakeReady/UI2Preview')

abort("no preview directory at #{preview_dir}") unless preview_dir.directory?

project = Xcodeproj::Project.open(project_path.to_s)
target  = project.targets.find { |t| t.name == 'MakeReady' }
abort('MakeReady target not found') if target.nil?

# The group is created relative to the MakeReady group so the pbxproj records a
# relative path, not this machine's absolute one.
parent = project.main_group.find_subpath('MakeReady', false)
abort('MakeReady group not found') if parent.nil?
group = parent.find_subpath('UI2Preview', true)
group.set_source_tree('<group>')
group.set_path('UI2Preview')

existing = group.files.to_h { |f| [f.display_name, f] }
added = []

Dir.glob(preview_dir.join('*.swift')).sort.each do |path|
  name = File.basename(path)
  ref = existing[name] || group.new_reference(name)
  next if target.source_build_phase.files_references.include?(ref)

  target.add_file_references([ref])
  added << name
end

# Drop references to files that no longer exist on disk, so a deleted preview
# does not break the build with a missing-file error.
removed = group.files.reject { |f| File.exist?(preview_dir.join(f.display_name)) }
removed.each(&:remove_from_project)

project.save
puts "UI2Preview: #{group.files.count} file(s) in target MakeReady"
puts "  added:   #{added.empty? ? '(none)' : added.join(', ')}"
puts "  removed: #{removed.empty? ? '(none)' : removed.map(&:display_name).join(', ')}"
