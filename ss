#!/bin/bash
mkdir -p screenshots && pngpaste "screenshots/$(date '+%Y-%m-%d at %H.%M.%S').png" && echo "📸 Screenshot saved to screenshots/"
