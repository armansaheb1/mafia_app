#!/bin/bash
export JAVA_HOME=/home/ars/java
export ANDROID_HOME=/home/ars/android-sdk
export PATH="$PATH:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:/home/ars/flutter/bin"

cd /home/ars/Mafia/mafia_app
echo "Current directory: $(pwd)"
echo "Flutter version: $(flutter --version | head -1)"
echo "Java version: $(java -version 2>&1 | head -1)"
echo "Starting Flutter app..."
flutter run --debug

