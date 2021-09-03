val repoProperty = "nixMavenRepo"

val systemRepo: Provider<String> =
    providers.systemProperty(repoProperty).forUseAtConfigurationTime()
val gradleRepo: Provider<String> =
    providers.gradleProperty(repoProperty).forUseAtConfigurationTime()
val repo: Provider<List<String>> =
    systemRepos.orElse(gradleRepos)

pluginManagement.repositories {
  if (repo.isPresent) {
    clear()
    maven(repo.get())
  }
}

dependencyResolutionManagement {
  if (repo.isPresent) {
    clear()
    maven(repo.get())
  }
}
