#!/bin/bash
git clone https://github.com/flutter/flutter.git -b stable flutter_sdk
export PATH="$PATH:`pwd`/flutter_sdk/bin"
flutter config --enable-web
flutter pub get
flutter build web --release