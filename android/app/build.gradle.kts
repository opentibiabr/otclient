plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.github.otclient"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.github.otclient"
        minSdk = 21
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        ndk {
            // Single ABI (arm64-v8a) for release to simplify build; add others as needed
            abiFilters += listOf("arm64-v8a")
        }

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++20")

                arguments += listOf(
                    "-DVCPKG_TARGET_ANDROID=ON",
                    "-DANDROID_STL=c++_shared",
                    "-DCMAKE_TOOLCHAIN_FILE=${projectDir}/../../cmake/android-ndk-no-gold.toolchain.cmake",
                    "-DCMAKE_CXX_COMPILER=${projectDir}/../../cmake/clang-no-gold.sh",
                    "-DCMAKE_C_COMPILER=${projectDir}/../../cmake/clang-no-gold.sh",
                    "-DCMAKE_CXX_FLAGS_INIT=-fuse-ld=lld",
                    "-DCMAKE_C_FLAGS_INIT=-fuse-ld=lld",
                    "-DCMAKE_EXE_LINKER_FLAGS_INIT=-fuse-ld=lld",
                    "-DCMAKE_SHARED_LINKER_FLAGS_INIT=-fuse-ld=lld",
                    "-DCMAKE_MODULE_LINKER_FLAGS_INIT=-fuse-ld=lld",
                    "-DCMAKE_EXE_LINKER_FLAGS=-fuse-ld=lld",
                    "-DCMAKE_SHARED_LINKER_FLAGS=-fuse-ld=lld",
                    "-DCMAKE_MODULE_LINKER_FLAGS=-fuse-ld=lld"
                )
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("../../CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        // Use the existing debug signing config
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                file("proguard-rules.pro")
            )
            // Use debug signing for release builds to allow installation
            // TODO: Configure proper release signing for production
            signingConfig = signingConfigs.getByName("debug")
        }
        create("releaseSkinDebug") {
            initWith(getByName("release"))
            isDebuggable = true
            externalNativeBuild {
                cmake {
                    arguments += "-DCMAKE_BUILD_TYPE=RelWithDebInfo"
                }
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    buildFeatures {
        viewBinding = true
        prefab = true
    }

    androidResources {
        // Store data.zip uncompressed in the APK — it is already a compressed
        // zip, so re-compressing wastes build time and forces Android to
        // decompress the whole file into RAM before AAsset_read can stream it.
        noCompress += "zip"
    }

    ndkVersion = "29.0.13599879 rc2"
}

dependencies {
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.appcompat:appcompat:1.7.1")
    implementation("androidx.games:games-activity:1.2.1")
    implementation("com.google.android.material:material:1.13.0")
}