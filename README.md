# NixOS NVIDIA vGPU Module

Example usage:
```nix
{
  # Optionally replace "master" with a particular revision to pin this dependency.
  # This repo also provides the module in a "Nix flake" under `nixosModules.nvidia-vgpu` output
  imports = [ (builtins.fetchTarball "https://github.com/danielfullmer/nixos-nvidia-vgpu/archive/master.tar.gz") ];

  hardware.nvidia.vgpu.enable = true; # Enable NVIDIA KVM vGPU + GRID driver
  hardware.nvidia.vgpu.unlock.enable = true; # Unlock vGPU functionality on consumer cards using DualCoder/vgpu_unlock project.
}
```
This currently creates a merged driver from the KVM + GRID drivers for using native desktop + VM guest simultaneously.
The merging stuff should probably be optional.

## Requirements
This module currently only works on with a recent NixOS unstable which has the `hardware.nvidia.package` option (Added in January 2021).
Additionally, the NVIDIA drivers used do not compile with newer kernels (I think `>= 5.10`).
This module has been tested using the `5.4` Linux kernel.

## Additional Notes
See also: https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/8/html/configuring_and_managing_virtualization/assembly_managing-nvidia-vgpu-devices_configuring-and-managing-virtualization

I've tested creating an mdev on my own 1080 Ti by running:
```shell
$ sudo mdevctl start -u 2d3a3f00-633f-48d3-96f0-17466845e672 -p 0000:03:00.0 --type nvidia-51
```
`nvidia-51` is the code for "GRID P40-8Q" in vgpuConfig.xml
```shell
$ sudo mdevctl define --auto --uuid 2d3a3f00-633f-48d3-96f0-17466845e672
