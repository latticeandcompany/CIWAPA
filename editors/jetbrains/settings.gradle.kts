import org.jetbrains.intellij.platform.gradle.extensions.intellijPlatform

rootProject.name = "intercal-jetbrains"

pluginManagement {
    plugins {
        id("org.jetbrains.kotlin.jvm") version "2.4.21"
    }
}

plugins {
    id("org.jetbrains.intellij.platform.settings") version "2.19.0"
}

dependencyResolutionManagement {
    repositoriesMode = RepositoriesMode.FAIL_ON_PROJECT_REPOS
    repositories {
        mavenCentral()
        intellijPlatform {
            defaultRepositories()
        }
    }
}
