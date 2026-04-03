{
  description = "OpenStarbound";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      overlays.default = final: prev: {
        libopus = prev.stdenv.mkDerivation rec {
          pname = "libopus";
          version = "1.5.2";
          src = prev.fetchurl {
            url = "https://downloads.xiph.org/releases/opus/opus-${version}.tar.gz";
            hash = "sha256-nMa1PBxq5LbMSBKlMFBMNFBFGsA1CKUK7pKpPCFHMM=";
          };
          nativeBuildInputs = [ prev.cmake ];
          cmakeFlags = [
            "-DOPUS_BUILD_SHARED_LIBRARY=ON"
            "-DOPUS_INSTALL_PKG_CONFIG_MODULE=ON"
            "-DOPUS_INSTALL_CMAKE_CONFIG_MODULE=ON" # nixpkgs libopus doesn't do this?
          ];
        };
      };

      packages.${system} = {
        openstarbound = pkgs.stdenv.mkDerivation {
          pname = "openstarbound";
          version = "1.4.4";

          src = pkgs.fetchFromGitHub {
            owner = "OpenStarbound";
            repo = "OpenStarbound";
            rev = "main";
            sha256 = "sha256-Sk2kHgIoBK0MgDDZyneBP9DUEkAiUdRB9a0uqrE/vqs=";
          };

          # patches = (
          #   pkgs.writeText "cmake-fixes.patch" ''
          #     --- a/source/CMakeLists.txt
          #     +++ b/source/CMakeLists.txt
          #     @@ -368,7 +368,7 @@
          #     -find_package(Opus CONFIG REQUIRED)
          #     +find_package(PkgConfig REQUIRED)
          #     +pkg_check_modules(Opus REQUIRED IMPORTED_TARGET opus)
          #     +add_library(Opus::opus ALIAS PkgConfig::Opus)
          #   ''
          # );

          nativeBuildInputs = with pkgs; [
            cmake
            ninja
            pkg-config
          ];

          buildInputs = with pkgs; [
            zlib
            zstd
            libpng
            freetype
            libvorbis
            libopus
            re2
            libcpr

            sdl3
            glew
            libsm
            libxi
            libxmu
            libGL
            libGLU
            imgui

            cpptrace

            python3Packages.jinja2
          ];

          cmakeFlags = [
            "-DSTAR_ENABLE_STEAM_INTEGRATION=OFF" # Disable Steam by default
          ];

          sourceRoot = "source/source";

          postInstall = ''
            mkdir -p $out/bin
            mkdir -p $out/share/openstarbound

            cp -r ../dist/* $out/share/openstarbound/
            cp -r ../lib/linux/*.so $out/share/openstarbound/ || true

            cp -r ../scripts/linux/sbinit.config $out/share/openstarbound/ || true

            cat > $out/bin/openstarbound << EOF
            #!/bin/sh
            cd $out/share/openstarbound
            exec ./starbound "\$@"
            EOF

            chmod +x $out/bin/openstarbound
          '';

          meta = with pkgs.lib; {
            description = "OpenStarbound - Unofficial build Starbound 1.4.4 that fixes bugs and adds features";
            homepage = "https://github.com/OpenStarbound/OpenStarbound";
            license = licenses.unfree; # Starbound is proprietary
            platforms = platforms.linux;
            maintainers = [ ];
          };
        };

        default = self.packages.${system}.openstarbound;
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs =
          with pkgs;
          [
            cmake
            ninja
            pkg-config
            gdb
          ]
          ++ self.packages.${system}.openstarbound.buildInputs;
      };
    };
}
