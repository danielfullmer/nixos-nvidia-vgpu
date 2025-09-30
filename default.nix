inputs: { pkgs, lib, config, ... }:

let
  cfg = config.hardware.nvidia.vgpu;

  driver-version = cfg.useMyDriver.driver-version; # "535.129.03";
  # grid driver and wdys driver aren't actually used, but their versions are needed to find some filenames
  vgpu-driver-version = cfg.useMyDriver.vgpu-driver-version; #"535.129.03";
  grid-driver-version = "535.129.03";
  wdys-driver-version = "537.70";
  grid-version = "16.2";
  kernel-at-least-6 = lib.strings.versionAtLeast config.boot.kernelPackages.kernel.version "6.0";
in
let
  inherit (pkgs.stdenv.hostPlatform) system;

  mdevctl = pkgs.callPackage ./mdevctl {};

  combinedZipName = "NVIDIA-GRID-Linux-KVM-${vgpu-driver-version}-${wdys-driver-version}.zip";
  requireFile = { name, ... }@args: pkgs.requireFile (rec {
    inherit name;
    url = "https://www.nvidia.com/object/vGPU-software-driver.html";
    message = ''
      Unfortunately, we cannot download file ${name} automatically.
      This file can be extracted from ${combinedZipName}.
      Please go to ${url} to download it yourself or ask the vgpu discord community for support (https://discord.com/invite/5rQsSV3Byq)
      You can see the related nvidia driver versions here: https://docs.nvidia.com/grid/index.html. Add it to the Nix store
      using either
        nix-store --add-fixed sha256 ${name}
      or
        nix-prefetch-url --type sha256 file:///path/to/${name}

      If you already added the file, maybe the sha256 is wrong, use "nix hash file ${name}" and the option vgpu_driver_src.sha256 to override the hardcoded hash.
    '';
  } // args);

  compiled-driver = pkgs.stdenv.mkDerivation {
    name = "NVIDIA-Linux-x86_64-${driver-version}-merged-vgpu-kvm-patched";
      nativeBuildInputs = [ pkgs.p7zip pkgs.unzip pkgs.coreutils pkgs.bash pkgs.zstd];
        system = "x86_64-linux";
        src = pkgs.fetchFromGitHub {
          owner = "VGPU-Community-Drivers";
          repo = "vGPU-Unlock-patcher";
          # 535.129
          rev = "3765eee908858d069e7b31842f3486095b0846b5";
          hash = "sha256-PR61ylYgTaWQ/xxMDR8ZUUA5vQNUcZvIt/hqgpAQeNM=";
          fetchSubmodules = true;
          deepClone = true;
        };
        original_driver_src = pkgs.fetchurl {
          # Hosted by nvidia
          url = "https://download.nvidia.com/XFree86/Linux-x86_64/${driver-version}/NVIDIA-Linux-x86_64-${driver-version}.run";
          sha256 = "e6dca5626a2608c6bb2a046cfcb7c1af338b9e961a7dd90ac09bb8a126ff002e";
        };
        vgpu_driver_src = requireFile {
            name = "NVIDIA-GRID-Linux-KVM-${driver-version}-${wdys-driver-version}.zip";
            sha256 = cfg.vgpu_driver_src.sha256; # nix hash file foo.txt
          };
 
        buildPhase = ''
          mkdir -p $out
          cd $TMPDIR
          #ln -s $original_driver_src NVIDIA-Linux-x86_64-${driver-version}.run
          ln -s $vgpu_driver_src NVIDIA-GRID-Linux-KVM-${driver-version}-${wdys-driver-version}.zip
          
          ${pkgs.unzip}/bin/unzip -j NVIDIA-GRID-Linux-KVM-${driver-version}-${wdys-driver-version}.zip Host_Drivers/NVIDIA-Linux-x86_64-${driver-version}-vgpu-kvm.run
          cp -a $src/* .
          cp -a $original_driver_src NVIDIA-Linux-x86_64-${driver-version}.run

          sed -i '0,/^    vcfgclone \''${TARGET}\/vgpuConfig.xml /s//${lib.attrsets.foldlAttrs (s: n: v: s + "    vcfgclone \\\${TARGET}\\/vgpuConfig.xml 0x${builtins.substring 0 4 v} 0x${builtins.substring 5 4 v} 0x${builtins.substring 0 4 n} 0x${builtins.substring 5 4 n}\\n") "" cfg.copyVGPUProfiles}&/' ./patch.sh
          
          bash ./patch.sh ${lib.optionalString kernel-at-least-6 "--force-nvidia-gpl-I-know-it-is-wrong --enable-nvidia-gpl-for-experimenting"} --repack general-merge
          cp -a NVIDIA-Linux-x86_64-${driver-version}-merged-vgpu-kvm-patched.run $out
        '';
  };
in
{
  options = with lib; {
    hardware.nvidia.vgpu = {
      enable = mkEnableOption "vGPU support";

      pinKernel = mkOption {
        default = false;
        type = types.bool;
        description = ''
          This will set kernel 6.1, a long term support release(LTS), higher kernels won't work with this module.
          If the inputs of this module aren't set to follow the rest of nixpkgs in the inputs (inputs.nixpkgs.follows = "nixpkgs";), then this means your kernel will also be pinned to the nixpkgs revision of this module known to work, and you won't recieve the security updates from the LTS (until 31 Dec 2026).
          Not recommended unless you are experiencing problems.
        '';
      };

      copyVGPUProfiles = mkOption {
        default = {};
        type = types.attrs;
        example = {
          "1122:3344" = "5566:7788";
          "1f11:0000" = "1E30:12BA"; # vcfgclone line for RTX 2060 Mobile 6GB. generates: vcfgclone ${TARGET}/vgpuConfig.xml 0x1E30 0x12BA 0x1f11 0x0000
        };
        description = ''
          Adds vcfgclone lines to the patch.sh script of the vgpu-unlock-patcher.
          They copy the vGPU profiles of officially supported GPUs specified by the attribute value to the video card specified by the attribute name. Not required when vcfgclone line with your GPU is already in the script. CASE-SENSETIVE, use UPPER case. Copy profiles from a GPU with a similar chip or at least architecture, otherwise nothing will work. See patch.sh for working vcfgclone examples.
          In the first example option value, it will copy the vGPU profiles of 5566:7788 to GPU 1122:3344 (vcfgclone ''${TARGET}/vgpuConfig.xml 0x5566 0x7788 0x1122 0x3344 in patch.sh).
        '';
      };

      vgpu_driver_src.sha256 = mkOption {
        default = "sha256-tFgDf7ZSIZRkvImO+9YglrLimGJMZ/fz25gjUT0TfDo=";
        type = types.str;
        description = ''
          sha256 of the vgpu_driver file in case you're having trouble adding it with for Example `nix-store --add-fixed sha256 NVIDIA-GRID-Linux-KVM-535.129.03-537.70.zip`
          You can find the hash of the file with `nix hash file foo.txt`
        '';
      };

      useMyDriver = mkOption {
        description = "Set up fastapi-dls host server";
        type = types.submodule {
          options = {
            enable = mkOption {
              default = false;
              type = types.bool;
              description = ''
                If enabled, the module won't compile the merged driver from the normal nvidia driver and the vgpu driver.
                You will be asked to add the driver to the store with nix-store --add-fixed sha256 file.zip
                Can be useful if you already compiled a driver or if you needed to add a vcfgclone line for your graphics card that hasn't been added to the VGPU-Community-Drivers repo and compile your driver with that. 
              '';
            };
            sha256 = mkOption {
              default = "";
              type = types.str;
              example = "sha256-g8BM1g/tYv3G9vTKs581tfSpjB6ynX2+FaIOyFcDfdI=";
              description = ''
                The sha256 for the driver you compiled. Find it by running `nix hash file fileName.run`
              '';
            };
            name = mkOption {
              default = "";
              type = types.str;
              example = "NVIDIA-Linux-x86_64-525.105.17-merged-vgpu-kvm-patched.run";
              description = ''
                Name of your compiled driver
              '';
            };
            getFromRemote = mkOption {
              default = null;
              type = types.nullOr types.package;
              #example = "525.105.17";
              description = ''
                If you have your merged driver online you can use this. 
                If used, instead of asking to supply the driver with `nix-store --add-fixed sha256 file`, will grab it from the online source.
              '';
            };
            driver-version = mkOption {
              default = "535.129.03";
              type = types.str;
              example = "525.105.17";
              description = ''
                Name of your compiled driver
              '';
            };
            vgpu-driver-version = mkOption {
              default = "535.129.03";
              type = types.str;
              example = "525.105.17";
              description = ''
                Name of your compiled driver
              '';
            };
          };
        };
        default = {};
      };

      # submodule
      fastapi-dls = mkOption {
        description = "Set up fastapi-dls host server";
        type = types.submodule {
          options = {
            enable = mkOption {
              default = false;
              type = types.bool;
              description = "Set up fastapi-dls host server";
            };
            docker-directory = mkOption {
              description = "Path to your folder with docker containers";
              default = "/opt/docker";
              example = "/dockers";
              type = types.str;
            };
            local_ipv4 = mkOption {
              description = "Your ipv4 or local hostname, needed for the fastapi-dls server. Leave blank to autodetect using hostname";
              default = "";
              example = "192.168.1.81";
              type = types.str;
            };
            timezone = mkOption {
              description = "Your timezone according to this list: https://docs.diladele.com/docker/timezones.html, needs to be the same as in the VM. Leave blank to autodetect";
              default = "";
              example = "Europe/Lisbon";
              type = types.str;
            };
          };
        };
        default = {};
      };
      
    };
  };

  config = lib.mkMerge [ ( lib.mkIf (cfg.enable && cfg.pinKernel) {

      boot.kernelPackages = pkgs.linuxPackages_6_1; # 6.1, LTS Kernel

    })
    
    ( lib.mkIf cfg.enable {
  
      hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (
        { patches ? [], postUnpack ? "", postPatch ? "", preFixup ? "", ... }@attrs: {
        # Overriding https://github.com/NixOS/nixpkgs/tree/nixos-unstable/pkgs/os-specific/linux/nvidia-x11
        # that gets called from the option hardware.nvidia.package from here: https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/hardware/video/nvidia.nix
        name = "NVIDIA-Linux-x86_64-${driver-version}-merged-vgpu-kvm-patched-${config.boot.kernelPackages.kernel.version}";
        version = "${driver-version}";

        # the new driver (compiled in a derivation above)
        src = if (!cfg.useMyDriver.enable) then
          "${compiled-driver}/NVIDIA-Linux-x86_64-${driver-version}-merged-vgpu-kvm-patched.run"
          else
            if (cfg.useMyDriver.getFromRemote != null) then
              cfg.useMyDriver.getFromRemote
            else
              pkgs.requireFile {
                name = cfg.useMyDriver.name;
                url = "compile it with the repo https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher 😉, also if you got this error the hash might be wrong, use `nix hash file <file>`";
                # The hash below was computed like so:
                #
                # $ nix hash file foo.txt
                # sha256-9fhYGu9fqxcQC2Kc81qh2RMo1QcLBUBo8U+pPn+jthQ=
                #
                sha256 = cfg.useMyDriver.sha256;
              };

        postPatch = if postPatch != null then postPatch + ''
          # Move path for vgpuConfig.xml into /etc
          sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

          substituteInPlace sriov-manage \
            --replace lspci ${pkgs.pciutils}/bin/lspci \
            --replace setpci ${pkgs.pciutils}/bin/setpci
        '' else ''
          # Move path for vgpuConfig.xml into /etc
          sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

          substituteInPlace sriov-manage \
            --replace lspci ${pkgs.pciutils}/bin/lspci \
            --replace setpci ${pkgs.pciutils}/bin/setpci
        '';

        /*
        postPatch = postPatch + ''
          # Move path for vgpuConfig.xml into /etc
          sed -i 's|/usr/share/nvidia/vgpu|/etc/nvidia-vgpu-xxxxx|' nvidia-vgpud

          substituteInPlace sriov-manage \
            --replace lspci ${pkgs.pciutils}/bin/lspci \
            --replace setpci ${pkgs.pciutils}/bin/setpci
        ''; */

        # HACK: Using preFixup instead of postInstall since nvidia-x11 builder.sh doesn't support hooks
        preFixup = preFixup + ''
          for i in libnvidia-vgpu.so.${vgpu-driver-version} libnvidia-vgxcfg.so.${vgpu-driver-version}; do
            install -Dm755 "$i" "$out/lib/$i"
          done
          patchelf --set-rpath ${pkgs.stdenv.cc.cc.lib}/lib $out/lib/libnvidia-vgpu.so.${vgpu-driver-version}
          install -Dm644 vgpuConfig.xml $out/vgpuConfig.xml

          for i in nvidia-vgpud nvidia-vgpu-mgr; do
            install -Dm755 "$i" "$bin/bin/$i"
            # stdenv.cc.cc.lib is for libstdc++.so needed by nvidia-vgpud
            patchelf --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
              --set-rpath $out/lib "$bin/bin/$i"
          done
          install -Dm755 sriov-manage $bin/bin/sriov-manage
        '';
      });

      systemd.services.nvidia-vgpud = {
        description = "NVIDIA vGPU Daemon";
        wants = [ "syslog.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "forking";
          ExecStart = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpud";
          ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpud";
          Environment = [ "__RM_NO_VERSION_CHECK=1" ]; # I think it's not needed anymore? (Avoids issue with API version incompatibility when merging host/client drivers)
        };
      };

      systemd.services.nvidia-vgpu-mgr = {
        description = "NVIDIA vGPU Manager Daemon";
        wants = [ "syslog.target" ];
        wantedBy = [ "multi-user.target" ];

        serviceConfig = {
          Type = "forking";
          KillMode = "process";
          ExecStart = "${lib.getBin config.hardware.nvidia.package}/bin/nvidia-vgpu-mgr";
          ExecStopPost = "${pkgs.coreutils}/bin/rm -rf /var/run/nvidia-vgpu-mgr";
          environment = [
            "__RM_NO_VERSION_CHECK=1"
            "LD_LIBRARY_PATH=${pkgs.glib.out}/lib:$LD_LIBRARY_PATH"
            "LD_PRELOAD=${pkgs.glib.out}/lib/libglib-2.0.so"
          ];
        };
      };
      
      boot.extraModprobeConfig = 
        ''
        options nvidia vup_sunlock=1 vup_swrlwar=1 vup_qmode=1
        ''; # (for driver 535) bypasses `error: vmiop_log: NVOS status 0x1` in nvidia-vgpu-mgr.service when starting VM

      environment.etc."nvidia-vgpu-xxxxx/vgpuConfig.xml".source = config.hardware.nvidia.package + /vgpuConfig.xml;

      boot.kernelModules = [ "nvidia-vgpu-vfio" ];

      environment.systemPackages = [ mdevctl ];
      services.udev.packages = [ mdevctl ];

    })

    (lib.mkIf (cfg.enable && cfg.fastapi-dls.enable) {
    
      virtualisation.oci-containers.containers = {
        fastapi-dls = {
          image = "collinwebdesigns/fastapi-dls";
          imageFile = pkgs.dockerTools.pullImage {
            imageName = "collinwebdesigns/fastapi-dls";
            imageDigest = "sha256:b7b5781a19058b7a825e8a4bb6982e09d0e390ee6c74f199ff9938d74934576c";
            sha256 = "sha256-1qvsVMzM4/atnQmxDMIamIVHCEYpxh0WDLLbANS2Wzw=";
          };
          volumes = [
            "${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert:/app/cert:rw"
            "dls-db:/app/database"
          ];
          # Set environment variables
          environment = {
            TZ = if cfg.fastapi-dls.timezone == "" then config.time.timeZone else "${cfg.fastapi-dls.timezone}";
            DLS_URL = if cfg.fastapi-dls.local_ipv4 == "" then config.networking.hostName else "${cfg.fastapi-dls.local_ipv4}";
            DLS_PORT = "443";
            LEASE_EXPIRE_DAYS="90";
            DATABASE = "sqlite:////app/database/db.sqlite";
            DEBUG = "true";
          };
          extraOptions = [
          ];
          # Publish the container's port to the host
          ports = [ "443:443" ];
          # Do not automatically start the container, it will be managed
          autoStart = false;
        };
      };

      systemd.timers.fastapi-dls-mgr = {
        wantedBy = [ "multi-user.target" ];
        timerConfig = {
          OnActiveSec = "1s";
          OnUnitActiveSec = "1h";
          AccuracySec = "1s";
          Unit = "fastapi-dls-mgr.service";
        };
      };

      systemd.services.fastapi-dls-mgr = {
        path = [ pkgs.openssl ];
        script = ''
  WORKING_DIR=${cfg.fastapi-dls.docker-directory}/fastapi-dls/cert
  CERT_CHANGED=false

  recreate_private () {
    echo "Recreating private key..."
    rm -f $WORKING_DIR/instance.private.pem
    openssl genrsa -out $WORKING_DIR/instance.private.pem 2048
  }

  recreate_public () {
    echo "Recreating public key..."
    rm -f $WORKING_DIR/instance.public.pem
    openssl rsa -in $WORKING_DIR/instance.private.pem -outform PEM -pubout -out $WORKING_DIR/instance.public.pem
  }

  recreate_certs () {
    echo "Recreating certificates..."
    rm -f $WORKING_DIR/webserver.key
    rm -f $WORKING_DIR/webserver.crt
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout $WORKING_DIR/webserver.key -out $WORKING_DIR/webserver.crt -subj "/C=XX/ST=StateName/L=CityName/O=CompanyName/OU=CompanySectionName/CN=CommonNameOrHostname"
  }

  check_recreate() {
    echo "Checking if certificates need to be recreated..."
    if [ ! -e $WORKING_DIR/instance.private.pem ]; then
      echo "Private key missing, recreating..."
      recreate_private
      recreate_public
      recreate_certs
      CERT_CHANGED=true
    fi
    if [ ! -e $WORKING_DIR/instance.public.pem ]; then
      echo "Public key missing, recreating..."
      recreate_public
      recreate_certs
      CERT_CHANGED=true
    fi
    if [ ! -e $WORKING_DIR/webserver.key ] || [ ! -e $WORKING_DIR/webserver.crt ]; then
      echo "Webserver certificates missing, recreating..."
      recreate_certs
      CERT_CHANGED=true
    fi
    if ( ! openssl x509 -checkend 864000 -noout -in $WORKING_DIR/webserver.crt); then
      echo "Webserver certificate will expire soon, recreating..."
      recreate_certs
      CERT_CHANGED=true
    fi
  }

  echo "Ensuring working directory exists..."
  if [ ! -d $WORKING_DIR ]; then
    mkdir -p $WORKING_DIR
  fi

  check_recreate

  if ( ! systemctl is-active --quiet podman-fastapi-dls.service); then
    echo "Starting podman-fastapi-dls.service..."
    systemctl start podman-fastapi-dls.service
  elif $CERT_CHANGED; then
    echo "Restarting podman-fastapi-dls.service due to certificate change..."
    systemctl stop podman-fastapi-dls.service
    systemctl start podman-fastapi-dls.service
  fi
  '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    })
  ];
}
