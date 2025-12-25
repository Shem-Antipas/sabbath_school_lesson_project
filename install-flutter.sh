#!/bin/bash
set -e

# Fix locale warnings
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# 1. Install system dependencies needed for Flutter
# We use 'dnf' for Amazon Linux 2023
echo "--- Installing dependencies ---"
sudo dnf install -y mesa-libGLU libicu

# 2. Clone Flutter SDK
echo "--- Cloning Flutter SDK ---"
if [ ! -d "flutter_sdk" ]; then
  git clone https://github.com/flutter/flutter.git -b stable flutter_sdk
fi

# 3. Setup Path
export PATH="$PATH:`pwd`/flutter_sdk/bin"

# 4. Build the app
flutter config --enable-web
flutter pub get
flutter build web --release --base-href "/"

echo "--- Build Finished Successfully ---"