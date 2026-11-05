// Domain: Kotlin puro. Sin Android SDK, sin Supabase, sin Room (RNF-03).
// Es un módulo JVM: si alguien importa android.* aquí, la compilación falla (CP-001 / CP-100).
plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin { jvmToolchain(17) }

dependencies {
    testImplementation(libs.junit)
}
