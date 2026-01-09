// 1. buildscript MUST be the very first block
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    // 2. This 'dependencies' opening brace was missing in your file!
    dependencies {
        // Google Services Plugin
        classpath("com.google.gms:google-services:4.4.2")
        // Android Build Tools
        classpath("com.android.tools.build:gradle:8.2.1")
        // Kotlin Plugin
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 3. Clean up build directory logic
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