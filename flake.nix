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
      packages.${system} = rec {
        libopus = pkgs.stdenv.mkDerivation rec {
          pname = "libopus";
          version = "1.5.2";
          src = pkgs.fetchurl {
            url = "https://downloads.xiph.org/releases/opus/opus-${version}.tar.gz";
            hash = "sha256-ZcHS94ufL7IAgsOMvkfJUa1YOTRYduRpQWEu6H+afOE=";
          };
          nativeBuildInputs = [ pkgs.cmake ];
          cmakeFlags = [
            "-DOPUS_BUILD_SHARED_LIBRARY=ON"
            "-DOPUS_INSTALL_PKG_CONFIG_MODULE=ON"
            "-DOPUS_INSTALL_CMAKE_CONFIG_MODULE=ON" # nixpkgs libopus doesn't do this?
          ];
        };
        imgui = pkgs.imgui.overrideAttrs (final: prev: rec {
          version = "1.91.9b";
          src = pkgs.fetchFromGitHub {
            owner = "ocornut";
            repo = "imgui";
            tag = "v${version}";
            hash = "sha256-dkukDP0HD8CHC2ds0kmqy7KiGIh4148hMCyA1QF3IMo=";
          };

          propagatedBuildInputs = with pkgs; (prev.propagatedBuildInputs or []) ++ [
            sdl3
            freetype
          ];

          preBuild = ''
            addToSearchPath CMAKE_PREFIX_PATH ${pkgs.freetype.dev}
          '';

          cmakeFlags = [
            "-DIMGUI_FREETYPE=ON"
            "-DIMGUI_BUILD_SDL3_BINDING=ON"
            "-DIMGUI_BUILD_OPENGL3_BINDING=ON"
          ];

          NIX_DEBUG = 7;

          meta.broken = false; # we're unbreaking it... may need to upstream it.
        });
        openstarbound = pkgs.stdenv.mkDerivation rec {
          pname = "openstarbound";
          version = "1.4.4";

          src = pkgs.nix-gitignore.gitignoreSource [
            "cmake/FindGLEW.cmake" # causes resolution issues, not needed
          ] ./.;

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
            re2
            libcpr
            jemalloc

            sdl3
            glew
            libsm
            libxi
            libxmu
            libGL
            libGLU

            cpptrace

            python3Packages.jinja2
            
            self.packages.${system}.libopus
            self.packages.${system}.imgui
          ];

          hardeningDisable = [ "format" ];

          cmakeFlags = [
            "-S ${src}/source"
            "-DSTAR_ENABLE_STATIC_LIBGCC_LIBSTDCXX=ON"
            "-DSTAR_USE_JEMALLOC=ON"
            "-DSTAR_ENABLE_STEAM_INTEGRATION=OFF" # Disable Steam by default
          ];

          postInstall = ''
            install -D $src/dist/* $out/share/openstarbound/
            install -D $src/lib/linux/*.so $out/share/openstarbound/
            install -D $src/scripts/linux/sbinit.config $out/share/openstarbound/

            wrapProgram $out/starbound \
              --chdir $out/share/openstarbound/            
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
