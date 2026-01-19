# Flutter Dependencies
# Dutch Language Learning Mobile App

**Document Version:** 1.0
**Date:** 2025-12-31

---

## 1. Dependencies Overview

This document lists all Flutter packages required for the Dutch Language Learning mobile app, including justification for each choice.

---

## 2. Core Dependencies

### 2.1 State Management

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | ^2.4.9 | State management and dependency injection |
| `riverpod_annotation` | ^2.3.3 | Code generation annotations for Riverpod |

**Justification for Riverpod:**
- Compile-time safety (catches errors before runtime)
- No BuildContext required for accessing state
- Built-in dependency injection
- Easy testing with provider overrides
- Auto-dispose for resource cleanup
- Family modifiers for parameterized providers
- Strong community support and documentation

**Alternatives Considered:**
| Alternative | Why Not Chosen |
|-------------|----------------|
| Provider | No compile-time safety, requires BuildContext |
| Bloc | Higher boilerplate, more complex for this app size |
| GetX | Less type-safe, controversial patterns |
| MobX | Adds complexity with code generation for observables |

---

### 2.2 Navigation

| Package | Version | Purpose |
|---------|---------|---------|
| `go_router` | ^13.0.1 | Declarative navigation and deep linking |

**Justification for GoRouter:**
- Declarative routing (matches Flutter's philosophy)
- Deep linking support (future-proofing)
- Type-safe route parameters
- Easy nested navigation
- Official Flutter team package

**Alternatives Considered:**
| Alternative | Why Not Chosen |
|-------------|----------------|
| Navigator 2.0 raw | Too verbose and complex |
| Auto Route | More code generation overhead |
| Beamer | Less community adoption |

---

### 2.3 Local Database

| Package | Version | Purpose |
|---------|---------|---------|
| `sqflite` | ^2.3.0 | SQLite database for local storage |
| `path` | ^1.8.3 | File path manipulation |
| `path_provider` | ^2.1.1 | Platform-specific file paths |

**Justification for sqflite:**
- Mature and stable (years of production use)
- Full SQL support (complex queries, joins, indexes)
- Transaction support
- Good performance for our data size
- Standard SQLite (portable, well-understood)

**Alternatives Considered:**
| Alternative | Why Not Chosen |
|-------------|----------------|
| Hive | No SQL support, less flexible querying |
| Isar | Newer, less battle-tested |
| Drift | Adds code generation complexity |
| Shared Preferences | Not suitable for structured data |

---

### 2.4 Audio Playback

| Package | Version | Purpose |
|---------|---------|---------|
| `just_audio` | ^0.9.36 | Audio playback with seeking and speed control |
| `audio_service` | ^0.18.12 | Background playback and media controls |

**Justification for just_audio:**
- Feature-rich (seek, speed, loop modes)
- Stream-based position updates
- Excellent documentation
- Active maintenance
- Support for local files and streaming
- Works well with audio_service

**Alternatives Considered:**
| Alternative | Why Not Chosen |
|-------------|----------------|
| audioplayers | Less feature-rich, inconsistent API |
| flutter_sound | More complex, designed for recording too |
| assets_audio_player | Less active development |

---

### 2.5 Google Drive Integration

| Package | Version | Purpose |
|---------|---------|---------|
| `google_sign_in` | ^6.1.6 | Google OAuth authentication |
| `googleapis` | ^12.0.0 | Google APIs client library |
| `googleapis_auth` | ^1.4.1 | OAuth2 authentication for googleapis |
| `http` | ^1.1.2 | HTTP client for API calls |

**Justification:**
- Official Google packages (best compatibility)
- Full Drive API access
- Handles OAuth token refresh automatically
- Well-documented with examples

**Alternatives Considered:**
| Alternative | Why Not Chosen |
|-------------|----------------|
| google_drive | Wrapper package, less maintained |
| dio with custom OAuth | More work to implement |

---

### 2.6 Secure Storage

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_secure_storage` | ^9.0.0 | Encrypted storage for OAuth tokens |

**Justification:**
- Uses Android Keystore for encryption
- Simple API for key-value storage
- Handles encryption automatically
- Industry standard for credential storage

**Alternatives Considered:**
| Alternative | Why Not Chosen |
|-------------|----------------|
| shared_preferences | Not encrypted |
| hive with encryption | More complex setup |

---

### 2.7 Connectivity

| Package | Version | Purpose |
|---------|---------|---------|
| `connectivity_plus` | ^5.0.2 | Network connectivity detection |

**Justification:**
- Stream-based connectivity updates
- Detects WiFi, mobile, none
- Cross-platform support
- Part of plus_plugins family (well maintained)

---

## 3. UI Dependencies

### 3.1 Code Generation

| Package | Version | Purpose |
|---------|---------|---------|
| `freezed_annotation` | ^2.4.1 | Immutable data classes |
| `json_annotation` | ^4.8.1 | JSON serialization |

**Justification for Freezed:**
- Immutable state classes (required for state management)
- Generated copyWith, equality, toString
- Union types for sealed classes
- Reduces boilerplate significantly

---

### 3.2 UI Components

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_svg` | ^2.0.9 | SVG image rendering |
| `shimmer` | ^3.0.0 | Loading placeholder animations |
| `flutter_animate` | ^4.3.0 | Declarative animations |

**Justification:**
- flutter_svg: For scalable icons and illustrations
- shimmer: Professional loading states
- flutter_animate: Easy staggered animations

---

### 3.3 Utilities

| Package | Version | Purpose |
|---------|---------|---------|
| `uuid` | ^4.2.2 | Generate unique IDs for entities |
| `intl` | ^0.18.1 | Date/time formatting, future i18n |
| `collection` | ^1.18.0 | Extended collection utilities |

---

## 4. Development Dependencies

### 4.1 Code Generation

| Package | Version | Purpose |
|---------|---------|---------|
| `build_runner` | ^2.4.7 | Run code generators |
| `freezed` | ^2.4.6 | Generate freezed classes |
| `json_serializable` | ^6.7.1 | Generate JSON serialization |
| `riverpod_generator` | ^2.3.9 | Generate Riverpod providers |

---

### 4.2 Testing

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_test` | (sdk) | Widget and unit testing |
| `mocktail` | ^1.0.1 | Mocking for tests |
| `fake_async` | ^1.3.1 | Control async in tests |

**Justification for mocktail:**
- Simple syntax (no code generation)
- Null-safe from the start
- Easy verification
- Works well with Riverpod

---

### 4.3 Code Quality

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_lints` | ^3.0.1 | Recommended lint rules |
| `very_good_analysis` | ^5.1.0 | Stricter lint rules (optional) |

---

## 5. Complete pubspec.yaml

```yaml
name: dutch_learn_app
description: Dutch language learning mobile app with audio playback and Google Drive sync.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'
  flutter: '>=3.16.0'

dependencies:
  flutter:
    sdk: flutter

  # State Management & DI
  flutter_riverpod: ^2.4.9
  riverpod_annotation: ^2.3.3

  # Navigation
  go_router: ^13.0.1

  # Local Database
  sqflite: ^2.3.0
  path: ^1.8.3
  path_provider: ^2.1.1

  # Audio
  just_audio: ^0.9.36
  audio_service: ^0.18.12

  # Google Drive
  google_sign_in: ^6.1.6
  googleapis: ^12.0.0
  googleapis_auth: ^1.4.1
  http: ^1.1.2

  # Security
  flutter_secure_storage: ^9.0.0

  # Connectivity
  connectivity_plus: ^5.0.2

  # Data Classes
  freezed_annotation: ^2.4.1
  json_annotation: ^4.8.1

  # UI
  flutter_svg: ^2.0.9
  shimmer: ^3.0.0
  flutter_animate: ^4.3.0

  # Utilities
  uuid: ^4.2.2
  intl: ^0.18.1
  collection: ^1.18.0

dev_dependencies:
  flutter_test:
    sdk: flutter

  # Code Generation
  build_runner: ^2.4.7
  freezed: ^2.4.6
  json_serializable: ^6.7.1
  riverpod_generator: ^2.3.9

  # Testing
  mocktail: ^1.0.1
  fake_async: ^1.3.1

  # Linting
  flutter_lints: ^3.0.1
  # very_good_analysis: ^5.1.0  # Optional: stricter rules

flutter:
  uses-material-design: true

  assets:
    - assets/images/

  # fonts:
  #   - family: CustomFont
  #     fonts:
  #       - asset: assets/fonts/CustomFont-Regular.ttf
```

---

## 6. Android Configuration

### 6.1 android/app/build.gradle.kts

```kotlin
android {
    namespace = "com.example.dutch_learn_app"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.example.dutch_learn_app"
        minSdk = 26  // Android 8.0 Oreo
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("release")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

dependencies {
    // Google Play Services for Google Sign-In
    implementation("com.google.android.gms:play-services-auth:20.7.0")
}
```

### 6.2 android/app/src/main/AndroidManifest.xml

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Internet permission for Google Drive API -->
    <uses-permission android:name="android.permission.INTERNET" />

    <!-- For checking network state -->
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />

    <!-- For foreground audio service -->
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />

    <!-- For audio focus -->
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application
        android:label="Dutch Learn"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:allowBackup="true"
        android:usesCleartextTraffic="false">

        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">

            <intent-filter>
                <action android:name="android.intent.action.MAIN"/>
                <category android:name="android.intent.category.LAUNCHER"/>
            </intent-filter>
        </activity>

        <!-- Audio Service for background playback -->
        <service
            android:name="com.ryanheise.audioservice.AudioService"
            android:foregroundServiceType="mediaPlayback"
            android:exported="true">
            <intent-filter>
                <action android:name="android.media.browse.MediaBrowserService" />
            </intent-filter>
        </service>

        <!-- Media Button Receiver -->
        <receiver
            android:name="com.ryanheise.audioservice.MediaButtonReceiver"
            android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MEDIA_BUTTON" />
            </intent-filter>
        </receiver>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
```

---

## 7. Dependency Update Policy

### 7.1 Version Constraints

| Constraint | Example | When to Use |
|------------|---------|-------------|
| `^x.y.z` | `^2.4.9` | Default - allows minor and patch updates |
| `>=x.y.z <a.b.c` | `>=2.0.0 <3.0.0` | When you need stricter control |
| `x.y.z` | `2.4.9` | Pin exact version (avoid unless necessary) |

### 7.2 Update Schedule

- **Weekly**: Run `flutter pub outdated` to check for updates
- **Monthly**: Update patch versions
- **Quarterly**: Evaluate minor version updates
- **As needed**: Major version updates (with testing)

### 7.3 Update Commands

```bash
# Check for outdated packages
flutter pub outdated

# Update to latest allowed versions
flutter pub upgrade

# Update specific package
flutter pub upgrade <package_name>

# Regenerate code after updates
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 8. Package Size Impact

| Package | Approximate Size Impact |
|---------|------------------------|
| flutter_riverpod | ~100 KB |
| go_router | ~50 KB |
| sqflite | ~200 KB (includes native) |
| just_audio | ~500 KB (includes native) |
| audio_service | ~150 KB |
| google_sign_in | ~300 KB |
| googleapis | ~200 KB |
| flutter_secure_storage | ~100 KB |
| Other packages | ~300 KB |
| **Total packages** | **~2 MB** |
| Flutter runtime | ~5 MB |
| **Estimated APK size** | **~15-20 MB** |

---

## 9. Security Considerations

### 9.1 Dependency Vulnerabilities

Run periodic security audits:

```bash
# Check for known vulnerabilities
flutter pub audit

# Check dependency licenses
flutter pub deps --style=compact
```

### 9.2 Package Trust

All selected packages are:
- From pub.dev verified publishers
- Actively maintained (commits within 6 months)
- Have significant download counts
- Have passing CI/tests

---

## 10. Future Considerations

### 10.1 Potential Additions

| Package | Purpose | When Needed |
|---------|---------|-------------|
| `flutter_local_notifications` | Reminder notifications | If reminders feature added |
| `shared_preferences` | Simple settings cache | If settings get complex |
| `firebase_core` + `firebase_crashlytics` | Crash reporting | If analytics needed |
| `flutter_tts` | Text-to-speech | If pronunciation feature added |
| `in_app_purchase` | Purchases | If monetization added |

### 10.2 Migration Paths

- If Riverpod 3.x releases: Follow migration guide, expect minor changes
- If go_router major update: Evaluate AutoRoute as alternative
- If sqflite deprecated: Migrate to Drift with generated code

---

**Document Control**

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-12-31 | Solution Architect | Initial dependency list |
