# nixearthlayer

Nix flake for [xearthlayer](https://github.com/samsoir/xearthlayer) - streaming satellite imagery for X-Plane 12 flight simulator.

## Binary Cache

Pre-built binaries are available via Cachix:

```bash
nix run nixpkgs#cachix -- use mescam
```

Or add to your NixOS configuration:

```nix
{
  nix.settings.substituters = [ "https://mescam.cachix.org" ];
  # Run 'cachix use mescam' to get the public key
}
```

## Installation

### Ad-hoc usage

```bash
nix run github:mescam/nixearthlayer
nix shell github:mescam/nixearthlayer
```

## Home Manager Module

The Home Manager module provides full declarative configuration and writes `~/.xearthlayer/config.ini`.

### Setup

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    nixearthlayer.url = "github:mescam/nixearthlayer";
  };

  outputs = { nixpkgs, home-manager, nixearthlayer, ... }: {
    homeConfigurations.pilot = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      modules = [
        nixearthlayer.homeManagerModules.default
        {
          programs.xearthlayer = {
            enable = true;
            provider.type = "bing";
          };
        }
      ];
    };
  };
}
```

### Usage

The configuration is quite complex, doing it first time might be too challenging. Consider following manual installation first and creating first config interactively as per upstream's docs. Then you can move your config to Nix. Please read the Configuration Notes below as well. 

```nix
{
  programs.xearthlayer = {
    enable = true;

    provider = {
      type = "bing";  # bing | go2 | google | apple | arcgis | mapbox | usgs
      # googleApiKey = "..."       # required for type = "google"
      # mapboxAccessToken = "..."; # required for type = "mapbox"
    };

    cache = {
      directory = "/mnt/nvme/xearthlayer-cache";
      memorySize = "4GB";
      diskSize = "100GB";
      diskIoProfile = "nvme";  # auto | hdd | ssd | nvme
      ddsDiskRatio = 0.6;      # 0.0-1.0, fraction of disk for DDS tiles
    };

    texture = {
      format = "bc1";         # bc1 (smaller) | bc3 (with alpha)
      mipmaps = 5;
      compressor = "ispc";    # software | ispc (SIMD) | gpu (wgpu compute)
      gpuDevice = "discrete"; # integrated | discrete | adapter name substring
    };

    generation = {
      threads = 4;     # worker threads for parallel tile generation
      timeout = 60;    # per-tile generation timeout (seconds)
    };

    executor = {
      maxConcurrentJobs = 32;    # max concurrent DDS tile jobs (1-256)
      networkConcurrent = 128;   # concurrent HTTP connections (64-256)
      cpuConcurrent = 4;         # concurrent CPU-bound operations
      diskIoConcurrent = 8;      # concurrent disk I/O operations
      requestTimeoutSecs = 30;   # HTTP request timeout per chunk
      maxRetries = 3;            # retry attempts per failed chunk
      retryBaseDelayMs = 500;    # base delay for exponential backoff (ms)
    };

    prefetch = {
      enable = true;
      mode = "auto";           # auto | aggressive | opportunistic | disabled
      webApiPort = 49002;      # X-Plane Web API port for telemetry (1024-65535)
      maxTilesPerCycle = 64;
      cycleIntervalMs = 1000;
      takeoffClimbFt = 800;
      rampDurationSecs = 30;
      rampStartFraction = 0.2;
      boxExtent = 10.0;
    };

    prewarm = {
      gridRows = 4;  # latitude extent in DSF tiles around airport
      gridCols = 6;  # longitude extent in DSF tiles around airport
    };

    xplane.sceneryDir = "/home/pilot/X-Plane 12/Custom Scenery";
  };
}
```

### Module options

#### `[general]` - General settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `general.updateCheck` | bool \| null | `null` | Check for new versions on startup |

#### `[provider]` - Imagery provider

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable xearthlayer |
| `package` | package | `pkgs.xearthlayer` | Package to use |
| `provider.type` | enum | `"bing"` | Satellite imagery provider (`bing`, `go2`, `google`, `apple`, `arcgis`, `mapbox`, `usgs`) |
| `provider.googleApiKey` | string \| null | `null` | Google Maps API key (required when provider is `google`) |
| `provider.mapboxAccessToken` | string \| null | `null` | MapBox access token (required when provider is `mapbox`) |

#### `[cache]` - Disk and memory cache

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cache.directory` | string \| null | `null` | Cache directory (default: `~/.cache/xearthlayer`) |
| `cache.memorySize` | string \| null | `null` | Maximum RAM for in-memory cache (e.g. `"4GB"`) |
| `cache.diskSize` | string \| null | `null` | Maximum disk space for persistent cache (e.g. `"50GB"`) |
| `cache.ddsDiskRatio` | float \| null | `null` | Fraction of `diskSize` allocated to DDS tile cache (0.0-1.0) |
| `cache.diskIoProfile` | enum \| null | `null` | Disk I/O concurrency profile (`auto`, `hdd`, `ssd`, `nvme`) |

