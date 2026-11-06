// App: composición, inyección (Hilt) y navegación. Es el único módulo que conoce todas las capas.
import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.kotlin.android)
    alias(libs.plugins.kotlin.compose)
    alias(libs.plugins.ksp)
    alias(libs.plugins.hilt)
}

// SP-04 · Llaves locales en android/local.properties (ignorado por git; no hay archivo de ejemplo versionado):
//   SUPABASE_URL=https://<proyecto>.supabase.co
//   SUPABASE_ANON_KEY=<llave anon/publishable; nunca la service_role>
//   GOOGLE_WEB_CLIENT_ID=<client id Web de Google Cloud, el que valida Supabase>
// Si faltan (CI, clon nuevo) quedan vacías: la app compila y arranca, y Acceso muestra «Configuración de Supabase incompleta».
val llavesLocales = Properties().apply {
    rootProject.file("local.properties").takeIf { it.isFile }?.inputStream()?.use { load(it) }
}
fun llaveLocal(nombre: String): String =
    (llavesLocales.getProperty(nombre) ?: "").trim().replace("\\", "").replace("\"", "")

android {
    namespace = "mx.rugbyapp.app"
    compileSdk = 35

    defaultConfig {
        // Id PROVISIONAL (ADR 0004): se define solo en gradle.properties.
        applicationId = providers.gradleProperty("rugbyapp.applicationId").get()
        minSdk = 29 // RNF-07: Android 10
        targetSdk = 35
        versionCode = 1
        versionName = "0.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        buildConfigField("String", "SUPABASE_URL", "\"${llaveLocal("SUPABASE_URL")}\"")
        buildConfigField("String", "SUPABASE_ANON_KEY", "\"${llaveLocal("SUPABASE_ANON_KEY")}\"")
        buildConfigField("String", "GOOGLE_WEB_CLIENT_ID", "\"${llaveLocal("GOOGLE_WEB_CLIENT_ID")}\"")
    }

    buildFeatures {
        compose = true
        buildConfig = true
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin { jvmToolchain(17) }

dependencies {
    implementation(project(":domain"))
    implementation(project(":data"))
    implementation(project(":presentation"))

    implementation(libs.hilt.android)
    ksp(libs.hilt.compiler)

    implementation(platform(libs.compose.bom))
    implementation(libs.compose.ui)
    implementation(libs.compose.material3)
    implementation(libs.activity.compose)
    implementation(libs.navigation.compose)
    implementation(libs.lifecycle.viewmodel.compose)

    // SP-04 · Inicio con Google por Credential Manager (ADR 0006). Versiones exactas (AT-16).
    implementation(libs.credentials)
    implementation(libs.credentials.play.services.auth)
    implementation(libs.googleid)

    androidTestImplementation(platform(libs.compose.bom))
    androidTestImplementation(libs.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.runner)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.espresso.core)
    debugImplementation(libs.compose.ui.test.manifest)
}
