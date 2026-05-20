---
description: Rebuild and launch iPhone app in simulator
---

Rebuild the MakeReady iPhone app and launch it in the iPhone 17 Pro Max simulator.

**Your task:**
1. Boot the simulator if not already booted (iPhone 17 Pro Max)
2. Open the Simulator.app GUI (`open -a Simulator`)
3. Build the app using xcodebuild
4. Install the newly built app (DO NOT uninstall first - this preserves app data like login sessions)
5. Launch the app
6. Report the process ID

**Important:**
- Change to the `/Users/lukekeith/www/makeready/iphone` directory first
- Use the iPhone 17 Pro Max simulator (or iPhone 17 Pro as fallback)
- Build to `./build` directory
- **DO NOT uninstall the old app** - just install over it to preserve UserDefaults (session cookies, etc.)
- Always open Simulator.app so user can see the app running
- Report any build errors clearly
- Keep output concise - just show build status and final PID
