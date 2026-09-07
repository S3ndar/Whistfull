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
    // !!! MUST CHANGE BEFORE THE FIRST PLAY STORE UPLOAD !!!
    //
    // `namespace` and `applicationId` below are still the Flutter template
    // default (com.example.whistfull). Google Play REJECTS uploads whose
    // applicationId starts with "com.example". You must pick a real, final
    // package ID (e.g. com.yourcompany.whistly) and set it in BOTH places
    // below before you ever upload a build to the Play Console.
    //
    // This ID becomes permanent the moment it's uploaded: Play does not allow
    // changing the applicationId of an already-published app, ever. Decide
    // it deliberately, then change it here.
    // ============================================================================
    namespace = "com.example.whistfull"
    // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
    // TODO: Play Store REJECTS "com.example.*" applicationIds. Change this before first upload.
    // TODO: The applicationId can NEVER be changed after your first Play Store upload. Choose carefully.

    // SDK versions are pinned explicitly rather than inherited from the
    // Flutter tool, so CI and every developer machine build against the
    // same target regardless of installed Flutter version.
    compileSdk = 35
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.whistfull"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23 // Google Mobile Ads requires minSdk 23+.
        targetSdk = 35 // Play Store's current requirement for new app submissions.
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
