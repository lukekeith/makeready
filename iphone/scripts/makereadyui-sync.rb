#!/usr/bin/env ruby
# frozen_string_literal: true
#
# Make every Swift file under iphone/MakeReadyUI/ a member of the MakeReadyUI
# framework target, and every .xcassets under it a RESOURCE of that target
# (ui2-shell SPEC D1/D29).
#
# MakeReadyUI is its own Swift module, so its types carry no prefix. The sources
# sit in iphone/MakeReadyUI/, beside iphone/MakeReady/ (D23), and the group is
# parented under the project's main group. Every source and catalog is ALSO a
# member of the MakeReady app target (D29): the app compiles the 2.0 views into
# its own module and never links the framework (a Release archive cannot use
# `@testable import`). Run `ruby iphone/scripts/capture-targets.rb` afterwards so
# the MakeReadyCapture target picks up the app target's new files.
#
# The project has no file-system-synchronised groups (objectVersion 56), so a
# generated file is invisible to the compiler until it is referenced here. This
# script SYNCS the folder rather than adding one file: it is idempotent, so
# d2m re-runs it after writing each new view without tracking what it added
# last time.

require 'xcodeproj'
require 'pathname'

repo_root    = Pathname.new(__dir__).parent.parent
project_path = repo_root.join('iphone/MakeReady.xcodeproj')
preview_dir  = repo_root.join('iphone/MakeReadyUI')

abort("no MakeReadyUI directory at #{preview_dir}") unless preview_dir.directory?

project = Xcodeproj::Project.open(project_path.to_s)
target  = project.targets.find { |t| t.name == 'MakeReadyUI' }
abort('MakeReadyUI target not found') if target.nil?
app = project.targets.find { |t| t.name == 'MakeReady' } || abort('MakeReady target not found')

# The group sits under the MAIN group (iphone/MakeReadyUI beside iphone/MakeReady),
# recorded with a relative path.
group = project.main_group.find_subpath('MakeReadyUI', true)
group.set_source_tree('<group>')
group.set_path('MakeReadyUI')

# Key existing references by their path relative to the MakeReadyUI group (not
# just the basename), so a file in a subdirectory is tracked distinctly from a
# same-named file elsewhere, and so the reference's `path` — which Xcode
# resolves relative to the group, not just the basename — stays correct.
existing = group.files.to_h { |f| [f.path, f] }
added = []

# Recurse: "every .swift file under MakeReadyUI/" includes subdirectories.
# Files stay flat members of this one MakeReadyUI group (Xcode does not require
# the group tree to mirror the folder tree) — only the reference's `path` needs
# to carry the subdirectory-relative path so Xcode looks in the right place.
on_disk = Dir.glob(preview_dir.join('**/*.swift')).sort
on_disk_relative = on_disk.map { |path| Pathname.new(path).relative_path_from(preview_dir).to_s }

on_disk_relative.each do |rel_path|
  ref = existing[rel_path] || group.new_reference(rel_path)
  unless target.source_build_phase.files_references.include?(ref)
    target.add_file_references([ref])
    added << rel_path
  end
  unless app.source_build_phase.files_references.include?(ref)
    app.add_file_references([ref])
    added << "#{rel_path} (MakeReady)"
  end
end

# Asset catalogs are RESOURCES, not sources: they carry the 2.0 glyph vectors
# (C-021), which iOS can only render through a catalog — a raw .svg in a bundle
# is not loadable. Globbed non-recursively into the catalog itself (an .xcassets
# is a directory; its contents must NOT be added individually).
catalogs = Dir.glob(preview_dir.join('**/*.xcassets')).sort
catalogs_relative = catalogs.map { |path| Pathname.new(path).relative_path_from(preview_dir).to_s }

catalogs_relative.each do |rel_path|
  ref = existing[rel_path] || group.new_reference(rel_path)
  unless target.resources_build_phase.files_references.include?(ref)
    target.resources_build_phase.add_file_reference(ref)
    added << "#{rel_path} (resource)"
  end
  unless app.resources_build_phase.files_references.include?(ref)
    app.resources_build_phase.add_file_reference(ref)
    added << "#{rel_path} (MakeReady resource)"
  end
end

# Drop references to files that no longer exist on disk, so a deleted preview
# does not break the build with a missing-file error.
removed = group.files.reject { |f| File.exist?(preview_dir.join(f.path)) }  # a .xcassets is a directory — File.exist? is true for it
removed.each(&:remove_from_project)

project.save
puts "MakeReadyUI: #{group.files.count} file(s) in targets MakeReadyUI + MakeReady"
puts "  added:   #{added.empty? ? '(none)' : added.join(', ')}"
puts "  removed: #{removed.empty? ? '(none)' : removed.map(&:path).join(', ')}"
