{
  description = "Nix flake for xearthlayer - streaming satellite imagery for X-Plane 12";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils, rust-overlay }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        version = "0.3.0";
        rev = "v${version}";

        rustPlatform = pkgs.makeRustPlatform {
          cargo = pkgs.rust-bin.stable.latest.minimal;
          rustc = pkgs.rust-bin.stable.latest.minimal;
        };

        xearthlayer = rustPlatform.buildRustPackage {
          pname = "xearthlayer";
          inherit version;

          src = pkgs.fetchFromGitHub {
            owner = "samsoir";
            repo = "xearthlayer";
            rev = rev;
            hash = "sha256-ZNYiSKlf11MV9ivnk28KUbGgarnehx+Si3pGHs5JgGY=";
          };

          cargoLock = {
            lockFile = "${xearthlayer.src}/Cargo.lock";
            allowBuiltinFetchGit = true;
          };

          nativeBuildInputs = with pkgs; [
            pkg-config
          ];

          buildInputs = with pkgs; [
            fuse3
            openssl
          ];

          # The binary is built from xearthlayer-cli
          cargoBuildFlags = [ "-p" "xearthlayer-cli" ];
          cargoTestFlags = [ "-p" "xearthlayer-cli" "-p" "xearthlayer" ];

          meta = with pkgs.lib; {
            description = "High-quality satellite imagery for X-Plane, streamed on demand";
            homepage = "https://github.com/samsoir/xearthlayer";
            license = licenses.mit;
            platforms = platforms.linux;
            mainProgram = "xearthlayer";
          };
        };
      in
      {
        packages = {
          default = xearthlayer;
          xearthlayer = xearthlayer;
        };

        apps.default = flake-utils.lib.mkApp {
          drv = xearthlayer;
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rust-bin.stable.latest.default
            pkg-config
            fuse3
            openssl
          ];
        };
      }
    ) // {
      overlays.default = final: prev: {
        xearthlayer = self.packages.${prev.system}.xearthlayer;
      };

      nixosModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.xearthlayer;
        in
        {
          options.programs.xearthlayer = {
            enable = mkEnableOption "xearthlayer - satellite imagery for X-Plane";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.xearthlayer;
              description = "The xearthlayer package to use";
            };
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];

            # FUSE is required for xearthlayer
            programs.fuse.userAllowOther = true;
          };
        };
    };
}
