allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

subprojects {
    val project = this
    fun applyNamespaceFix() {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android")
            try {
                val getNamespaceMethod = android.javaClass.getMethod("getNamespace")
                if (getNamespaceMethod.invoke(android) == null) {
                    val namespaceMethod = android.javaClass.getMethod("setNamespace", String::class.java)
                    val packageName = if (project.group.toString().isNotEmpty() && project.group.toString() != "unspecified") {
                        project.group.toString()
                    } else {
                        "id.co.divine.${project.name.replace("-", "_")}"
                    }
                    namespaceMethod.invoke(android, packageName)
                    println("Fixed namespace for ${project.name} -> $packageName")
                }
            } catch (e: Exception) {
                // Fallback for older AGP or different configurations
            }
        }
    }

    if (project.state.executed) {
        applyNamespaceFix()
    } else {
        project.afterEvaluate {
            applyNamespaceFix()
        }
    }
}