#### `[texture]` - Texture compression

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `texture.format` | enum \| null | `null` | DDS compression format (`bc1` = smaller, `bc3` = with alpha) |
| `texture.mipmaps` | int \| null | `null` | Number of mipmap levels (1-10) |
| `texture.compressor` | enum \| null | `null` | Compression backend: `software`, `ispc` (SIMD, default), or `gpu` (wgpu compute) |
| `texture.gpuDevice` | enum \| string \| null | `null` | GPU adapter for encoding: `integrated`, `discrete`, or adapter name substring |

#### `[generation]` - Tile generation workers

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `generation.threads` | int \| null | `null` | Worker threads for parallel tile generation (default: num_cpus / 2) |
| `generation.timeout` | int \| null | `null` | Timeout in seconds for generating a single tile |

#### `[executor]` - Job execution and concurrency

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `executor.maxConcurrentJobs` | int \| null | `null` | Maximum concurrent DDS tile jobs (1-256) |
| `executor.networkConcurrent` | int \| null | `null` | Concurrent HTTP connections (64-256) |
| `executor.cpuConcurrent` | int \| null | `null` | Concurrent CPU-bound operations |
| `executor.diskIoConcurrent` | int \| null | `null` | Concurrent disk I/O operations |
| `executor.requestTimeoutSecs` | int \| null | `null` | HTTP request timeout per chunk (seconds) |
| `executor.maxRetries` | int \| null | `null` | Maximum retry attempts per failed chunk |
| `executor.retryBaseDelayMs` | int \| null | `null` | Base delay for exponential backoff (ms) |

