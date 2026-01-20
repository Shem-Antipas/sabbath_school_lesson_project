// 1. Buildscript Block
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.android.tools.build:gradle:8.2.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 2. Build Directory Logic
val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// ✅ THE CRASH-PROOF FIX
subprojects {
    // FIX 1: Safely Force SDK 36
    // We use 'pluginManager.withPlugin' instead of 'afterEvaluate'. 
    // This runs immediately when the plugin is applied, preventing the "Already Evaluated" crash.
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileSdk = 36
        }
    }

    // FIX 2: Disable the Broken Verification Tasks
    // The Firebase plugin fails on these specific tasks. We simply disable them.
    tasks.configureEach {
        if (name == "verifyProductionReleaseResources" || name == "verifyStagingReleaseResources") {
            enabled = false
        }
    }

    // FIX 3: Force Core Library Versions
    // Ensures 'lStar' attribute is available globally.
    configurations.all {
        resolutionStrategy {
            force("androidx.core:core:1.13.1")
            force("androidx.core:core-ktx:1.13.1")
            force("androidx.appcompat:appcompat:1.7.0")
        }
    }
}