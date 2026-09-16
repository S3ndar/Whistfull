import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is driven by an optional key.properties file (see
// android/key.properties.example). If it's not present, release builds
// fall back to debug signing so the project still builds for anyone who
// hasn't been handed the upload keystore.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ============================================================================
    // Application ID: be.quest.whistly — FINAL, chosen 2026-09-15.
    //
    // Play never allows changing a published app's applicationId. This value
    // must stay in sync with four other places:
    //   - `applicationId` in defaultConfig below
    //   - the Kotlin package + folder: android/app/src/main/kotlin/be/quest/whistly/
    //   - PRODUCT_BUNDLE_IDENTIFIER in ios/Runner.xcodeproj/project.pbxproj
    //   - PRODUCT_BUNDLE_IDENTIFIER in macos/Runner.xcodeproj/project.pbxproj
    //
    // NOTE: `flutter build` rewrites this file ("Upgrading build.gradle.kts").
    // It has already reverted this edit twice. Commit the file before building
    // so `git diff` shows what the tool changed.
    // ============================================================================
    namespace = "be.quest.whistly"

    // compileSdk pinned so CI and every machine build against the same SDK.
    // 36 is what five bundled plugins (google_mobile_ads, in_app_purchase_android,
    // package_info_plus, path_provider_android, webview_flutter_android) compile
    // against. Building on 35 only warns rather than failing, but compileSdk is
    // backward compatible — raising it changes no runtime behaviour and drops
    // no devices, so there is no reason to stay behind.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "be.quest.whistly"
        // NOTE: `flutter build` reverted a previously pinned `minSdk = 23` to this
        // inherited value. Inherited is safe today (Flutter's floor clears Google
        // Mobile Ads' minSdk 23), but it means the minimum Android version — and
        // your device reach on Play — moves with the Flutter version. Pin it
        // deliberately before the first release.
        minSdk = flutter.minSdkVersion
        // TODO: confirm Play's current targetSdk requirement for NEW apps before
        // the first upload — it rises roughly annually. Unlike compileSdk,
        // raising targetSdk changes runtime behaviour, so test after bumping.
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Uses the "release" signing config (from android/key.properties) when
            // present, otherwise falls back to debug signing so `flutter build`
            // and `flutter run --release` keep working without a keystore.
            // TODO: Add your own signing config for the release build before shipping to Play.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}
