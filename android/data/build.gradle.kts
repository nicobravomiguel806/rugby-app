// Data → :domain. Implementa los puertos de Domain. Sin Hilt: los módulos de DI viven en :app (ADR 0005).
// supabase-kt y Room llegan en SP-04 / C-01.
plugins {
    alias(libs.plugins.android.library)
    alias(libs.plugins.kotlin.android)
}

android {
    namespace = "mx.rugbyapp.data"
    compileSdk = 35
    defaultConfig { minSdk = 29 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin { jvmToolchain(17) }

dependencies {
    implementation(project(":domain"))
    testImplementation(libs.junit)
}
