import org.jetbrains.intellij.platform.gradle.IntelliJPlatformType
import org.jetbrains.intellij.platform.gradle.TestFrameworkType
import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.dsl.KotlinVersion

plugins {
    id("org.jetbrains.kotlin.jvm")
    id("org.jetbrains.intellij.platform")
}

kotlin {
    jvmToolchain(21)
    compilerOptions {
        jvmTarget = JvmTarget.JVM_21
        // 2026.1 bundles the 2.3 standard library, and the plugin runs on whatever the IDE bundles.
        apiVersion = KotlinVersion.KOTLIN_2_3
        languageVersion = KotlinVersion.KOTLIN_2_3
        allWarningsAsErrors = true
    }
}

dependencies {
    intellijPlatform {
        intellijIdea("2026.1")
        testFramework(TestFrameworkType.Platform)
    }
    testImplementation("junit:junit:4.13.2")
}

intellijPlatform {
    pluginConfiguration {
        ideaVersion {
            sinceBuild = "261"
            untilBuild = provider { null }
        }
    }
    pluginVerification {
        ides {
            current()
            create(IntelliJPlatformType.IntellijIdea, "2026.2.4")
        }
    }
    buildSearchableOptions = false
}

// The smoke test's server: build it before running `test` (see the Lattice test script), or pass -PintercalServer=<path>.
val server = providers.gradleProperty("intercalServer")
    .orElse(layout.projectDirectory.file("../../.cache/build/ciwapa-llvm").asFile.absolutePath)

tasks.test {
    systemProperty("intercal.server", server.get())
}

// Q179: the plugin ships in the compilers' release, with the compilers' version.
val checkVersionLockstep = tasks.register("checkVersionLockstep") {
    group = "verification"
    description = "Checks that the plugin's version is the version in packages/ciwapa_llvm/pubspec.yaml."
    val pubspec = layout.projectDirectory.file("../../packages/ciwapa_llvm/pubspec.yaml").asFile
    val pluginVersion = project.version.toString()
    inputs.file(pubspec)
    inputs.property("pluginVersion", pluginVersion)
    doLast {
        val compilers = pubspec.readLines().first { it.startsWith("version:") }.removePrefix("version:").trim()
        check(compilers == pluginVersion) {
            "The plugin is version $pluginVersion but the compilers are version $compilers. Change `version` in gradle.properties."
        }
    }
}

tasks.check { dependsOn(checkVersionLockstep) }
tasks.buildPlugin { dependsOn(checkVersionLockstep) }

tasks.register("lint") {
    group = "verification"
    description = "Compiles with warnings as errors, checks the version, and runs the plugin verifier."
    dependsOn(
        checkVersionLockstep,
        tasks.compileKotlin,
        tasks.compileTestKotlin,
        tasks.verifyPluginProjectConfiguration,
        tasks.verifyPluginStructure,
        tasks.verifyPlugin,
    )
}
