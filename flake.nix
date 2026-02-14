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
          cfg = config.services.xearthlayer;

          providerType = types.enum [ "bing" "go2" "google" "apple" "arcgis" "mapbox" "usgs" ];
          
          formatIniValue = v:
            if builtins.isBool v then (if v then "true" else "false")
            else toString v;

          generateIni = settings:
            let
              formatSection = name: attrs:
                let
                  nonNullAttrs = filterAttrs (n: v: v != null) attrs;
                  lines = mapAttrsToList (k: v: "${k} = ${formatIniValue v}") nonNullAttrs;
                in
                if nonNullAttrs == {} then ""
                else "[${name}]\n${concatStringsSep "\n" lines}\n";
            in
            concatStringsSep "\n" (filter (s: s != "") (mapAttrsToList formatSection settings));

          configFile = pkgs.writeText "xearthlayer-config.ini" (generateIni {
            provider = {
              type = cfg.provider.type;
              google_api_key = cfg.provider.googleApiKey;
              mapbox_access_token = cfg.provider.mapboxAccessToken;
            };
            cache = {
              directory = cfg.cache.directory;
              memory_size = cfg.cache.memorySize;
              disk_size = cfg.cache.diskSize;
              disk_io_profile = cfg.cache.diskIoProfile;
            };
            texture = {
              format = cfg.texture.format;
              mipmaps = cfg.texture.mipmaps;
            };
            prefetch = {
              enabled = cfg.prefetch.enable;
              mode = cfg.prefetch.mode;
              udp_port = cfg.prefetch.udpPort;
            };
            xplane = {
              scenery_dir = cfg.xplane.sceneryDir;
            };
          });
        in
        {
          options.services.xearthlayer = {
            enable = mkEnableOption "xearthlayer - streaming satellite imagery for X-Plane 12";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.xearthlayer;
              description = "The xearthlayer package to use";
            };

            provider = {
              type = mkOption {
                type = providerType;
                default = "bing";
                description = "Satellite imagery provider";
              };

              googleApiKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Google Maps API key (required when provider is 'google')";
              };

              mapboxAccessToken = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "MapBox access token (required when provider is 'mapbox')";
              };
            };

            cache = {
              directory = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "Cache directory (default: ~/.cache/xearthlayer)";
              };

              memorySize = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "4GB";
                description = "Maximum RAM for in-memory cache";
              };

              diskSize = mkOption {
                type = types.nullOr types.str;
                default = null;
                example = "50GB";
                description = "Maximum disk space for persistent cache";
              };

              diskIoProfile = mkOption {
                type = types.nullOr (types.enum [ "auto" "hdd" "ssd" "nvme" ]);
                default = null;
                description = "Disk I/O concurrency profile";
              };
            };

            texture = {
              format = mkOption {
                type = types.nullOr (types.enum [ "bc1" "bc3" ]);
                default = null;
                description = "DDS compression format (bc1 = smaller, bc3 = with alpha)";
              };

              mipmaps = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Number of mipmap levels (1-10)";
              };
            };

            prefetch = {
              enable = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = "Enable predictive tile prefetching";
              };

              mode = mkOption {
                type = types.nullOr (types.enum [ "auto" "aggressive" "opportunistic" "disabled" ]);
                default = null;
                description = "Prefetch mode";
              };

              udpPort = mkOption {
                type = types.nullOr types.port;
                default = null;
                description = "UDP port for X-Plane telemetry";
              };
            };

            xplane = {
              sceneryDir = mkOption {
                type = types.nullOr types.path;
                default = null;
                description = "X-Plane Custom Scenery directory";
              };
            };

            configFile = mkOption {
              type = types.path;
              default = configFile;
              description = "Generated config file path (read-only)";
              readOnly = true;
            };

            users = mkOption {
              type = types.listOf types.str;
              default = [];
              example = [ "pilot" "jane" ];
              description = ''
                List of users for whom to create the config symlink.
                Creates ~/.xearthlayer/config.ini -> /etc/xearthlayer/config.ini
              '';
            };
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
            programs.fuse.userAllowOther = true;

            environment.etc."xearthlayer/config.ini".source = cfg.configFile;

            system.activationScripts.xearthlayer-config = lib.stringAfter [ "users" ] ''
              ${concatMapStringsSep "\n" (user: 
                let
                  home = config.users.users.${user}.home;
                in ''
                  mkdir -p "${home}/.xearthlayer"
                  chown ${user}:${config.users.users.${user}.group} "${home}/.xearthlayer"
                  ln -sf /etc/xearthlayer/config.ini "${home}/.xearthlayer/config.ini"
                ''
              ) cfg.users}
            '';
          };
        };
    };
}
