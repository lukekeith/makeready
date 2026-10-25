#!/usr/bin/env ruby
# frozen_string_literal: true
# SPEC D5: take the legacy UI out of the MakeReady target. Files stay on disk
# (run the old app from the `legacy-final` tag). Idempotent.
require 'xcodeproj'
require 'pathname'

root = Pathname.new(__dir__).parent.parent
project = Xcodeproj::Project.open(root.join('iphone/MakeReady.xcodeproj').to_s)
app = project.targets.find { |t| t.name == 'MakeReady' } || abort('MakeReady target not found')
base = root.join('iphone/MakeReady')

REMOVE_DIRS  = %w[Pages Components Fixtures].freeze
REMOVE_FILES = %w[
  MainView.swift LoginView.swift Colors.swift Typography.swift FixturesManager.swift CARD_ARCHITECTURE.md
  Services/NavigationCoordinator.swift Services/Route.swift Services/OverlayManager.swift
  Utilities/CachedAsyncImage.swift Utilities/CachedCardImage.swift
].freeze

removed = []
# Sources AND resources: Fixtures/*.json and Components/**/*.md are resources.
[app.source_build_phase, app.resources_build_phase].each do |phase|
  phase.files.dup.each do |bf|
    ref = bf.file_ref or next
    rel = begin
      ref.real_path.relative_path_from(base).to_s
    rescue StandardError
      next
    end
    next unless REMOVE_DIRS.any? { |d| rel.start_with?("#{d}/") } || REMOVE_FILES.include?(rel)

    phase.remove_build_file(bf)
    removed << rel
  end
end
project.save
puts "removed #{removed.size} file(s) from MakeReady target"
