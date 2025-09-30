# NixOS NVIDIA vGPU Module

> [!IMPORTANT]
> This repo isn't being developed further, efforts are currently focused on [mrzenc's rewrite of this module](https://github.com/mrzenc/nvidia-vgpu-nixos) (and their seperate [fastapi-dls module](https://github.com/mrzenc/fastapi-dls-nixos))  
> It also features guest support!
> <details>
> <summary>Example Working Config of Their Module</summary>
> 
> https://github.com/Yeshey/nixOS-Config/blob/17000dc17711fabb19a86a62ff8b25315a215c54/nixos/hyrulecastle/vgpu.nix 
>   
> </details>

This module unlocks vGPU functionality on your consumer nvidia card.


This module is for host machines, it installs a merged driver, meaning the host can use the GPU at the same time as guests.

> [!WARNING]  
> Activating this module may make some games stop working on the host, check [Known Issues](#known-issues).

## Installation:

1. Add Module to nixOS

   1. In a non-flake configuration you'll have to [add flake support](https://nixos.wiki/wiki/Flakes#:~:text=nix%2Dcommand%20flakes%27-,Enable%20flakes%20permanently%20in%20NixOS,-Add%20the%20following) to your system, with this method you'll also have to build with the additional '--impure' flag. Add this to your nixOS configuration:
   ```nix
   # configuration.nix
     imports = [
       (builtins.getFlake "https://github.com/Yeshey/nixos-nvidia-vgpu/archive/refs/heads/development.zip").nixosModules.nvidia-vgpu
     ];

     hardware.nvidia.vgpu = #...module config...

   ```

   2. In a Flake configuration you'll have to add the following. You may refer to [my nixos config](https://github.com/Yeshey/nixOS-Config/tree/HEAD@{2024-04-27}) for a working example or to [here](https://nixos.wiki/wiki/Flakes) for an introduction to flakes.
   ```nix
   # flake.nix
   {
     inputs = {
       nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

       nixos-nvidia-vgpu = {
         url = "github:Yeshey/nixos-nvidia-vgpu/535.129";

         # comment this line and a specific older revision
         # of nixpkgs known to work will be used
         inputs.nixpkgs.follows = "nixpkgs";
       };
     };

     outputs = {self, nixpkgs, nixos-nvidia-vgpu, ...}: {
       nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
         # ...
         modules = [
           nixos-nvidia-vgpu.nixosModules.default
           {
             hardware.nvidia.vgpu = #...module config...
           }
           # ...
         ];
       };
     };
   ```
2. Then add the module configuration to activate vgpu, example:
```nix
  boot.kernelPackages = pkgs.linuxPackages_6_1; # needs kernel 6.1

  hardware.nvidia.vgpu = {
    enable = true; # Install NVIDIA KVM vGPU + GRID driver + Activates required systemd services
    vgpu_driver_src.sha256 = "sha256-tFgDf7ZSIZRkvImO+9YglrLimGJMZ/fz25gjUT0TfDo="; # use if you're getting the `Unfortunately, we cannot download file...` error # find hash with `nix hash file foo.txt`  
    #copyVGPUProfiles = { # Use if your graphics driver isn't supported yet
    #  "1f11:0000" = "1E30:12BA"; # RTX 2060 Mobile 6GB (is already supported in the repo)
    #};
    pinKernel = false; # pins and installs a specific version of the 6.1 Kernel, recommended only if experiencing problems
    fastapi-dls = { # License server for unrestricted use of the vgpu driver in guests
      enable = true;
      #local_ipv4 = "192.168.1.109"; # Hostname is autodetected, use this setting to override
      #timezone = "Europe/Lisbon"; # detected automatically (needs to be the same as the tz in the VM)
      #docker-directory = "/mnt/dockers"; # default is "/opt/docker"
    };
  };
```
- This will attempt to compile and install the merged driver `535.129.03`, it merges the the common nvidia linux driver (like `NVIDIA-Linux-x86_64-535.129.03.run`) and a GRID driver that is usually for a server to share its GPU with multiple users (like `NVIDIA-GRID-Linux-KVM-535.129.03-537.70.run`), so the host can use and share the GPU simultaneously. We can't provide the latter, so you will be prompted with `nix-store --add-fixed...` to add it;  
  
  You'll need to get it [from nvidia](https://www.nvidia.com/object/vGPU-software-driver.html), you have to sign up and make a request that might take some days or refer to the [Discord VGPU-Unlock Community](https://discord.com/invite/5rQsSV3Byq) for support;  

  If you're still getting the `Unfortunately, we cannot download file...` error, use the option `vgpu_driver_src.sha256` to override the hardcoded hash. Find the hash of the file with `nix hash file file.zip`.
- You will have to check your kernel, kernel `6.1.` is recommended, higher than that won't work. Check the [Tested In](#tested-in) section to see the tested kernels.
- If you have a compiled merge driver, you can directly use it with the `useMyDriver` option. Here is an example using the driver in my google drive:

> [!IMPORTANT]  
> `useMyDriver` is only expected to work with a compiled host merged driver. It's mostly a legacy option intended now for those that had already compiled a driver or want to garantee the module won't ask to add files manually with `nix-store --add-fixed`

  ```nix
  {
    inputs,
    config,
    pkgs,
    lib,
    ...
  }:

  with lib;
  let
    cfg = config.mySystem.vgpu;

    # need to pin because of this error: https://discourse.nixos.org/t/cant-update-nvidia-driver-on-stable-branch/39246
    inherit (pkgs.stdenv.hostPlatform) system;
    patchedPkgs = import (fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/468a37e6ba01c45c91460580f345d48ecdb5a4db.tar.gz";
          # sha256 = "sha256:057qsz43gy84myk4zc8806rd7nj4dkldfpn7wq6mflqa4bihvdka"; ??? BREAKS Mdevctl WHY OMFG!!
          sha256 = "sha256:11ri51840scvy9531rbz32241l7l81sa830s90wpzvv86v276aqs";
      }) {
      inherit system;
      config.allowUnfree = true;
    };
  in
  {
    boot.kernelPackages = patchedPkgs.linuxPackages_5_15;

    hardware.nvidia = {
      vgpu = {
        enable = true; # Install NVIDIA KVM vGPU + GRID driver
        vgpu_driver_src.sha256 = "sha256-tFgDf7ZSIZRkvImO+9YglrLimGJMZ/fz25gjUT0TfDo="; # use if you're getting the `Unfortunately, we cannot download file...` error # find hash with `nix hash file foo.txt`        
        useMyDriver = {
          enable = true;
          name = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched.run";
          sha256 = "sha256-g8BM1g/tYv3G9vTKs581tfSpjB6ynX2+FaIOyFcDfdI=";
          driver-version = "525.105.14";
          vgpu-driver-version = "525.105.14";
          # you can not specify getFromRemote and it will ask to add the file manually with `nix-store --add-fixed...`
          getFromRemote = pkgs.fetchurl {
                name = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched.run"; # So there can be special characters in the link below: https://github.com/NixOS/nixpkgs/issues/6165#issuecomment-141536009
                url = "https://drive.usercontent.google.com/download?id=17NN0zZcoj-uY2BELxY2YqGvf6KtZNXhG&export=download&authuser=0&confirm=t&uuid=b70e0e36-34df-4fde-a86b-4d41d21ce483&at=APZUnTUfGnSmFiqhIsCNKQjPLEk3%3A1714043345939";
                sha256 = "sha256-g8BM1g/tYv3G9vTKs581tfSpjB6ynX2+FaIOyFcDfdI=";
              };
        };
        fastapi-dls = {
          enable = true;
          #local_ipv4 = "192.168.1.109"; # "localhost"; #"192.168.1.109";
          #timezone = "Europe/Lisbon";
          #docker-directory = "/mnt/dockers";
        };
      };
    };

  }
  ```

1. Run `nixos-rebuild switch`.

You can refer to `./guides` for specific goals:
- [virt-manager.md]() to set up a virt-mananger windows 10 guest that can be viewed through looking glass with samba folder sharing.

## Requirements

- Unlockable consumer NVIDIA GPU card (can't be `Ampere` architecture)
  - [These](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher/blob/525.105/patch.sh) are the graphic cards the driver supports.  
  - These are the graphics my pre-compiled driver in google drive supports:
    
    ```
      # RTX 2070 super 8GB
      # RTX 2080 super 8GB
      # RTX 2060 12GB
      # RTX 2060 Mobile 6GB
      # GTX 1660 6GB
      # GTX 1650 Ti Mobile 4GB
      # Quadro RTX 4000
      # Quadro T400 4GB
      # GTX 1050 Ti 4GB
      # GTX 1070
      # GTX 1030 -> Tesla P40
      # Tesla M40 -> Tesla M60
      # GTX 980 -> Tesla M60
      # GTX 980M -> Tesla M60
      # GTX 950M -> Tesla M10
    ```
    If yours is not in this list or in the repo, you'll likely have to add support for your graphics card through `copyVGPUProfiles` option, please refer to [The official VGPU-Community-Drivers README](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher) for figuring out the right values for your graphics card.
  
      - Use the option as shown in the module configuration options, for example:
        ```nix
        copyVGPUProfiles = {
          "1f11:0000" = "1E30:12BA"; # RTX 2060 Mobile 6GB (is already supported in the repo)
        };
        ```
        would generate the vcfgclone line:  
        ```sh
        vcfgclone ${TARGET}/vgpuConfig.xml 0x1E30 0x12BA 0x1f11 0x0000
        ```
        The option adds vcfgclone lines to the patch.sh script of the vgpu-unlock-patcher.  
        They copy the vGPU profiles of officially supported GPUs specified by the attribute value ("1E30:12BA" in the example) to the video card specified by the attribute name ("1f11:0000" in the example). Not required when vcfgclone line with your GPU is already in the script. CASE-SENSETIVE, use UPPER case for the attribute value. Copy profiles from a GPU with a similar chip or at least architecture, otherwise nothing will work. See patch.sh for working vcfgclone examples.  

        If you found a working vcfgclone line that works and isn't in the repo yet, consider sharing it in the [VGPU-Unlock discord](https://discord.com/invite/5rQsSV3Byq) or with a maintainer of the [VGPU Unlock Community Repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher) for it to be added.

### Tested in

- kernel `5.15.108` with a `NVIDIA GeForce RTX 2060 Mobile` in `NixOS 22.11.20230428.7449971`. 
- kernel `5.15.108` with a `NVIDIA GeForce RTX 2060 Mobile` in `NixOS 23.05.20230605.70f7275`.
- kernel `5.15.82` with a `NVIDIA GeForce RTX 2060 Mobile` in `NNixOS 23.11.20240403.1487bde (Tapir) x86_64`.
- kernel `6.1.96` with a `NVIDIA GeForce RTX 2060 Mobile` in `NixOS 24.05.20240704.c0d0be0`. 

## Guest VMs

### Windows Guest

In the Windows VM you might need to install the appropriate drivers too, if in the host you use an A profile([difference between profiles](https://youtu.be/cPrOoeMxzu0?t=1244)) for example (from the `mdevctl types` command) you can use the normal driver from the [nvidia licensing server](#nvidia-drivers), if you want a Q profile, you're gonna need to get the driver from the [nvidia servers](#nvidia-drivers) and patch it with the [community vgpu unlock repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher).

That [didn't work for me](https://discord.com/channels/829786927829745685/830520513834516530/1109199157299793970) tho.

Besides the above profiles there are vGaming profiles for the host, the ones I recommend, I used the special `GeForce RTX 2070-` profiles (from `mdevctl types`).  
If using this profile, you should be able to install the normal corresponding nvidia driver for the windows guest, it will support vulkan, opengl, directx and such for games but not CUDA.  
If you're having trouble with the licensing (altho fastapi-dls should be able to deal with it), you might have to install a specific driver like [this one](https://nvidia-gaming.s3.us-east-1.amazonaws.com/windows/528.49_Cloud_Gaming_win10_win11_server2019_server2022_dch_64bit_international.exe).   
Here is the explanation of where that driver is from:
> vGaming is specially licensed.  
> there's no trial and you need to buy a compute cluster from nuhvidya.  
> But Amazon has this and they host the drivers for people to use.  
> The link comes from their bucket that has the vGaming drivers

Ask in the [VGPU-Unlock discord](https://discord.com/invite/5rQsSV3Byq) for the correct version if this is the case.

### Linux Guest

(Untested) You likely need to install the nvidia grid drivers in the guest. There isn't a module to get them to work in nixOS as far as I know (https://github.com/Yeshey/nixos-nvidia-vgpu/issues/5).

### nvidia-drivers

To get the nvidia vgpu drivers: downloads are available from nvidia site [here](http://nvid.nvidia.com/dashboard/), evaluation account may be obtained [here](http://www.nvidia.com/object/vgpu-evaluation.html)  
For guest drivers for windows get the ones with the name `Microsoft Hyper-V Server`  
To check and match versions see [here](https://docs.nvidia.com/grid/index.html). For example:
| vGPU Software | Linux vGPU Manager | Windows vGPU Manager | Linux Driver | Windows Driver | Release Date |
|--------------|-------------------|---------------------|--------------|----------------|--------------|
| 16.2         | 535.129.03        | 537.70              | 535.129.03   |	537.70         | October 2023 |
| 15.2         | 525.105.14        | 528.89              | 525.105.17   | 528.89         | March 2023   |
| 15.1         | 525.85.07         | 528.24              | 525.85.05    | 528.24         | January 2023 |
| 15.0         | 525.60.12         | 527.41              | 525.60.13    | 527.41         | December 2022|

## Additional Notes

To test if everything is installed correctly run `nvidia-smi vgpu`. If there is no output something went wrong with the installation.  
Also test `mdevctl types`, if there is no output, maybe your graphics card isn't supported yet or you have an incompatible kernel.

You can also check if the services `nvidia-vgpu-mgr` and `nvidia-vgpud` executed without errors with `systemctl status nvidia-vgpud` and `systemctl status nvidia-vgpu-mgr`. (or something like `journalctl -fu nvidia-vgpud` to see the logs in real time)

If you set up fastapi-dls correctly, you should get a notification when your windows VM starts saying it was successful. In the Linux or Windows guest you can also run `nvidia-smi -q  | grep -i "License"` or `& 'nvidia-smi' -q | Select-String "License"` respectively to check.

I've tested creating an mdev on my own `NVIDIA GeForce RTX 2060 Mobile` by running:
```bash
> sudo su

> uuidgen
ce851576-7e81-46f1-96e1-718da691e53e

> lspci -D -nn | grep -i nvidia # to find the right address
0000:01:00.0 VGA compatible controller [0300]: NVIDIA Corporation TU106M [GeForce RTX 2060 Mobile] [10de:1f11] (rev a1)
0000:01:00.1 Audio device [0403]: NVIDIA Corporation TU106 High Definition Audio Controller [10de:10f9] (rev a1)
0000:01:00.2 USB controller [0c03]: NVIDIA Corporation TU106 USB 3.1 Host Controller [10de:1ada] (rev a1)
0000:01:00.3 Serial bus controller [0c80]: NVIDIA Corporation TU106 USB Type-C UCSI Controller [10de:1adb] (rev a1)

> mdevctl start -u ce851576-7e81-46f1-96e1-718da691e53e -p 0000:01:00.0 --type nvidia-258 && mdevctl start -u b761f485-1eac-44bc-8ae6-2a3569881a1a -p 0000:01:00.0 --type nvidia-258 && mdevctl define --auto --uuid ce851576-7e81-46f1-96e1-718da691e53e && mdevctl define --auto --uuid b761f485-1eac-44bc-8ae6-2a3569881a1a
```
That creates two VGPUs in my graphics card (because my card has 6Gb so 3Gb each VGPU. It needs to devide evenly, so I could also do 3 VGPUs of 2Gb each for example, but it's not possible to have 1 VGPU of 4Gb and one of 2Gb)

check if they were created successfully with `mdevctl list`
```bash
 ✘ ⚡ root@nixOS-Laptop  /home/yeshey  mdevctl list
ce851576-7e81-46f1-96e1-718da691e53e 0000:01:00.0 nvidia-258 (defined)
b761f485-1eac-44bc-8ae6-2a3569881a1a 0000:01:00.0 nvidia-258 (defined)
```

(UNTESTED!) Also you can change the resolution and other parameters of a profile directly in the vgpu config xml here: `/etc/nvidia-vgpu-xxxxx/vgpuConfig.xml`, so you can mod for example a A profile as you need, just need to reboot to get the changes loaded (or reload all the stuff).

## Compile your drivers

Use `nix-shell` to get the tools to run the [vGPU community repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher), you'll have to clone the branch for the driver you want with submodules, for example: `git clone --recurse-submodules -b 525.105 https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher.git`.  

### Linux Host Merged Driver

In the case of the merged driver you'll have to get the vgpu driver and the normal driver and merge them with the vGPU repo.

1. Refer to the [vGPU community repo](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher). If your graphics card isn't supported you'll likely have to add a `vcfgclone` in patch.sh of their repository as per their instructions.
2. Use the option `useMyDriver` like shown in [installation](#installation) section.
4. Refer to the [VGPU-Unlock discord community](https://discord.com/invite/5rQsSV3Byq) for help :)

## To-Do

- ~~Add mechanism to add more cards through vcfgclone~~ (Added by [mrzenc](https://github.com/mrzenc), thanks!)

---

For more help [Join VGPU-Unlock discord for Support](https://discord.com/invite/5rQsSV3Byq)

## Known Issues

Biggest problems of the module:
- **Some games stop working on host** (DXVK?), [Issue on GPU Unlocking discord](https://discord.com/channels/829786927829745685/1192188752915869767)
- **Very inefficient installation process**: it installs 555 driver - it installs 535 vgpu driver - 535 driver compiles, get unpacked (by [patcher](https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher/blob/535.129/patch.sh)) then repacked (because of --repack) and then unpacked again by builder.sh (see [here](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11/builder.sh) and [here](https://github.com/NixOS/nixpkgs/blob/master/pkgs/os-specific/linux/nvidia-x11/generic.nix#L114)) in the process. 555 compiles because why not.
- ~~Core dump from nvidia-vgpud happening bc of frida?~~(fixed, frida is not even needed anymore, it was for the old vgpu repo)
- ~~Grabs merged driver from my google drive instead of compiling it~~(fixed by [letmeiiiin](https://github.com/letmeiiiin)'s [work](https://github.com/letmeiiiin/nixos-nvidia-vgpu)! Big thanks!)
- ~~Commands need to be ran manually for the docker volume to work: Still needs `--impure`: `access to absolute path '/opt/docker' is forbidden in pure eval mode (use '--impure' to override)`~~ (fixed, `--impure` not needed anymore! Big thanks to [physics-enthusiast](https://github.com/physics-enthusiast)'s [contributions](https://github.com/Yeshey/nixos-nvidia-vgpu/pull/2))
- ~~Needs `--impure` to run.~~
  - ~~`error: cannot call 'getFlake' on unlocked flake reference 'github:itstarsun/frida-nix'`, because of the line:~~
  - ~~`frida = (builtins.getFlake "github:itstarsun/frida-nix").packages.x86_64-linux.frida-tools;`~~ (fixed, [thanks](https://discourse.nixos.org/t/for-nixos-on-aws-ec2-how-to-get-ip-address/15616/12?u=yeshey)!)
- ~~Hard coded nix store paths: https://discourse.nixos.org/t/how-to-use-python-environment-in-a-systemd-service/28022~~ (fixed!)

## Acknowledgements

I'm not an experienced nix developer and a lot of what's implemented here could be done in a better way. If anyone is interested in contributing, you may get in contact through the issues or simply make a pull request with details as to what it changes.

This was heavily based and inspiered in these two repositories:

- old NixOS module: https://github.com/danielfullmer/nixos-nvidia-vgpu
- vgpu for newer nvidia drivers: https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher
