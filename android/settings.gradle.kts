pluginManagement {
    repositories { gradlePluginPortal(); google(); mavenCentral() }
}
dependencyResolutionManagement {
    repositories { google(); mavenCentral() }
}
rootProject.name = "rugby-app-android"

// :domain es Kotlin puro (módulo JVM). :data, :presentation y :app se crean en AN-T-03.
include(":domain")
