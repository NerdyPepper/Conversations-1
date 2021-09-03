{
  inputs = {
    utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.05";
  };

  outputs = { self, nixpkgs, utils, ... }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
        gradle = pkgs.gradle_7;
        xml-to-json = pkgs.haskellPackages.xml-to-json;
        jq = pkgs.jq;
        callPackage = pkgs.callPackage;
        writeShellScriptBin = pkgs.writeShellScriptBin;

        android = {
          versions = {
            tools = "26.1.1";
            platformTools = "31.0.2";
            buildTools = "30.0.2";
            ndk = [ "22.1.7171670" "21.3.6528147" ];
            cmake = "3.18.1";
            emulator = "30.6.3";
          };

          platforms = [ "28" "29" "30" ];
          abis = [ "armeabi-v7a" "arm64-v8a" ];
          extras = [ "extras;google;gcm" ];
        };

        androidenv = pkgs.androidenv.override {
          licenseAccepted = true;
        };
        sdk = (androidenv.composeAndroidPackages {

          toolsVersion = android.versions.tools;
          platformToolsVersion = android.versions.platformTools;
          buildToolsVersions = [ android.versions.buildTools ];
          platformVersions = android.platforms;

          includeEmulator = false;
          includeSources = false;
          includeSystemImages = false;

          systemImageTypes = [ "google_apis_playstore" ];
          abiVersions = android.abis;
          cmakeVersions = [ android.versions.cmake ];

          includeNDK = false;
          useGoogleAPIs = false;
          useGoogleTVAddOns = false;
          includeExtras = android.extras;
        }).androidsdk;

        updateLocks = writeShellScriptBin "update-locks" ''
          set -eu -o pipefail
          ${gradle}/bin/gradle --write-locks
          ${gradle}/bin/gradle --write-verification-metadata sha256 dependencies
          ${xml-to-json}/bin/xml-to-json -sam -t components gradle/verification-metadata.xml \
          | ${jq}/bin/jq '[
          .[] | .component |
          { group, name, version,
          artifacts: [([.artifact] | flatten | .[] | {(.name): .sha256.value})] | add
          }
          ]' > deps.json

          rm gradle/verification-metadata.xml
        '';

        buildMavenRepo = callPackage ./maven-repo.nix { };
        mavenRepo = buildMavenRepo {
          name = "nix-maven-repo";
          repos = [
            "https://jcenter.bintray.com"
            "https://plugins.gradle.org/m2"
            "https://raw.github.com/abdularis/libwebrtc-android/repo/"
            "https://maven.google.com"
            "https://repo1.maven.org/maven2"
          ];
          deps = builtins.fromJSON (builtins.readFile ./deps.json);
        };

        jdk = pkgs.adoptopenjdk-jre-openj9-bin-15;
      in
      rec {
        packages.conversations = pkgs.stdenv.mkDerivation {
          pname = "conversations";
          version = "0.0.0";
          src = ./.;
          nativeBuildInputs = [ gradle ];
          JDK_HOME = "${jdk.home}";

          buildPhase = ''
            runHook preBuild
            gradle --stop
            gradle assembleConversationsFreeSystemDebug \
            --offline --no-daemon --no-build-cache --info --full-stacktrace \
            --warning-mode=all --parallel --console=plain \
             -Dmaven.repo.local='file://${mavenRepo}' \
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p $out
            cp -r build/dist/* $out
            runHook postInstall
          '';

          dontStrip = true;
        };
        packages.update-locks = updateLocks;
        defaultPackage = packages.conversations;
        defaultApp = packages.conversations;
        apps = {
          "update-locks" = {
            type = "app";
            program = "${updateLocks}/bin/update-locks";
          };
        };
        devShell = pkgs.mkShell (rec {
          nativeBuildInputs = [
            sdk
            jdk
            gradle
            updateLocks
          ] ++ [
            # convinience
            pkgs.scrcpy
          ];
          ANDROID_SDK_ROOT = "${sdk}/libexec/android-sdk";
          ANDROID_HOME = "${ANDROID_SDK_ROOT}";
          JAVA_HOME = jdk.home;
          LANG = "C.UTF-8";
          LC_ALL = "C.UTF-8";
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${ANDROID_SDK_ROOT}/build-tools/${android.versions.buildTools}/aapt2";
        });
      });
}
