# 🚀 GitHub + Codemagic Setup Guide

## Step 1: After cloning, get the Gradle wrapper JAR

The `gradle-wrapper.jar` is not in source control (it's a binary).
Run this once after cloning:

```bash
flutter pub get
```
Flutter will auto-install the Gradle wrapper. OR manually:
```bash
curl -L "https://raw.githubusercontent.com/gradle/gradle/v8.3.0/gradle/wrapper/gradle-wrapper.jar" \
     -o android/gradle/wrapper/gradle-wrapper.jar
```

## Step 2: Update local.properties

Edit `android/local.properties` with your actual paths:
```
sdk.dir=/path/to/your/Android/Sdk
flutter.sdk=/path/to/your/flutter
```

## Step 3: (Optional) Release Signing

1. Generate a keystore:
```bash
keytool -genkey -v -keystore robocar-release.jks -alias robocar \
        -keyalg RSA -keysize 2048 -validity 10000
```
2. Fill in `android/key.properties` with your passwords
3. **DO NOT commit key.properties or .jks to GitHub**

## Step 4: Codemagic Setup

1. Connect your GitHub repo to [codemagic.io](https://codemagic.io)
2. Upload your keystore under **Code Signing → Android**
3. Set environment variables:
   - `CM_KEYSTORE_PASSWORD`
   - `CM_KEY_PASSWORD`  
   - `CM_KEY_ALIAS` = `robocar`
4. Run the `android-release` workflow

## Step 5: Build locally

```bash
flutter pub get
flutter run              # debug on connected phone
flutter build apk --release  # release APK
```

Output: `build/app/outputs/flutter-apk/app-release.apk`
