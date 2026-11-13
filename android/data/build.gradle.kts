// Data → :domain. Implementa los puertos de Domain. Sin Hilt: los módulos de DI viven en :app (ADR 0005).
// SP-04: supabase-kt (Auth) y el almacén cifrado de la sesión (ADR 0007).
// C-01: postgrest-kt para el consentimiento del aviso, en el mismo cliente que Auth (ADR 0006).
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
    // Las pruebas unitarias crean el cliente de Supabase en la JVM; los métodos de android.jar devuelven valores por defecto.
    testOptions { unitTests.isReturnDefaultValues = true }
}

kotlin { jvmToolchain(17) }

dependencies {
    implementation(project(":domain"))
    // api: AlmacenDeSesionCifrado implementa SessionManager de supabase-kt y :app lo construye.
    api(libs.supabase.auth)
    implementation(libs.supabase.postgrest)
    implementation(libs.ktor.client.okhttp)
    implementation(libs.datastore.preferences)
    implementation(libs.tink.android)

    testImplementation(libs.junit)
    testImplementation(libs.ktor.client.mock)
    testImplementation(libs.kotlinx.coroutines.test)
}
