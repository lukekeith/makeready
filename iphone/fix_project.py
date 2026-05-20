#!/usr/bin/env python3
"""
Fix project.pbxproj by removing broken Card.swift and DataComponent.swift references
and adding all Components/Card files properly.
"""

import re
import uuid

# Read the project file
with open('MakeReady.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Files to add from Components/Card/
card_files = [
    'CardData.swift',
    'CardEvent.swift',
    'CardGroup.swift',
    'CardGroupMini.swift',
    'CardStudy.swift',
    'CardStudyMini.swift',
    'CardVideo.swift',
    'CardVideoMini.swift',
    'DataComponent.swift',
]

# Generate unique IDs for each file (2 IDs per file: BuildFile and FileReference)
def generate_id():
    """Generate a unique 24-character hex ID for Xcode"""
    return uuid.uuid4().hex[:24].upper()

file_ids = {}
for filename in card_files:
    file_ids[filename] = {
        'buildfile': generate_id(),
        'fileref': generate_id(),
    }

# Generate IDs for groups
components_group_id = generate_id()
card_group_id = generate_id()

print("Generated IDs:")
print(f"Components Group: {components_group_id}")
print(f"Card Group: {card_group_id}")
for filename, ids in file_ids.items():
    print(f"{filename}: BuildFile={ids['buildfile']}, FileRef={ids['fileref']}")

# Step 1: Remove old broken references
print("\nRemoving broken references...")

# Remove from PBXBuildFile section (lines 36-37)
content = re.sub(
    r'\t\tA1000107000000000000001 /\* DataComponent\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = A1000108000000000000001 /\* DataComponent\.swift \*/; \};\n',
    '',
    content
)
content = re.sub(
    r'\t\tA1000109000000000000001 /\* Card\.swift in Sources \*/ = \{isa = PBXBuildFile; fileRef = A1000110000000000000001 /\* Card\.swift \*/; \};\n',
    '',
    content
)

# Remove from PBXFileReference section (lines 89-90)
content = re.sub(
    r'\t\tA1000108000000000000001 /\* DataComponent\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = DataComponent\.swift; sourceTree = "<group>"; \};\n',
    '',
    content
)
content = re.sub(
    r'\t\tA1000110000000000000001 /\* Card\.swift \*/ = \{isa = PBXFileReference; lastKnownFileType = sourcecode\.swift; path = Card\.swift; sourceTree = "<group>"; \};\n',
    '',
    content
)

# Remove from PBXGroup MakeReady children (lines 160-161)
content = re.sub(
    r'\t\t\t\tA1000108000000000000001 /\* DataComponent\.swift \*/,\n',
    '',
    content
)
content = re.sub(
    r'\t\t\t\tA1000110000000000000001 /\* Card\.swift \*/,\n',
    '',
    content
)

# Remove from PBXSourcesBuildPhase (lines 307-308)
content = re.sub(
    r'\t\t\t\tA1000107000000000000001 /\* DataComponent\.swift in Sources \*/,\n',
    '',
    content
)
content = re.sub(
    r'\t\t\t\tA1000109000000000000001 /\* Card\.swift in Sources \*/,\n',
    '',
    content
)

# Step 2: Add new PBXBuildFile entries (after line 9)
print("Adding PBXBuildFile entries...")
buildfile_section = "/* Begin PBXBuildFile section */"
buildfile_entries = []
for filename in card_files:
    buildfile_id = file_ids[filename]['buildfile']
    fileref_id = file_ids[filename]['fileref']
    entry = f"\t\t{buildfile_id} /* {filename} in Sources */ = {{isa = PBXBuildFile; fileRef = {fileref_id} /* {filename} */; }};"
    buildfile_entries.append(entry)

buildfile_block = "\n".join(buildfile_entries)
content = content.replace(
    buildfile_section,
    f"{buildfile_section}\n{buildfile_block}"
)

# Step 3: Add new PBXFileReference entries (after line 59)
print("Adding PBXFileReference entries...")
fileref_section = "/* Begin PBXFileReference section */"
fileref_entries = []
for filename in card_files:
    fileref_id = file_ids[filename]['fileref']
    entry = f"\t\t{fileref_id} /* {filename} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {filename}; sourceTree = \"<group>\"; }};"
    fileref_entries.append(entry)

fileref_block = "\n".join(fileref_entries)
content = content.replace(
    fileref_section,
    f"{fileref_section}\n{fileref_block}"
)

# Step 4: Add Card group (before MakeReady group section ends, around line 179)
print("Adding Card group...")
card_children = []
for filename in card_files:
    fileref_id = file_ids[filename]['fileref']
    card_children.append(f"\t\t\t\t{fileref_id} /* {filename} */,")

card_children_block = "\n".join(card_children)

card_group = f"""\t\t{card_group_id} /* Card */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
{card_children_block}
\t\t\t);
\t\t\tpath = Card;
\t\t\tsourceTree = "<group>";
\t\t}};"""

# Step 5: Add Components group
components_group = f"""\t\t{components_group_id} /* Components */ = {{
\t\t\tisa = PBXGroup;
\t\t\tchildren = (
\t\t\t\t{card_group_id} /* Card */,
\t\t\t);
\t\t\tpath = Components;
\t\t\tsourceTree = "<group>";
\t\t}};"""

# Insert before "/* End PBXGroup section */"
end_group_section = "/* End PBXGroup section */"
content = content.replace(
    end_group_section,
    f"{components_group}\n{card_group}\n{end_group_section}"
)

# Step 6: Add Components group reference to MakeReady group children
# Find the MakeReady group and add Components reference after ShareInviteSheet.swift
makeready_pattern = r'(A1000102000000000000001 /\* ShareInviteSheet\.swift \*/,)'
makeready_replacement = f'\\1\n\t\t\t\t{components_group_id} /* Components */,'
content = re.sub(makeready_pattern, makeready_replacement, content)

# Step 7: Add to PBXSourcesBuildPhase
print("Adding to build phase...")
# Find the PBXSourcesBuildPhase section and add our files
sources_phase_pattern = r'(files = \()'
sources_entries = []
for filename in card_files:
    buildfile_id = file_ids[filename]['buildfile']
    sources_entries.append(f"\t\t\t\t{buildfile_id} /* {filename} in Sources */,")

sources_block = "\n".join(sources_entries)
content = re.sub(
    sources_phase_pattern,
    f'\\1\n{sources_block}',
    content,
    count=1
)

# Write the updated content
with open('MakeReady.xcodeproj/project.pbxproj', 'w') as f:
    f.write(content)

print("\n✅ project.pbxproj updated successfully!")
print("Removed broken Card.swift and DataComponent.swift references")
print("Added Components/Card folder with all 9 card component files")
