# Flutter App Build Instructions

## Prerequisites

### 1. Install Flutter SDK

```bash
# Option A: Using snap (Ubuntu/Debian)
sudo snap install flutter --classic

# Option B: Manual installation
cd ~
git clone https://github.com/flutter/flutter.git -b stable
export PATH="$PATH:$HOME/flutter/bin"
echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc

# Verify installation
flutter doctor
```

### 2. Install Android SDK

```bash
# Install Android Studio or command-line tools
# Download from: https://developer.android.com/studio

# Or install via sdkmanager:
sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# Set environment variables
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

### 3. Accept Android Licenses

```bash
flutter doctor --android-licenses
```

## Build the APK

### Step 1: Navigate to project

```bash
cd "/data/AI  Tools/Audio for Dutch Learn/flutter_app/dutch_learn_app"
```

### Step 2: Get dependencies

```bash
flutter pub get
```

### Step 3: Analyze code (optional)

```bash
flutter analyze
```

### Step 4: Run tests (optional)

```bash
flutter test
```

### Step 5: Build release APK

```bash
flutter build apk --release
```

### Step 6: Find APK

APK location:
```
build/app/outputs/flutter-apk/app-release.apk
```

Copy to accessible location:
```bash
cp build/app/outputs/flutter-apk/app-release.apk ~/dutch_learn_app.apk
```

## Install on Phone

### Option A: USB Transfer

1. Connect phone via USB
2. Enable "File Transfer" mode on phone
3. Copy APK to phone
4. Open file manager on phone
5. Tap APK to install
6. Enable "Install from unknown sources" if prompted

### Option B: ADB Install

```bash
adb install ~/dutch_learn_app.apk
```

### Option C: Google Drive

1. Upload APK to Google Drive
2. Download on phone
3. Install from Downloads

## Troubleshooting

### "minSdk version" error

Edit `android/app/build.gradle`:
```gradle
defaultConfig {
    minSdk = 21  // Ensure this is 21 or higher
}
```

### "NDK version" warning

Can be ignored, or install NDK via Android Studio.

### Google Sign-In issues

1. Create project in [Google Cloud Console](https://console.cloud.google.com)
2. Enable Google Drive API
3. Create OAuth 2.0 credentials (Android)
4. Add SHA-1 fingerprint from your keystore
5. Update `google_services.json`

## Signed Release Build (Optional)

For production, create a signed APK:

### 1. Generate keystore

```bash
keytool -genkey -v -keystore ~/dutch-learn-key.jks \
    -keyalg RSA -keysize 2048 -validity 10000 \
    -alias dutch-learn
```

### 2. Create key.properties

Create file: `android/key.properties`
```properties
storePassword=your_store_password
keyPassword=your_key_password
keyAlias=dutch-learn
storeFile=/home/your_username/dutch-learn-key.jks
```

### 3. Update build.gradle

The app is already configured to look for `key.properties`. Just create the file and rebuild.

### 4. Build signed APK

```bash
flutter build apk --release
```

## App Usage

### First Time Setup

1. Open app
2. Tap "Sync from Google Drive"
3. Sign in with Google account
4. Grant Google Drive access
5. Browse to folder with exported JSON + MP3 files
6. Select and download files

### Learning

1. Select a project from home screen
2. Tap any sentence to view details
3. Use audio controls:
   - Play/Pause
   - Speed (0.5x - 2.0x)
   - Loop (1x, 3x, 5x, infinite)
4. Tap underlined words for definitions

### Exporting Data from Web App

On the web app (localhost:8000):
1. Process an audio/video file
2. Click "Export" button
3. Save JSON file to Google Drive
4. Copy MP3 audio file to same folder
5. Sync from mobile app
