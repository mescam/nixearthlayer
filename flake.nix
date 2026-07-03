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

        version = "0.4.6";
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
            hash = "sha256-Ur5SEigBqglx+jE4OwtWENWmb1hwdvr7RPrQ530hdKo=";
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
        in
        {
          options.services.xearthlayer = {
            enable = mkEnableOption "xearthlayer - streaming satellite imagery for X-Plane 12";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.xearthlayer;
              description = "The xearthlayer package to use";
            };
          };

          config = mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
            programs.fuse.userAllowOther = true;
          };
        };

      homeManagerModules.default = { config, lib, pkgs, ... }:
        with lib;
        let
          cfg = config.programs.xearthlayer;

          providerType = types.enum [ "bing" "go2" "google" "apple" "arcgis" "mapbox" "usgs" ];
          compressorType = types.enum [ "software" "ispc" "gpu" ];
          gpuDeviceType = types.enum [ "integrated" "discrete" ];
          prefetchModeType = types.enum [ "auto" "aggressive" "opportunistic" "disabled" ];

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

          configContent = generateIni {
            general = {
              update_check = cfg.general.updateCheck;
            };

            provider = {
              type = cfg.provider.type;
              google_api_key = cfg.provider.googleApiKey;
              mapbox_access_token = cfg.provider.mapboxAccessToken;
            };

            cache = {
              directory = cfg.cache.directory;
              memory_size = cfg.cache.memorySize;
              disk_size = cfg.cache.diskSize;
              dds_disk_ratio = cfg.cache.ddsDiskRatio;
              disk_io_profile = cfg.cache.diskIoProfile;
            };

            texture = {
              format = cfg.texture.format;
              mipmaps = cfg.texture.mipmaps;
              compressor = cfg.texture.compressor;
              gpu_device = cfg.texture.gpuDevice;
            };

            generation = {
              threads = cfg.generation.threads;
              timeout = cfg.generation.timeout;
            };

            executor = {
              max_concurrent_jobs = cfg.executor.maxConcurrentJobs;
              network_concurrent = cfg.executor.networkConcurrent;
              cpu_concurrent = cfg.executor.cpuConcurrent;
              disk_io_concurrent = cfg.executor.diskIoConcurrent;
              request_timeout_secs = cfg.executor.requestTimeoutSecs;
              max_retries = cfg.executor.maxRetries;
              retry_base_delay_ms = cfg.executor.retryBaseDelayMs;
            };

            prefetch = {
              enabled = cfg.prefetch.enable;
              mode = cfg.prefetch.mode;
              web_api_port = cfg.prefetch.webApiPort;
              max_tiles_per_cycle = cfg.prefetch.maxTilesPerCycle;
              cycle_interval_ms = cfg.prefetch.cycleIntervalMs;
              calibration_aggressive_threshold = cfg.prefetch.calibrationAggressiveThreshold;
              calibration_opportunistic_threshold = cfg.prefetch.calibrationOpportunisticThreshold;
              calibration_sample_duration = cfg.prefetch.calibrationSampleDuration;
              takeoff_climb_ft = cfg.prefetch.takeoffClimbFt;
              takeoff_timeout_secs = cfg.prefetch.takeoffTimeoutSecs;
              landing_hysteresis_secs = cfg.prefetch.landingHysteresisSecs;
              ramp_duration_secs = cfg.prefetch.rampDurationSecs;
              ramp_start_fraction = cfg.prefetch.rampStartFraction;
              box_extent = cfg.prefetch.boxExtent;
              box_max_bias = cfg.prefetch.boxMaxBias;
              window_buffer = cfg.prefetch.windowBuffer;
              stale_region_timeout = cfg.prefetch.staleRegionTimeout;
              default_window_rows = cfg.prefetch.defaultWindowRows;
              window_lon_extent = cfg.prefetch.windowLonExtent;
            };

            prewarm = {
              grid_rows = cfg.prewarm.gridRows;
              grid_cols = cfg.prewarm.gridCols;
            };

            xplane = {
              scenery_dir = cfg.xplane.sceneryDir;
            };

            logging = {
              file = cfg.logging.file;
            };

            packages = {
              library_url = cfg.packages.libraryUrl;
              install_location = cfg.packages.installLocation;
              custom_scenery_path = cfg.packages.customSceneryPath;
              auto_install_overlays = cfg.packages.autoInstallOverlays;
              disable_overlays = cfg.packages.disableOverlays;
              temp_dir = cfg.packages.tempDir;
              concurrent_downloads = cfg.packages.concurrentDownloads;
            };

            patches = {
              enabled = cfg.patches.enable;
              directory = cfg.patches.directory;
            };

            fuse = {
              max_background = cfg.fuse.maxBackground;
              congestion_threshold = cfg.fuse.congestionThreshold;
            };
          };
        in
        {
          options.programs.xearthlayer = {
            enable = mkEnableOption "xearthlayer - streaming satellite imagery for X-Plane 12";

            package = mkOption {
              type = types.package;
              default = self.packages.${pkgs.system}.xearthlayer;
              description = "The xearthlayer package to use";
            };

            # ── [general] ──────────────────────────────────────────────
            general = {
              updateCheck = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = "Check for new versions on startup";
              };
            };

            # ── [provider] ─────────────────────────────────────────────
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

            # ── [cache] ────────────────────────────────────────────────
            cache = {
              directory = mkOption {
                type = types.nullOr types.str;
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

              ddsDiskRatio = mkOption {
                type = types.nullOr types.float;
                default = null;
                example = 0.6;
                description = "Fraction of disk_size allocated to DDS tile cache (0.0-1.0)";
              };

              diskIoProfile = mkOption {
                type = types.nullOr (types.enum [ "auto" "hdd" "ssd" "nvme" ]);
                default = null;
                description = "Disk I/O concurrency profile";
              };
            };

            # ── [texture] ──────────────────────────────────────────────
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

              compressor = mkOption {
                type = types.nullOr compressorType;
                default = null;
                description = "Compression backend: software, ispc (SIMD, default), or gpu (wgpu compute)";
              };

              gpuDevice = mkOption {
                type = types.nullOr (types.either gpuDeviceType types.str);
                default = null;
                example = "Radeon";
                description = "GPU adapter for encoding: 'integrated', 'discrete', or adapter name substring";
              };
            };

            # ── [generation] ───────────────────────────────────────────
            generation = {
              threads = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Worker threads for parallel tile generation (default: num_cpus / 2)";
              };

              timeout = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Timeout in seconds for generating a single tile";
              };
            };

            # ── [executor] ─────────────────────────────────────────────
            executor = {
              maxConcurrentJobs = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Maximum concurrent DDS tile jobs (1-256)";
              };

              networkConcurrent = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Concurrent HTTP connections (64-256)";
              };

              cpuConcurrent = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Concurrent CPU-bound operations";
              };

              diskIoConcurrent = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Concurrent disk I/O operations";
              };

              requestTimeoutSecs = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "HTTP request timeout per chunk (seconds)";
              };

              maxRetries = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Maximum retry attempts per failed chunk";
              };

              retryBaseDelayMs = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Base delay for exponential backoff (ms)";
              };
            };

            # ── [prefetch] ─────────────────────────────────────────────
            prefetch = {
              enable = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = "Enable predictive tile prefetching";
              };

              mode = mkOption {
                type = types.nullOr prefetchModeType;
                default = null;
                description = "Prefetch mode (auto uses calibration)";
              };

              webApiPort = mkOption {
                type = types.nullOr types.port;
                default = null;
                description = "X-Plane Web API port for telemetry (1024-65535)";
              };

              maxTilesPerCycle = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Maximum tiles to submit per prefetch cycle";
              };

              cycleIntervalMs = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Interval between prefetch cycles (milliseconds)";
              };

              calibrationAggressiveThreshold = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Tiles/sec threshold for aggressive mode";
              };

              calibrationOpportunisticThreshold = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Tiles/sec threshold for opportunistic mode";
              };

              calibrationSampleDuration = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Duration (secs) to measure throughput during calibration";
              };

              takeoffClimbFt = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Altitude climb (ft) above takeoff MSL to release transition hold (200-5000)";
              };

              takeoffTimeoutSecs = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Maximum seconds before timeout release (30-300)";
              };

              landingHysteresisSecs = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Sustained seconds at GS < 40kt before landing detection (5-60)";
              };

              rampDurationSecs = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Duration of linear ramp to full prefetch rate (10-120)";
              };

              rampStartFraction = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Starting prefetch fraction when ramp begins (0.1-0.5)";
              };

              boxExtent = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Prefetch box extent per axis in degrees (7.0-15.0)";
              };

              boxMaxBias = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Maximum forward bias fraction (0.5-0.9)";
              };

              windowBuffer = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Extra DSF tiles around window edges to retain (0-3)";
              };

              staleRegionTimeout = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Seconds before an InProgress region is considered stale (30-600)";
              };

              defaultWindowRows = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Scenery window height in DSF rows (2-12)";
              };

              windowLonExtent = mkOption {
                type = types.nullOr types.float;
                default = null;
                description = "Longitude extent in degrees for window column computation (1.0-10.0)";
              };
            };

            # ── [prewarm] ──────────────────────────────────────────────
            prewarm = {
              gridRows = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Latitude extent in DSF tiles around airport for prewarm";
              };

              gridCols = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Longitude extent in DSF tiles around airport for prewarm";
              };
            };

            # ── [xplane] ───────────────────────────────────────────────
            xplane = {
              sceneryDir = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "X-Plane Custom Scenery directory";
              };
            };

            # ── [logging] ──────────────────────────────────────────────
            logging = {
              file = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Log file location (default: ~/.xearthlayer/xearthlayer.log)";
              };
            };

            # ── [packages] ─────────────────────────────────────────────
            packages = {
              libraryUrl = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "URL to the package library index file";
              };

              installLocation = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Directory for storing installed packages";
              };

              customSceneryPath = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "X-Plane Custom Scenery directory for overlay symlinks";
              };

              autoInstallOverlays = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = "Automatically install matching overlay when installing ortho";
              };

              disableOverlays = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = "Suppress XEL overlays at runtime";
              };

              tempDir = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Temporary directory for package downloads";
              };

              concurrentDownloads = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Number of concurrent part downloads (1-10)";
              };
            };

            # ── [patches] ──────────────────────────────────────────────
            patches = {
              enable = mkOption {
                type = types.nullOr types.bool;
                default = null;
                description = "Enable/disable tile patches functionality";
              };

              directory = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Directory containing patch tiles";
              };
            };

            # ── [fuse] ─────────────────────────────────────────────────
            fuse = {
              maxBackground = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Maximum pending background FUSE requests (1-1024)";
              };

              congestionThreshold = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Kernel throttling threshold for pending requests (1-1024)";
              };
            };
          };

          config = mkIf cfg.enable {
            home.packages = [ cfg.package ];

            home.file.".xearthlayer/config.ini".text = configContent;
          };
        };
    };
}
