plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// CI and package consumers may not have the project-specific file yet.
// Dropping google-services.json into this directory enables Firebase wiring.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.zaim.mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.sumly.qarz.zaim.kredit"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val uploadKeystore = providers.environmentVariable("SUMLY_UPLOAD_KEYSTORE").orNull
    val uploadPassword = providers.environmentVariable("SUMLY_UPLOAD_PASSWORD").orNull
    val testApk = providers.environmentVariable("SUMLY_TEST_APK").orNull == "true"
    require((uploadKeystore == null) == (uploadPassword == null)) {
        "Set both SUMLY_UPLOAD_KEYSTORE and SUMLY_UPLOAD_PASSWORD to sign the release."
    }
    require(!testApk || uploadKeystore == null) {
        "Test APK mode cannot be combined with upload signing."
    }

    val uploadSigning = uploadKeystore?.let { path ->
        signingConfigs.create("upload") {
            storeFile = file(path)
            storeType = "PKCS12"
            storePassword = uploadPassword
            keyAlias = "sumly-upload"
            keyPassword = uploadPassword
        }
    }
    buildTypes {
        release {
            signingConfig = if (testApk) signingConfigs.getByName("debug") else uploadSigning
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation(platform("com.google.firebase:firebase-bom:34.17.0"))
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.android.installreferrer:installreferrer:2.2")
    implementation("com.google.android.gms:play-services-ads-identifier:18.2.0")
}
