{
  description = "NixOS module which provides NVIDIA vGPU functionality";

  inputs = {
    nixpkgs = {
      url = "https://github.com/NixOS/nixpkgs/archive/9f4128e00b0ae8ec65918efeba59db998750ead6.tar.gz"; # a working revision (09/07/2024)
    };
  };

  outputs = { self, nixpkgs,... }@inputs: 
    let

    in {
      nixosModules.nvidia-vgpu = import ./default.nix inputs;
    };
}


