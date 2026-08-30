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

            // R8 is deliberately left off. It only reaches the Dart/Kotlin dex,
            // which is 0.52 MB of a 52 MB APK — under 1% — while the engine is
            // 97%. The size problem is solved by shipping one ABI instead of
            // three (see tool/build_release.sh), and enabling R8 here would risk
            // stripping something a plugin reaches reflectively for a saving
            // that does not show up.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }

    // Splitting the engine out per architecture is the whole size story: a
    // universal APK carries arm64-v8a, armeabi-v7a and x86_64 side by side and
    // every phone uses exactly one of them.
    splits {
        abi {
            isEnable = project.hasProperty("splitApks")
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86_64")
            isUniversalApk = false
        }
    }
}

flutter {
    source = "../.."
}
