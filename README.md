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

## Home Manager Module (Recommended)

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

### Basic usage

```nix
{
  programs.xearthlayer = {
    enable = true;
    provider.type = "bing";
  };
}
```

### Full example

```nix
{
  programs.xearthlayer = {
    enable = true;

    provider = {
      type = "bing";  # bing | go2 | google | apple | arcgis | mapbox | usgs
      # googleApiKey = "...";       # required for type = "google"
      # mapboxAccessToken = "...";  # required for type = "mapbox"
    };

    cache = {
      directory = "/mnt/nvme/xearthlayer-cache";
      memorySize = "4GB";
      diskSize = "100GB";
      diskIoProfile = "nvme";  # auto | hdd | ssd | nvme
    };

    texture = {
      format = "bc1";  # bc1 (smaller) | bc3 (with alpha)
      mipmaps = 5;
    };

    prefetch = {
      enable = true;
      mode = "auto";  # auto | aggressive | opportunistic | disabled
      udpPort = 49002;
    };

    xplane.sceneryDir = "/home/pilot/X-Plane 12/Custom Scenery";
  };
}
```

### Module options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | Enable xearthlayer |
| `package` | package | `pkgs.xearthlayer` | Package to use |
| `provider.type` | enum | `"bing"` | Imagery provider |
| `provider.googleApiKey` | string | `null` | Google Maps API key |
| `provider.mapboxAccessToken` | string | `null` | MapBox access token |
| `cache.directory` | string | `null` | Cache directory |
| `cache.memorySize` | string | `null` | Memory cache size (e.g., "4GB") |
| `cache.diskSize` | string | `null` | Disk cache size (e.g., "50GB") |
| `cache.diskIoProfile` | enum | `null` | Disk I/O profile |
| `texture.format` | enum | `null` | DDS compression format |
| `texture.mipmaps` | int | `null` | Mipmap levels (1-10) |
| `prefetch.enable` | bool | `null` | Enable tile prefetching |
| `prefetch.mode` | enum | `null` | Prefetch mode |
| `prefetch.udpPort` | port | `null` | X-Plane telemetry UDP port |
| `xplane.sceneryDir` | string | `null` | X-Plane Custom Scenery directory |

### What the module does

- Installs xearthlayer to `home.packages`
- Generates `~/.xearthlayer/config.ini` with your settings

## Configuration Notes

> **⚠️ FUSE requirement**: xearthlayer uses FUSE to mount imagery. You must enable FUSE in your NixOS config:
> ```nix
> programs.fuse.userAllowOther = true;
> ```
> Alternatively, use `nixearthlayer.nixosModules.default` which enables FUSE automatically (and adds the package to `environment.systemPackages`).

> **⚠️ Upstream changes**: The xearthlayer configuration format may change between versions. This module covers common options but not all settings. If upstream adds new options or changes existing ones, you may need to configure them manually or wait for this flake to be updated.
>
> For the full list of configuration options, see the [upstream documentation](https://github.com/samsoir/xearthlayer/blob/main/docs/configuration.md).

## Providers

| Provider | API Key Required | Cost | Coverage |
|----------|------------------|------|----------|
| `bing` | No | Free | Global |
| `go2` | No | Free | Global (Google via public servers) |
| `google` | Yes | Paid | Global |
| `apple` | No | Free | Global (tokens auto-acquired) |
| `arcgis` | No | Free | Global |
| `mapbox` | Yes | Freemium | Global |
| `usgs` | No | Free | US only |

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
