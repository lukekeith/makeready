#!/usr/bin/env ruby
# frozen_string_literal: true
#
# d2m video-captures D23 — the MakeReadyCapture app target (Debug only, never archived).
#
# MakeReadyCapture compiles EVERY source of the MakeReady target except MakeReadyApp.swift (its
# @main), the seeded-capture sources that sit in MakeReadyCaptureTests/ (ViewRegistry.swift,
# CaptureFixture.swift, CaptureEnvironment.swift, StubAPIClient.swift — they STAY there on disk,
# because d2m's skills edit them at that path), and its own MakeReadyCapture/*.swift. Its module is
# named MakeReady (PRODUCT_MODULE_NAME), so the shared files' `@testable import MakeReady` is an
# ignored self-import and their `MakeReady.TextInput` qualifications still resolve.
# It also (Task 9) owns the MakeReadyCaptureUITests UI-test target, which compiles
# MakeReadyCaptureUITests/*.swift plus MakeReadyCapture/RecordingJob.swift; the shared scheme
# MakeReadyCapture runs it. MakeReady.app itself gains nothing.
#
# A SYNC, like ui2-preview-sync.rb: idempotent, re-run after the MakeReady target gains or loses a
# file. `--check` changes nothing and exits 3 naming what is out of sync (record.sh runs it).
# CAPTURE_TARGETS_PROJECT=<path to a .xcodeproj> points it at another copy of the project (used to
# stage a commit against HEAD's pbxproj while the working tree carries uncommitted edits).

require 'xcodeproj'
require 'pathname'

CHECK = ARGV.include?('--check')
SHARED = %w[ViewRegistry.swift CaptureFixture.swift CaptureEnvironment.swift StubAPIClient.swift].freeze

repo_root    = Pathname.new(__dir__).parent.parent
project_path = ENV['CAPTURE_TARGETS_PROJECT'] || repo_root.join('iphone/MakeReady.xcodeproj').to_s
own_dir      = repo_root.join('iphone/MakeReadyCapture')

project = Xcodeproj::Project.open(project_path)
find = ->(name) { project.targets.find { |t| t.name == name } || abort("#{name} target not found") }
app   = find.('MakeReady')
tests = find.('MakeReadyCaptureTests')
ui2   = find.('UI2Preview')
changes = []

capture = project.targets.find { |t| t.name == 'MakeReadyCapture' }
if capture.nil?
  changes << 'create target MakeReadyCapture'
  if CHECK
    warn changes.join("\n")
    exit 3
  end
  capture = project.new_target(:application, 'MakeReadyCapture', :ios, '26.0', nil, :swift)
end

# Build settings: the real app's, with the capture app's identity on top.
capture.build_configurations.each do |config|
  source = app.build_configurations.find { |c| c.name == config.name }
  want = source.build_settings.merge(
    'PRODUCT_NAME' => 'MakeReadyCapture',
    'PRODUCT_MODULE_NAME' => 'MakeReady',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.makeready.capture',
    'IPHONEOS_DEPLOYMENT_TARGET' => '26.0',
    'TARGETED_DEVICE_FAMILY' => '1',
    'SKIP_INSTALL' => 'YES',
    'ENABLE_PREVIEWS' => 'NO',
    'SWIFT_VERSION' => '5.0',
    'LD_RUNPATH_SEARCH_PATHS' => ['$(inherited)', '@executable_path/Frameworks']
  )
  next if config.build_settings == want && config.base_configuration_reference == source.base_configuration_reference

  changes << "build settings (#{config.name})"
  next if CHECK

  config.build_settings = want
  config.base_configuration_reference = source.base_configuration_reference
end

# Sources: MakeReady's minus its @main, the shared capture sources, MakeReadyCapture/*.swift.
group = project.main_group.find_subpath('MakeReadyCapture', !CHECK)
own_refs = []
if group
  unless CHECK
    group.set_source_tree('<group>')
    group.set_path('MakeReadyCapture')
  end
  existing = group.files.to_h { |f| [f.path, f] }
  Dir.glob(own_dir.join('*.swift')).sort.map { |p| File.basename(p) }.each do |name|
    ref = existing[name]
    if ref.nil?
      changes << "add MakeReadyCapture/#{name}"
      ref = group.new_reference(name) unless CHECK
    end
    own_refs << ref if ref
  end
end
shared_refs = SHARED.map do |name|
  tests.source_build_phase.files_references.find { |r| r&.path && File.basename(r.path) == name } ||
    abort("MakeReadyCaptureTests no longer compiles #{name}")
end
app_refs = app.source_build_phase.files_references.compact.reject { |r| r.path && File.basename(r.path) == 'MakeReadyApp.swift' }
want_sources = (app_refs + shared_refs + own_refs).uniq
have_sources = capture.source_build_phase.files_references.compact
(want_sources - have_sources).each do |ref|
  changes << "compile #{ref.path}"
  capture.source_build_phase.add_file_reference(ref, true) unless CHECK
end
(have_sources - want_sources).each do |ref|
  changes << "stop compiling #{ref.path}"
  capture.source_build_phase.remove_file_reference(ref) unless CHECK
end

