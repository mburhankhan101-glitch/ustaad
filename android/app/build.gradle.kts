import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Load signing keys from key.properties ─────────────────────────────────
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.ustaad.app"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // flutter_local_notifications needs the java.time APIs on older
        // Android versions, and refuses to build without this — the error is
        // "requires core library desugaring to be enabled", from
        // checkDebugAarMetadata rather than from anything in our code.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    signingConfigs {
        create("release") {
            keyAlias     = keystoreProperties["keyAlias"].toString()
            keyPassword  = keystoreProperties["keyPassword"].toString()
            storeFile    = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"].toString()
        }
    }

    defaultConfig {
        applicationId = "com.ustaad.app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // The back-ported java.time implementation the line above switches on.
    // 2.1.4 is the version flutter_local_notifications documents; moving it
    // is a thing to do deliberately, not incidentally.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
