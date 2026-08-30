import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is read from android/key.properties, which is git-ignored and
// never committed. Without it the build falls back to the debug key so that a
// fresh clone still builds — but a debug-signed APK cannot go on Play, and every
// machine's debug key differs, so an update signed elsewhere will not install
// over it. See android/key.properties.example.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKeystore = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.redfort360.trip_planner"
    compileSdk = flutter.compileSdkVersion
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
        applicationId = "com.redfort360.trip_planner"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // R8 stays on. It was on by default and an earlier version of this
            // file switched it off, on the reasoning that the dex is a small
            // share of an APK dominated by the engine. That reasoning was drawn
            // from a measurement taken while R8 was still running: with it off
            // the dex went from 0.52 MB to 3.56 MB, which is three megabytes on
            // a seventeen megabyte download.
            isMinifyEnabled = true
            isShrinkResources = true
        }
    }

    // No `splits { abi { ... } }` block here on purpose.
    //
    // Splitting the engine out per architecture is the whole size story — a
    // universal APK carries arm64-v8a, armeabi-v7a and x86_64 side by side and
    // every phone uses exactly one. But the Flutter Gradle plugin already
    // configures that from `flutter build apk --split-per-abi`. Declaring the
    // block here as well overrode it, Gradle emitted a single 53 MB universal
    // APK, and the build then failed looking for per-ABI filenames that were
    // never produced. Use the flag; see tool/build_release.sh.
}

flutter {
    source = "../.."
}
