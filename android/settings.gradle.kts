pluginManagement {
    repositories { gradlePluginPortal(); google(); mavenCentral() }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
rootProject.name = "rugby-app-android"

// Mismos nombres de capa que iOS (CP-100): Domain, Data, Presentation y la App que compone todo.
include(":domain")       // Kotlin JVM puro: sin Android SDK ni Supabase
include(":data")         // → :domain
include(":presentation") // → :domain (nunca → :data)
include(":app")          // → todas; composición e inyección con Hilt
