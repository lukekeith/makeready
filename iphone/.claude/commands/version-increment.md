---
description: Increment the app version number (major, minor, or patch)
---

Increment the MakeReady iPhone app version number.

**Ask the user which type of version increment they want.**

After the user selects the increment type, perform these steps:

1. Read the current version from `MakeReady/Info.plist` (the `CFBundleShortVersionString` value)
2. Parse it as `major.minor.patch` (if only `major.minor`, treat patch as 0)
3. Apply the increment:
   - **Major**: `X.0.0` (e.g., `1.1.2` → `2.0.0`)
   - **Minor**: `major.X.0` (e.g., `1.1.2` → `1.2.0`)
   - **Patch**: `major.minor.X` (e.g., `1.1.2` → `1.1.3`)
4. Update the version in ALL of these files:
   - `MakeReady/Info.plist` — `CFBundleShortVersionString`
   - `MakeReady.xcodeproj/project.pbxproj` — ALL `MARKETING_VERSION` entries
   - `MakeReady/Configuration/Debug.xcconfig` — `MARKETING_VERSION`
   - `MakeReady/Configuration/Release.xcconfig` — `MARKETING_VERSION`
   - `Debug.xcconfig` (root) — `MARKETING_VERSION`
   - `Release.xcconfig` (root) — `MARKETING_VERSION`
5. Report the change: "Version updated: X.Y.Z → A.B.C"
6. Ask if the user wants to commit and push

**Do NOT increment `CFBundleVersion` (the build number) — Xcode manages that automatically.**
