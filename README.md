# nixearthlayer

Nix flake for [xearthlayer](https://github.com/samsoir/xearthlayer) - streaming satellite imagery for X-Plane 12 flight simulator.

## Binary Cache

Pre-built binaries are available via Cachix:

```bash
nix run nixpkgs#cachix -- use mescam
```

Or add manually to your NixOS configuration:

```nix
{
  nix.settings = {
    substituters = [ "https://mescam.cachix.org" ];
    trusted-public-keys = [ "mescam.cachix.org-1:..." ];
  };
}
```

## Installation

### Flake-based NixOS

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixearthlayer.url = "github:mescam/nixearthlayer";
  };

  outputs = { self, nixpkgs, nixearthlayer, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        nixearthlayer.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

### Using the overlay

```nix
{
  nixpkgs.overlays = [ nixearthlayer.overlays.default ];
  environment.systemPackages = [ pkgs.xearthlayer ];
}
```

### Ad-hoc usage

```bash
nix run github:mescam/nixearthlayer
nix shell github:mescam/nixearthlayer
```

## NixOS Module

The module provides declarative configuration for xearthlayer and generates a config file.

### Basic usage

```nix
{
  services.xearthlayer = {
    enable = true;
    provider.type = "bing";
  };
}
```

### Full example

```nix
{
  services.xearthlayer = {
    enable = true;

    provider = {
      type = "bing";  # bing | go2 | google | apple | arcgis | mapbox | usgs
      # googleApiKey = "...";       # required for type = "google"
      # mapboxAccessToken = "...";  # required for type = "mapbox"
    };

    cache = {
      directory = "/var/cache/xearthlayer";
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

    xplane.sceneryDir = "/home/user/X-Plane 12/Custom Scenery";
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
| `cache.directory` | path | `null` | Cache directory |
| `cache.memorySize` | string | `null` | Memory cache size (e.g., "4GB") |
| `cache.diskSize` | string | `null` | Disk cache size (e.g., "50GB") |
| `cache.diskIoProfile` | enum | `null` | Disk I/O profile |
| `texture.format` | enum | `null` | DDS compression format |
| `texture.mipmaps` | int | `null` | Mipmap levels (1-10) |
| `prefetch.enable` | bool | `null` | Enable tile prefetching |
| `prefetch.mode` | enum | `null` | Prefetch mode |
| `prefetch.udpPort` | port | `null` | X-Plane telemetry UDP port |
| `xplane.sceneryDir` | path | `null` | X-Plane Custom Scenery directory |

### What the module does

- Installs xearthlayer to `environment.systemPackages`
- Enables `programs.fuse.userAllowOther` (required for FUSE mounts)
- Generates config at `/etc/xearthlayer/config.ini`

## Configuration Warning

> **⚠️ Important**: The generated config file is written to `/etc/xearthlayer/config.ini`, but xearthlayer expects its config at `~/.xearthlayer/config.ini` by default.
>
> You have several options:
> 1. Symlink: `ln -s /etc/xearthlayer/config.ini ~/.xearthlayer/config.ini`
> 2. Run the setup wizard: `xearthlayer setup` (creates user config)
> 3. Use the module just for installation and configure manually

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

## Home Manager

For per-user installation without the NixOS module:

```nix
{ pkgs, nixearthlayer, ... }:
{
  home.packages = [ nixearthlayer.packages.${pkgs.system}.xearthlayer ];
}
```

Then run `xearthlayer setup` to configure.

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
