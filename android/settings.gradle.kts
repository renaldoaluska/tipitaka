pluginManagement {
    val flutterSdkPath = runCatching {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        properties.getProperty("flutter.sdk")
    }.getOrNull()

    // Load Flutter Tools
    flutterSdkPath?.let {
        includeBuild("$it/packages/flutter_tools/gradle")
    }

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    // Loader Plugin Flutter
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"

    //  VERSI DIKUNCI DI SINI (Source of Truth)
    id("com.android.application") version "8.13.2" apply false
    id("com.android.library") version "8.13.2" apply false
    id("org.jetbrains.kotlin.android") version "2.3.0" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false
}

include(":app")

// Logic Load Plugin Flutter (Standard)
val flutterProjectRoot = rootProject.projectDir.parentFile.toPath()
val plugins = java.util.Properties()
val pluginsFile = flutterProjectRoot.resolve(".flutter-plugins").toFile()
if (pluginsFile.exists()) {
    pluginsFile.inputStream().use { plugins.load(it) }
}

plugins.forEach { name, path ->
    // 👇 PERBAIKAN DI SINI: tambahin "as String"
    val pluginDirectory = flutterProjectRoot.resolve(path as String).resolve("android").toFile()
    include(":$name")
    project(":$name").projectDir = pluginDirectory
}