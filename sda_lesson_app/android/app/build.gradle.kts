plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "adventist.study.hub"
    
    // ✅ SDK 36 required
    compileSdk = 36 
    
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
        
        // ✅ Target 35 is safe/stable for Play Store
        targetSdk = 35 
        
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

dependencies {
    implementation("com.google.firebase:firebase-appdistribution-api-ktx:16.0.0-beta15")
    
    // 🚨 Uncomment this ONLY for testing distribution, comment out for Play Store
    implementation("com.google.firebase:firebase-appdistribution:16.0.0-beta17")
}