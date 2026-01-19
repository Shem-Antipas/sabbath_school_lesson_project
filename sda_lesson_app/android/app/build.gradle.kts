plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "adventist.study.hub"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "adventist.study.hub"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        missingDimensionStrategy("default", "production")
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

// ✅ NEW SECTION: ADD THIS AT THE BOTTOM
dependencies {
    // 1. The API Library (Safe to keep always)
    implementation("com.google.firebase:firebase-appdistribution-api-ktx:16.0.0-beta15")

    // 2. The Full Tester SDK (🚨 ONLY FOR FIREBASE TESTING)
    // IMPORTANT: When you are ready to upload to the Google Play Store,
    // you MUST comment out or remove this line below.
    // If you leave it in, Google Play will reject your app.
    implementation("com.google.firebase:firebase-appdistribution:16.0.0-beta17")
}