allprojects {
    repositories {
        google()
        mavenCentral()
        // DEVELOPMENT ONLY: dev.useunion:union is not on Maven Central yet. Publish it first with
        //   cd ../union-android && ./gradlew :union:publishToMavenLocal
        // Remove this line once 0.1.0 is released.
        mavenLocal()
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
