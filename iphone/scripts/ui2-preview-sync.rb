#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Make every Swift file under MakeReady/UI2Preview/ a member of the UI2Preview
# framework target, and every .xcassets under it a RESOURCE of that target
# (docs/ui2/preview-build.md §2).
#
# UI2Preview is its own Swift module, so its types carry no prefix and cannot
# collide with the 1.0 types in MakeReady/Components/. The sources still SIT
# under MakeReady/ on disk (path stability, and SwiftLint's `included: MakeReady`
# keeps covering them) but they are NOT in the MakeReady target.
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
target  = project.targets.find { |t| t.name == 'UI2Preview' }
abort('UI2Preview target not found') if target.nil?

# The group is created relative to the MakeReady group so the pbxproj records a
# relative path, not this machine's absolute one.
parent = project.main_group.find_subpath('MakeReady', false)
abort('MakeReady group not found') if parent.nil?
group = parent.find_subpath('UI2Preview', true)
group.set_source_tree('<group>')
group.set_path('UI2Preview')

# Key existing references by their path relative to the UI2Preview group (not
# just the basename), so a file in a subdirectory is tracked distinctly from a
# same-named file elsewhere, and so the reference's `path` — which Xcode
# resolves relative to the group, not just the basename — stays correct.
existing = group.files.to_h { |f| [f.path, f] }
added = []

# Recurse: "every .swift file under UI2Preview/" includes subdirectories.
# Files stay flat members of this one UI2Preview group (Xcode does not require
# the group tree to mirror the folder tree) — only the reference's `path` needs
# to carry the subdirectory-relative path so Xcode looks in the right place.
on_disk = Dir.glob(preview_dir.join('**/*.swift')).sort
on_disk_relative = on_disk.map { |path| Pathname.new(path).relative_path_from(preview_dir).to_s }

on_disk_relative.each do |rel_path|
  ref = existing[rel_path] || group.new_reference(rel_path)
  next if target.source_build_phase.files_references.include?(ref)

  target.add_file_references([ref])
  added << rel_path
end

# Asset catalogs are RESOURCES, not sources: they carry the 2.0 glyph vectors
# (C-021), which iOS can only render through a catalog — a raw .svg in a bundle
# is not loadable. Globbed non-recursively into the catalog itself (an .xcassets
# is a directory; its contents must NOT be added individually).
catalogs = Dir.glob(preview_dir.join('**/*.xcassets')).sort
catalogs_relative = catalogs.map { |path| Pathname.new(path).relative_path_from(preview_dir).to_s }

catalogs_relative.each do |rel_path|
  ref = existing[rel_path] || group.new_reference(rel_path)
  next if target.resources_build_phase.files_references.include?(ref)

  target.resources_build_phase.add_file_reference(ref)
  added << "#{rel_path} (resource)"
end

# Drop references to files that no longer exist on disk, so a deleted preview
# does not break the build with a missing-file error.
removed = group.files.reject { |f| File.exist?(preview_dir.join(f.path)) }  # a .xcassets is a directory — File.exist? is true for it
removed.each(&:remove_from_project)

project.save
puts "UI2Preview: #{group.files.count} file(s) in target UI2Preview"
puts "  added:   #{added.empty? ? '(none)' : added.join(', ')}"
puts "  removed: #{removed.empty? ? '(none)' : removed.map(&:path).join(', ')}"
