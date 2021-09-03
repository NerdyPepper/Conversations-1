{ gradleGen, fetchurl }:

gradleGen rec {
  name = "gradle-7.0-milestone-2";
  nativeVersion = "0.22-milestone-10";
  src = fetchurl {
    url = "https://services.gradle.org/distributions/${name}-bin.zip";
    sha256 = "10a2zhr7yhj7a9pi2rn1jaqdf1nxnxxpljvfnnz0v3il4p6v2wd9";
  };
}
