#!/bin/bash

# 1. Exit on error
set -e

# 2. Clone Flutter (Stable channel)
echo "--- Cloning Flutter SDK ---"
if [ ! -d "flutter_sdk" ]; then
  git clone https://github.com/flutter/flutter.git -b stable flutter_sdk
fi

# 3. Add Flutter to the PATH
export PATH="$PATH:`pwd`/flutter_sdk/bin"

# 4. Pre-download Web artifacts
flutter config --enable-web
flutter doctor

# 5. Get dependencies
echo "--- Fetching dependencies ---"
flutter pub get

# 6. Build for Web
echo "--- Building Web Release ---"
flutter build web --release --base-href "/"

echo "--- Build Complete ---"