#### `[prefetch]` - Predictive tile prefetching

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prefetch.enable` | bool \| null | `null` | Enable predictive tile prefetching |
| `prefetch.mode` | enum \| null | `null` | Prefetch mode (`auto` uses calibration, `aggressive`, `opportunistic`, `disabled`) |
| `prefetch.webApiPort` | port \| null | `null` | X-Plane Web API port for telemetry (1024-65535) |
| `prefetch.maxTilesPerCycle` | int \| null | `null` | Maximum tiles to submit per prefetch cycle |
| `prefetch.cycleIntervalMs` | int \| null | `null` | Interval between prefetch cycles (milliseconds) |
| `prefetch.calibrationAggressiveThreshold` | float \| null | `null` | Tiles/sec threshold for aggressive mode |
| `prefetch.calibrationOpportunisticThreshold` | float \| null | `null` | Tiles/sec threshold for opportunistic mode |
| `prefetch.calibrationSampleDuration` | int \| null | `null` | Duration (secs) to measure throughput during calibration |
| `prefetch.takeoffClimbFt` | float \| null | `null` | Altitude climb (ft) above takeoff MSL to release transition hold (200-5000) |
| `prefetch.takeoffTimeoutSecs` | int \| null | `null` | Maximum seconds before timeout release (30-300) |
| `prefetch.landingHysteresisSecs` | int \| null | `null` | Sustained seconds at GS < 40kt before landing detection (5-60) |
| `prefetch.rampDurationSecs` | int \| null | `null` | Duration of linear ramp to full prefetch rate (10-120) |
| `prefetch.rampStartFraction` | float \| null | `null` | Starting prefetch fraction when ramp begins (0.1-0.5) |
| `prefetch.boxExtent` | float \| null | `null` | Prefetch box extent per axis in degrees (7.0-15.0) |
| `prefetch.boxMaxBias` | float \| null | `null` | Maximum forward bias fraction (0.5-0.9) |
| `prefetch.windowBuffer` | int \| null | `null` | Extra DSF tiles around window edges to retain (0-3) |
| `prefetch.staleRegionTimeout` | int \| null | `null` | Seconds before an InProgress region is considered stale (30-600) |
| `prefetch.defaultWindowRows` | int \| null | `null` | Scenery window height in DSF rows (2-12) |
| `prefetch.windowLonExtent` | float \| null | `null` | Longitude extent in degrees for window column computation (1.0-10.0) |

#### `[prewarm]` - Airport prewarming grid

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `prewarm.gridRows` | int \| null | `null` | Latitude extent in DSF tiles around airport for prewarm |
| `prewarm.gridCols` | int \| null | `null` | Longitude extent in DSF tiles around airport for prewarm |

#### `[xplane]` - X-Plane paths

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `xplane.sceneryDir` | string \| null | `null` | X-Plane Custom Scenery directory |

#### `[logging]` - Log output

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `logging.file` | string \| null | `null` | Log file location (default: `~/.xearthlayer/xearthlayer.log`) |

#### `[packages]` - Package management

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `packages.libraryUrl` | string \| null | `null` | URL to the package library index file |
| `packages.installLocation` | string \| null | `null` | Directory for storing installed packages |
| `packages.customSceneryPath` | string \| null | `null` | X-Plane Custom Scenery directory for overlay symlinks |
| `packages.autoInstallOverlays` | bool \| null | `null` | Automatically install matching overlay when installing ortho |
| `packages.disableOverlays` | bool \| null | `null` | Suppress XEL overlays at runtime |
| `packages.tempDir` | string \| null | `null` | Temporary directory for package downloads |
| `packages.concurrentDownloads` | int \| null | `null` | Number of concurrent part downloads (1-10) |

#### `[patches]` - Tile patches

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `patches.enable` | bool \| null | `null` | Enable/disable tile patches functionality |
| `patches.directory` | string \| null | `null` | Directory containing patch tiles |

#### `[fuse]` - FUSE filesystem settings

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `fuse.maxBackground` | int \| null | `null` | Maximum pending background FUSE requests (1-1024) |
| `fuse.congestionThreshold` | int \| null | `null` | Kernel throttling threshold for pending requests (1-1024) |

### What the module does

- Installs xearthlayer to `home.packages`
- Generates `~/.xearthlayer/config.ini` with your settings

## Configuration Notes

> **\u26a0\ufe0f FUSE requirement**: xearthlayer uses FUSE to mount imagery. You must enable FUSE in your NixOS config:
> ```nix
> programs.fuse.userAllowOther = true;
> ```
> Alternatively, use `nixearthlayer.nixosModules.default` which enables FUSE automatically (and adds the package to `environment.systemPackages`).

> **\u26a0\ufe0f Upstream changes**: The xearthlayer configuration format may change between versions. This module covers common options but not all settings. If upstream adds new options or changes existing ones, you may need to configure them manually or wait for this flake to be updated.
> 
> For the full list of configuration options, see the [upstream documentation](https://github.com/samsoir/xearthlayer/blob/main/docs/configuration.md).

## Manual Installation (without Home Manager module)

If you prefer not to use the module:

```nix
{ pkgs, nixearthlayer, ... }:
{
  home.packages = [ nixearthlayer.packages.${pkgs.system}.xearthlayer ];
}
```

Then run `xearthlayer setup` to create `~/.xearthlayer/config.ini` interactively.

## Development

```bash
nix develop  # Enter dev shell with Rust toolchain
nix build    # Build the package
nix flake check  # Run checks
```

## Auto-updates

This repository includes GitHub Actions that:

1. **Daily update check**: Monitors upstream releases and creates PRs for new versions
2. **Build & cache**: Builds on push/PR and pushes to Cachix

## License

This flake is MIT licensed. xearthlayer itself is [MIT licensed](https://github.com/samsoir/xearthlayer/blob/main/LICENSE).

## Disclaimer

This is an unofficial Nix packaging of xearthlayer. I am not the author of xearthlayer and have no affiliation with the upstream project. For issues with xearthlayer itself, please refer to the [upstream repository](https://github.com/samsoir/xearthlayer).