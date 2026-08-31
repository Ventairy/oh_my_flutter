import java.nio.charset.StandardCharsets
import java.security.MessageDigest

plugins {
    id("com.android.application")
}

val collectorRoot = rootProject.projectDir
val collectorSourceManifest = collectorRoot.resolve("source_manifest.txt")
val collectorSourcePaths = collectorSourceManifest.readLines()
    .map(String::trim)
    .filter(String::isNotEmpty)
require(collectorSourcePaths == collectorSourcePaths.sorted()) {
    "Collector source manifest must be sorted."
}
require(collectorSourcePaths.size == collectorSourcePaths.toSet().size) {
    "Collector source manifest paths must be unique."
}
require(collectorSourcePaths.none { path ->
    path.startsWith("/") ||
        path.contains("\\") ||
        path.split("/").any { segment -> segment.isEmpty() || segment == "." || segment == ".." }
}) {
    "Collector source manifest paths must be safe and relative."
}
val expectedCollectorPaths = (listOf("source_manifest.txt") + collectorSourcePaths).toSet()
val actualCollectorPaths = collectorRoot.walkTopDown()
    .filter(File::isFile)
    .map { file -> file.relativeTo(collectorRoot).invariantSeparatorsPath }
    .filter { path ->
        path == "source_manifest.txt" ||
            path == "build.gradle.kts" ||
            path == "settings.gradle.kts" ||
            path == "protocol.json" ||
            path == "app/build.gradle.kts" ||
            path.startsWith("app/src/")
    }
    .toSet()
require(actualCollectorPaths == expectedCollectorPaths) {
    "Collector source manifest does not match the canonical source tree."
}
val collectorSourceFiles = listOf(collectorSourceManifest) +
    collectorSourcePaths.map(collectorRoot::resolve)
val collectorDigest = MessageDigest.getInstance("SHA-256")
for (file in collectorSourceFiles) {
    collectorDigest.update(
        file.relativeTo(collectorRoot).invariantSeparatorsPath.toByteArray(
            StandardCharsets.UTF_8,
        ),
    )
    collectorDigest.update(0.toByte())
    collectorDigest.update(file.readBytes())
    collectorDigest.update(0.toByte())
}
val collectorSourceHash = "sha256:" + collectorDigest.digest().joinToString("") {
    byte -> "%02x".format(byte.toInt() and 0xff)
}

android {
    namespace = "dev.ventairy.oh_my_flutter.device_display_model_collector"
    compileSdk = 36

    defaultConfig {
        applicationId = "dev.ventairy.oh_my_flutter.device_display_model_collector"
        minSdk = 24
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        buildConfigField("String", "COLLECTOR_SOURCE_HASH", "\"$collectorSourceHash\"")
    }

    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}
