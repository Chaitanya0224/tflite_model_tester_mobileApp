plugins {
    id("com.android.application")
    id("kotlin-android")
    // Add the Flutter Gradle Plugin
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.object_detector"
    compileSdk = 35 // Use a specific version instead of flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.example.object_detector"
        minSdk = 21 // Use a specific version instead of flutter.minSdkVersion
        targetSdk = 35 // Use a specific version instead of flutter.targetSdkVersion
        versionCode = 1 // Use a specific version instead of flutter.versionCode
        versionName = "1.0" // Use a specific version instead of flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Prevent compression of .tflite models
    packaging {
        resources {
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
        }
    }

    // Use androidResources instead of deprecated aaptOptions
    androidResources {
        noCompress += "tflite"
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}