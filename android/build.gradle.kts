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

// `flutter_blue_plus` 1.35 (la rama 1.x, la unica sin licencia comercial) compila
// su modulo Android contra `android-33`, pero sus dependencias de androidx
// (fragment 1.7, window 1.2, ...) exigen compilar contra 34 o superior, asi que
// AGP aborta el build con "checkDebugAarMetadata". Es el arreglo que recomienda
// el propio mensaje de AGP: subir el `compileSdk` de los modulos de plugin al
// mismo que usa la app (36, el valor de `flutter.compileSdkVersion` en Flutter
// 3.47). No se modifica ni el plugin ni su codigo, solo el SDK de compilacion.
subprojects {
    val applyCompileSdk = {
        val androidExtension = extensions.findByName("android")
        if (androidExtension != null) {
            try {
                androidExtension.withGroovyBuilder { "compileSdkVersion"(36) }
            } catch (error: Exception) {
                logger.warn(
                    "No se pudo fijar compileSdk 36 en $name: ${error.message}",
                )
            }
        }
    }

    // El bloque anterior ya fuerza la evaluacion de `:app`, asi que aqui hay
    // proyectos que pueden estar evaluados: `afterEvaluate` solo se registra si
    // todavia no lo estan.
    if (state.executed) {
        applyCompileSdk()
    } else {
        afterEvaluate { applyCompileSdk() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
