#!/usr/bin/env python3
"""
Add CardFixtures.swift and cards.json to the project.pbxproj
"""

import re
import uuid

# Read the project file
with open('MakeReady.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Generate unique IDs
def generate_id():
    """Generate a unique 24-character hex ID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

# IDs for CardFixtures.swift
card_fixtures_buildfile = generate_id()
card_fixtures_fileref = generate_id()

# IDs for cards.json
cards_json_buildfile = generate_id()
cards_json_fileref = generate_id()

print(f"CardFixtures.swift BuildFile: {card_fixtures_buildfile}")
print(f"CardFixtures.swift FileRef: {card_fixtures_fileref}")
print(f"cards.json BuildFile: {cards_json_buildfile}")
print(f"cards.json FileRef: {cards_json_fileref}")

# Step 1: Add PBXBuildFile entries
print("\nAdding PBXBuildFile entries...")
buildfile_section = "/* Begin PBXBuildFile section */"
buildfile_entries = f"""\t\t{card_fixtures_buildfile} /* CardFixtures.swift in Sources */ = {{isa = PBXBuildFile; fileRef = {card_fixtures_fileref} /* CardFixtures.swift */; }};
\t\t{cards_json_buildfile} /* cards.json in Resources */ = {{isa = PBXBuildFile; fileRef = {cards_json_fileref} /* cards.json */; }};"""

content = content.replace(
    buildfile_section,
    f"{buildfile_section}\n{buildfile_entries}"
)

# Step 2: Add PBXFileReference entries
print("Adding PBXFileReference entries...")
fileref_section = "/* Begin PBXFileReference section */"
fileref_entries = f"""\t\t{card_fixtures_fileref} /* CardFixtures.swift */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = CardFixtures.swift; sourceTree = "<group>"; }};
\t\t{cards_json_fileref} /* cards.json */ = {{isa = PBXFileReference; lastKnownFileType = text.json; path = cards.json; sourceTree = "<group>"; }};"""

content = content.replace(
    fileref_section,
    f"{fileref_section}\n{fileref_entries}"
)

# Step 3: Find the Fixtures group and add these files
print("Adding to Fixtures group...")
# The Fixtures group should already exist (has contacts.json and members.json)
# We need to add CardFixtures.swift and cards.json to it

# Find the Fixtures group pattern
fixtures_pattern = r'(A1000082000000000000001 /\* Fixtures \*/ = \{[\s\S]*?children = \([\s\S]*?)(A1000079000000000000001 /\* contacts\.json \*/,)'

# Add our files before contacts.json
fixtures_replacement = f'\\1{card_fixtures_fileref} /* CardFixtures.swift */,\n\t\t\t\t{cards_json_fileref} /* cards.json */,\n\t\t\t\t\\2'

if re.search(fixtures_pattern, content):
    content = re.sub(fixtures_pattern, fixtures_replacement, content)
    print("✓ Added to Fixtures group")
else:
    print("✗ Could not find Fixtures group pattern")

# Step 4: Add to PBXSourcesBuildPhase (CardFixtures.swift only, not cards.json)
print("Adding CardFixtures.swift to build phase...")
sources_phase_pattern = r'(/\* Begin PBXSourcesBuildPhase section \*/[\s\S]*?files = \()'
sources_entry = f"\n\t\t\t\t{card_fixtures_buildfile} /* CardFixtures.swift in Sources */,"

content = re.sub(sources_phase_pattern, f'\\1{sources_entry}', content, count=1)

# Step 5: Add to PBXResourcesBuildPhase (cards.json only)
print("Adding cards.json to resources phase...")
resources_phase_pattern = r'(/\* Begin PBXResourcesBuildPhase section \*/[\s\S]*?files = \()'
resources_entry = f"\n\t\t\t\t{cards_json_buildfile} /* cards.json in Resources */,"

content = re.sub(resources_phase_pattern, f'\\1{resources_entry}', content, count=1)

# Write the updated content
with open('MakeReady.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ project.pbxproj updated successfully!")
print("Added CardFixtures.swift and cards.json to the project")
