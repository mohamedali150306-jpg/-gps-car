#!/bin/bash
# Setup script - run once after cloning
echo "Downloading gradle-wrapper.jar..."
curl -L "https://services.gradle.org/distributions/gradle-8.3-all.zip" --output /dev/null --silent
curl -L "https://raw.githubusercontent.com/gradle/gradle/v8.3.0/gradle/wrapper/gradle-wrapper.jar" \
     -o android/gradle/wrapper/gradle-wrapper.jar
echo "Done! Now run: flutter pub get"
