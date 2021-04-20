{
  description = "NixOS module which provides NVIDIA vGPU functionality";

  outputs = { self }: {
    nixosModules.nvidia-vgpu = import ./default.nix;
  };
}
