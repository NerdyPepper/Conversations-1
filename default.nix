{ pkgs ? import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/refs/tags/21.05.tar.gz") { } }:

with pkgs;

lib.makeScope newScope (self: with self; {
  gradle = pkgs.gradle_7;

  updateLocks = callPackage ./update-locks.nix {
    inherit (haskellPackages) xml-to-json;
  };

  buildMavenRepo = callPackage ./maven-repo.nix { };

  mavenRepo = buildMavenRepo {
    name = "nix-maven-repo";
    repos = [
      "https://plugins.gradle.org/m2"
      "https://repo1.maven.org/maven2"
    ];
    deps = builtins.fromJSON (builtins.readFile ./deps.json);
  };

  builtWithGradle = callPackage ./build.nix { };
})
