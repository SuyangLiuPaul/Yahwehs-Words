import java.util.Properties

val wearSigning = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) file.inputStream().use { load(it) }
}
val phoneVersion = rootProject.file("../pubspec.yaml").readLines()
    .first { it.startsWith("version:") }.substringAfter(":").trim().substringBefore("+")
val phoneParts = phoneVersion.split(".").map { it.toInt() }

plugins { id("com.android.application"); id("kotlin-android") }
android {
    namespace = "com.example.yswords.wear"
    compileSdk = 36
    defaultConfig {
        applicationId = (project.findProperty("playAppId") as String?) ?: "com.example.yswords"
        minSdk = 30
        targetSdk = 36
        // Dedicated Play form factors share a package but require distinct
        // version codes. Reserve a separate range without changing the ID.
        versionCode = (project.findProperty("wearVersionCode") as String?)?.toInt() ?: (20_000_000 + phoneParts[0] * 1_000_000 + phoneParts[1] * 10_000 + phoneParts[2])
        versionName = (project.findProperty("wearVersionName") as String?) ?: phoneVersion
    }
    signingConfigs {
        if (wearSigning.getProperty("storeFile") != null) {
            create("release") {
                storeFile = file(wearSigning.getProperty("storeFile"))
                storePassword = wearSigning.getProperty("storePassword")
                keyAlias = wearSigning.getProperty("keyAlias")
                keyPassword = wearSigning.getProperty("keyPassword")
            }
        }
    }
    buildTypes { release { signingConfig = signingConfigs.findByName("release") } }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_11; targetCompatibility = JavaVersion.VERSION_11 }
    kotlinOptions { jvmTarget = "11" }
}
gradle.taskGraph.whenReady {
    if (allTasks.any { it.project == project && it.name.contains("Release") } &&
        wearSigning.getProperty("storeFile") == null) {
        throw GradleException("Wear release requires the phone release signing key; debug fallback is not distributable.")
    }
}
dependencies { implementation("com.google.android.gms:play-services-wearable:19.0.0") }