# Resources: the real app's.
(app.resources_build_phase.files_references.compact - capture.resources_build_phase.files_references.compact).each do |ref|
  changes << "resource #{ref.path}"
  capture.resources_build_phase.add_file_reference(ref, true) unless CHECK
end

# UI2Preview: a dependency, linked, and embedded.
unless capture.dependencies.any? { |d| d.target == ui2 }
  changes << 'depend on UI2Preview'
  capture.add_dependency(ui2) unless CHECK
end
product = ui2.product_reference
unless capture.frameworks_build_phase.files_references.include?(product)
  changes << 'link UI2Preview.framework'
  capture.frameworks_build_phase.add_file_reference(product, true) unless CHECK
end
embed = capture.copy_files_build_phases.find { |p| p.name == 'Embed Frameworks' }
unless embed&.files_references&.include?(product)
  changes << 'embed UI2Preview.framework'
  unless CHECK
    embed ||= capture.new_copy_files_build_phase('Embed Frameworks').tap { |p| p.symbol_dst_subfolder_spec = :frameworks }
    file = embed.add_file_reference(product, true)
    file.settings = { 'ATTRIBUTES' => %w[CodeSignOnCopy RemoveHeadersOnCopy] }
  end
end

# The MakeReadyCaptureUITests UI-test target (D23): its own *.swift plus the shared job model.
uitests = project.targets.find { |t| t.name == 'MakeReadyCaptureUITests' }
if uitests.nil?
  changes << 'create target MakeReadyCaptureUITests'
  unless CHECK
    uitests = project.new_target(:ui_test_bundle, 'MakeReadyCaptureUITests', :ios, '26.0', nil, :swift)
    uitests.add_dependency(capture)
  end
end
if uitests
  ui_settings = {
    'PRODUCT_NAME' => '$(TARGET_NAME)',
    'PRODUCT_BUNDLE_IDENTIFIER' => 'com.makeready.MakeReadyCaptureUITests',
    'GENERATE_INFOPLIST_FILE' => 'YES',
    'TEST_TARGET_NAME' => 'MakeReadyCapture',
    'IPHONEOS_DEPLOYMENT_TARGET' => '26.0',
    'TARGETED_DEVICE_FAMILY' => '1',
    'SWIFT_VERSION' => '5.0',
    'CODE_SIGN_STYLE' => 'Automatic'
  }
  uitests.build_configurations.each do |config|
    next if ui_settings.all? { |k, v| config.build_settings[k] == v }

    changes << "UI-test build settings (#{config.name})"
    config.build_settings.merge!(ui_settings) unless CHECK
  end
  ui_group = project.main_group.find_subpath('MakeReadyCaptureUITests', !CHECK)
  ui_refs = []
  if ui_group
    unless CHECK
      ui_group.set_source_tree('<group>')
      ui_group.set_path('MakeReadyCaptureUITests')
    end
    existing = ui_group.files.to_h { |f| [f.path, f] }
    Dir.glob(repo_root.join('iphone/MakeReadyCaptureUITests/*.swift')).sort.map { |p| File.basename(p) }.each do |name|
      ref = existing[name]
      if ref.nil?
        changes << "add MakeReadyCaptureUITests/#{name}"
        ref = ui_group.new_reference(name) unless CHECK
      end
      ui_refs << ref if ref
    end
  end
  job_ref = own_refs.find { |r| r.path == 'RecordingJob.swift' } || abort('MakeReadyCapture/RecordingJob.swift is missing')
  ((ui_refs + [job_ref]) - uitests.source_build_phase.files_references.compact).each do |ref|
    changes << "UI tests compile #{ref.path}"
    uitests.source_build_phase.add_file_reference(ref, true) unless CHECK
  end
  attrs = (project.root_object.attributes['TargetAttributes'] ||= {})
  unless attrs.dig(uitests.uuid, 'TestTargetID') == capture.uuid
    changes << 'UI tests test MakeReadyCapture'
    attrs[uitests.uuid] = { 'CreatedOnToolsVersion' => '26.0', 'TestTargetID' => capture.uuid } unless CHECK
  end
end

# The shared scheme: build + run MakeReadyCapture, test MakeReadyCaptureUITests.
scheme_file = File.join(Xcodeproj::XCScheme.shared_data_dir(project_path), 'MakeReadyCapture.xcscheme')
unless File.exist?(scheme_file) && File.read(scheme_file).include?('MakeReadyCaptureUITests')
  changes << 'write scheme MakeReadyCapture'
  unless CHECK
    scheme = Xcodeproj::XCScheme.new
    scheme.configure_with_targets(capture, uitests, launch_target: true)
    scheme.save_as(project_path, 'MakeReadyCapture', true)
  end
end

if changes.empty?
  puts 'MakeReadyCapture: in sync'
  exit 0
end
if CHECK
  warn "MakeReadyCapture is out of sync with MakeReady:\n  #{changes.join("\n  ")}\nrun: ruby iphone/scripts/capture-targets.rb"
  exit 3
end
project.save
puts "MakeReadyCapture: #{changes.length} change(s)\n  #{changes.first(20).join("\n  ")}#{changes.length > 20 ? "\n  …" : ''}"
