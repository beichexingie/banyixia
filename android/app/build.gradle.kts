import java.util.Properties
import java.util.Base64

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val localProperties = Properties().apply {
    val localPropertiesFile = rootProject.file("local.properties")
    if (localPropertiesFile.exists()) {
        localPropertiesFile.inputStream().use { input ->
            load(input)
        }
    }
}

fun dartDefine(name: String): String {
    val encodedDefines = project.findProperty("dart-defines")?.toString().orEmpty()
    return encodedDefines
        .split(',')
        .asSequence()
        .mapNotNull { encoded ->
            try {
                String(Base64.getDecoder().decode(encoded), Charsets.UTF_8)
            } catch (_: IllegalArgumentException) {
                null
            }
        }
        .firstOrNull { it.startsWith("$name=") }
        ?.substringAfter('=')
        ?.trim()
        .orEmpty()
}

// Prefer local.properties for IDE builds, but also accept Flutter's
// --dart-define so the native AMap SDK receives the same key as Dart.
val amapAndroidKey = localProperties.getProperty("amap.android.key", "")
    .trim()
    .ifEmpty { dartDefine("AMAP_ANDROID_KEY") }
val aliyunPushAppKey = localProperties.getProperty("aliyun.push.app.key", "")
val aliyunPushAppSecret = localProperties.getProperty("aliyun.push.app.secret", "")

fun buildConfigString(value: String): String =
    "\"${value.replace("\\", "\\\\").replace("\"", "\\\"")}\""

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_application_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["AMAP_ANDROID_KEY"] = amapAndroidKey
        buildConfigField("String", "ALIYUN_PUSH_APP_KEY", buildConfigString(aliyunPushAppKey))
        buildConfigField("String", "ALIYUN_PUSH_APP_SECRET", buildConfigString(aliyunPushAppSecret))
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            isShrinkResources = false
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.aliyun.ams:alicloud-android-push:4.0.0")
    implementation("com.amap.api:location:6.4.9")
}

flutter {
    source = "../.."
}
