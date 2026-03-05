buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Fix: Explicitly defining the Kotlin version to 2.1.0 to match the libraries
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
        
        // Essential for Google Sign-In and Firebase
        classpath("com.google.gms:google-services:4.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

plugins{
    id("com.google.gms.google-services") version "4.4.4" apply false
}
