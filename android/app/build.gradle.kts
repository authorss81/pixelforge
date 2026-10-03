plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing comes from android/key.properties, which is never committed.
// See docs/SIGNING.md. A missing file is a hard error for release builds only;
// debug builds keep working so `flutter run` is unaffected.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

fun releaseTaskRequested(): Boolean =
    gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }

android {
    namespace = "dev.pixelforge.pixelforge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.pixelforge.pixelforge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            } else if (releaseTaskRequested()) {
                throw GradleException(
                    "android/key.properties not found, so there is nothing to sign the release with. " +
                        "Create it from android/key.properties.example. Full instructions: docs/SIGNING.md. " +
                        "Refusing to fall back to the debug key: a debug-signed release cannot be updated " +
                        "in place later and the Play Store rejects it outright."
                )
            } else {
                // Debug and profile builds. Signing with the debug key is fine here.
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

// Fails unless android/key.properties exists and names all four values.
// Run it any time: ./gradlew :app:verifyReleaseSigning
tasks.register("verifyReleaseSigning") {
    doLast {
        if (!keystorePropertiesFile.exists()) {
            throw GradleException(
                "android/key.properties not found. Copy android/key.properties.example " +
                    "and fill it in. See docs/SIGNING.md."
            )
        }
        val required = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
        val missing = required.filter { (keystoreProperties[it] as String?).isNullOrBlank() }
        if (missing.isNotEmpty()) {
            throw GradleException(
                "android/key.properties is missing values for: ${missing.joinToString(", ")}. " +
                    "See docs/SIGNING.md."
            )
        }
        val store = file(keystoreProperties["storeFile"] as String)
        if (!store.exists()) {
            throw GradleException(
                "keystore file not found at ${store.absolutePath} (storeFile in android/key.properties)."
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
