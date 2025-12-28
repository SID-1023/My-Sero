buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Modern Gradle & Kotlin versions
        classpath("com.android.tools.build:gradle:8.2.1")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:1.9.22")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Ensure the build directory is in the standard Flutter location
val rootBuildDir = layout.projectDirectory.dir("../build")
rootProject.layout.buildDirectory.value(rootBuildDir)

subprojects {
    val subprojectBuildDir = rootBuildDir.dir(project.name)
    project.layout.buildDirectory.value(subprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    // Apply fixes lazily as plugins are loaded
    plugins.withType<com.android.build.gradle.BasePlugin> {
        val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
        
        // 1. Set Namespace (Required for Gradle 8+)
        if (android.namespace == null) {
            android.namespace = project.group.toString()
        }

        // 2. Automate the removal of legacy 'package' attribute from old plugins
        project.tasks.matching { it.name.contains("Manifest") }.configureEach {
            doFirst {
                val manifestFile = file("${project.projectDir}/src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    var content = manifestFile.readText()
                    if (content.contains("package=")) {
                        println("Sero Build: Auto-fixing manifest for ${project.name}")
                        content = content.replace(Regex("package=\"[^\"]*\""), "")
                        manifestFile.writeText(content)
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}