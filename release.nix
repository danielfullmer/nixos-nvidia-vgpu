{ pkgs ? (import <nixpkgs> { config = {allowUnfree = true;}; }) }:

let
  lib = pkgs.lib;
  getNvidiaPackage = kernelPackages:
    (pkgs.nixos {
      imports = [ ./default.nix ];
      boot.kernelPackages = kernelPackages;
      hardware.nvidia.vgpu = {
        enable = true;
        unlock.enable = true;
      };
      #nixpkgs.config.allowUnfree = true;
    }).config.hardware.nvidia.package;
in
  lib.mapAttrs' (n: v: lib.nameValuePair "nvidia-${n}" (getNvidiaPackage v))
    (lib.filterAttrs (n: v: (lib.hasPrefix "linuxPackages_4_" n) || (lib.hasPrefix "linuxPackages_5_" n)) pkgs)
