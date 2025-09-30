## Guide on vgpu sharing with local Windows VM running on virt-manager and seen through Looking-Glass

This is assuming you already created the vgpus with `mdevctl`. (They'll have to be created every reboot). After having things set up, you can use a script like the `run-vm.sh` script on this folder for quickly creating the vgpus, starting the VM, and launching looking-glass.  
You'll have to change the commands to create the vgpus and the name of your virtual machine in the script, rn is `win10`.

### Virt-manager

A good guide on this: https://github.com/tuh8888/libvirt_win10_vm.
My current win10 config looks like this, `sudo virsh edit win10`:
```xml
<domain type="kvm">
  <name>win11</name>
  <uuid>6a56489d-f65e-4e3b-9d99-ec7f89237e34</uuid>
  <metadata>
    <libosinfo:libosinfo xmlns:libosinfo="http://libosinfo.org/xmlns/libvirt/domain/1.0">
      <libosinfo:os id="http://microsoft.com/win/11"/>
    </libosinfo:libosinfo>
  </metadata>
  <memory unit="KiB">8388608</memory>
  <currentMemory unit="KiB">8388608</currentMemory>
  <vcpu placement="static">8</vcpu>
  <cputune>
    <vcpupin vcpu="0" cpuset="4"/>
    <vcpupin vcpu="1" cpuset="5"/>
    <vcpupin vcpu="2" cpuset="6"/>
    <vcpupin vcpu="3" cpuset="7"/>
    <vcpupin vcpu="4" cpuset="8"/>
    <vcpupin vcpu="5" cpuset="9"/>
    <vcpupin vcpu="6" cpuset="10"/>
    <vcpupin vcpu="7" cpuset="11"/>
  </cputune>
  <os firmware="efi">
    <type arch="x86_64" machine="pc-q35-9.2">hvm</type>
    <firmware>
      <feature enabled="no" name="enrolled-keys"/>
      <feature enabled="yes" name="secure-boot"/>
    </firmware>
    <loader readonly="yes" secure="yes" type="pflash" format="raw">/nix/store/i03rw8r4dysh2185c7pfwc6zgc837gfc-qemu-9.2.4/share/qemu/edk2-x86_64-secure-code.fd</loader>
    <nvram template="/nix/store/i03rw8r4dysh2185c7pfwc6zgc837gfc-qemu-9.2.4/share/qemu/edk2-i386-vars.fd" templateFormat="raw" format="raw">/var/lib/libvirt/qemu/nvram/win11_VARS.fd</nvram>
    <boot dev="hd"/>
  </os>
  <features>
    <acpi/>
    <apic/>
    <hyperv mode="custom">
      <relaxed state="on"/>
      <vapic state="on"/>
      <spinlocks state="on" retries="8191"/>
      <vpindex state="on"/>
      <runtime state="on"/>
      <synic state="on"/>
      <stimer state="on"/>
      <frequencies state="on"/>
      <tlbflush state="on"/>
      <ipi state="on"/>
      <evmcs state="on"/>
      <avic state="on"/>
    </hyperv>
    <vmport state="off"/>
    <smm state="on"/>
  </features>
  <cpu mode="host-passthrough" check="none" migratable="on">
    <topology sockets="1" dies="1" clusters="1" cores="4" threads="2"/>
  </cpu>
  <clock offset="localtime">
    <timer name="rtc" tickpolicy="catchup"/>
    <timer name="pit" tickpolicy="delay"/>
    <timer name="hpet" present="no"/>
    <timer name="hypervclock" present="yes"/>
  </clock>
  <on_poweroff>destroy</on_poweroff>
  <on_reboot>restart</on_reboot>
  <on_crash>destroy</on_crash>
  <pm>
    <suspend-to-mem enabled="no"/>
    <suspend-to-disk enabled="no"/>
  </pm>
  <devices>
    <emulator>/run/libvirt/nix-emulators/qemu-system-x86_64</emulator>
    <disk type="file" device="disk">
      <driver name="qemu" type="qcow2"/>
      <source file="/home/yeshey/AppFiles/interchangeable/VMs/Windows/win10.qcow2"/>
      <target dev="sda" bus="sata"/>
      <address type="drive" controller="0" bus="0" target="0" unit="0"/>
    </disk>
    <disk type="block" device="disk">
      <driver name="qemu" type="raw" cache="none" io="native"/>
      <source dev="/dev/sdb"/>
      <target dev="vdb" bus="virtio"/>
      <address type="pci" domain="0x0000" bus="0x06" slot="0x00" function="0x0"/>
    </disk>
    <controller type="usb" index="0" model="qemu-xhci" ports="15">
      <address type="pci" domain="0x0000" bus="0x02" slot="0x00" function="0x0"/>
    </controller>
    <controller type="pci" index="0" model="pcie-root"/>
    <controller type="pci" index="1" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="1" port="0x10"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="2" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="2" port="0x11"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x1"/>
    </controller>
    <controller type="pci" index="3" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="3" port="0x12"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x2"/>
    </controller>
    <controller type="pci" index="4" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="4" port="0x13"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x3"/>
    </controller>
    <controller type="pci" index="5" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="5" port="0x14"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x4"/>
    </controller>
    <controller type="pci" index="6" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="6" port="0x15"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x5"/>
    </controller>
    <controller type="pci" index="7" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="7" port="0x16"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x6"/>
    </controller>
    <controller type="pci" index="8" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="8" port="0x17"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x02" function="0x7"/>
    </controller>
    <controller type="pci" index="9" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="9" port="0x18"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x0" multifunction="on"/>
    </controller>
    <controller type="pci" index="10" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="10" port="0x19"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x1"/>
    </controller>
    <controller type="pci" index="11" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="11" port="0x1a"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x2"/>
    </controller>
    <controller type="pci" index="12" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="12" port="0x1b"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x3"/>
    </controller>
    <controller type="pci" index="13" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="13" port="0x1c"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x4"/>
    </controller>
    <controller type="pci" index="14" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="14" port="0x1d"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x03" function="0x5"/>
    </controller>
    <controller type="pci" index="15" model="pcie-root-port">
      <model name="pcie-root-port"/>
      <target chassis="15" port="0x8"/>
      <address type="pci" domain="0x0000" bus="0x00" slot="0x01" function="0x0"/>
    </controller>
    <controller type="pci" index="16" model="pcie-to-pci-bridge">
      <model name="pcie-pci-bridge"/>
      <address type="pci" domain="0x0000" bus="0x04" slot="0x00" function="0x0"/>
    </controller>
    <controller type="sata" index="0">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1f" function="0x2"/>
    </controller>
    <controller type="virtio-serial" index="0">
      <address type="pci" domain="0x0000" bus="0x03" slot="0x00" function="0x0"/>
    </controller>
    <interface type="network">
      <mac address="52:54:00:fc:89:25"/>
      <source network="default"/>
      <model type="e1000e"/>
      <address type="pci" domain="0x0000" bus="0x01" slot="0x00" function="0x0"/>
    </interface>
    <serial type="pty">
      <target type="isa-serial" port="0">
        <model name="isa-serial"/>
      </target>
    </serial>
    <console type="pty">
      <target type="serial" port="0"/>
    </console>
    <channel type="spicevmc">
      <target type="virtio" name="com.redhat.spice.0"/>
      <address type="virtio-serial" controller="0" bus="0" port="1"/>
    </channel>
    <input type="tablet" bus="usb">
      <address type="usb" bus="0" port="1"/>
    </input>
    <input type="mouse" bus="ps2"/>
    <input type="keyboard" bus="ps2"/>
    <graphics type="spice" autoport="yes">
      <listen type="address"/>
      <image compression="off"/>
    </graphics>
    <sound model="ich9">
      <address type="pci" domain="0x0000" bus="0x00" slot="0x1a" function="0x0"/>
    </sound>
    <audio id="1" type="spice"/>
    <video>
      <model type="none"/>
    </video>
    <hostdev mode="subsystem" type="mdev" managed="no" model="vfio-pci" display="on">
      <source>
        <address uuid="b761f485-1eac-44bc-8ae6-2a3569881a1a"/>
      </source>
      <address type="pci" domain="0x0000" bus="0x05" slot="0x00" function="0x0"/>
    </hostdev>
    <hostdev mode="subsystem" type="usb" managed="yes">
      <source>
        <vendor id="0x258a"/>
        <product id="0x0016"/>
      </source>
      <address type="usb" bus="0" port="5"/>
    </hostdev>
    <redirdev bus="usb" type="spicevmc">
      <address type="usb" bus="0" port="2"/>
    </redirdev>
    <redirdev bus="usb" type="spicevmc">
      <address type="usb" bus="0" port="3"/>
    </redirdev>
    <watchdog model="itco" action="reset"/>
    <memballoon model="none"/>
    <shmem name="looking-glass">
      <model type="ivshmem-plain"/>
      <size unit="M">64</size>
      <address type="pci" domain="0x0000" bus="0x10" slot="0x01" function="0x0"/>
    </shmem>
  </devices>
</domain>
```

### Looking Glass

Looking glass allows VGA PCI Pass-through without an attached physical monitor to view the VM in all its glory.  
Run it with something like `looking-glass-client win:fullScreen spice:alwaysShowCursor` for fullscreen and being able to use the cursor in VM while using a cursor in the host at the same time.

```nix
  environment.systemPackages = with pkgs; [
    looking-glass-client
  ];
```

If you want to make sure your looking glass version won't get updated, you can pin it, this also means that you will have another version of nixpkgs on the system:

```nix
  environment.systemPackages = with pkgs; let
    # Looking glass B6 version in nixpkgs: 
    myLookingGlassPkgs = import (builtins.fetchTarball {
          url = "https://github.com/NixOS/nixpkgs/archive/c0d0be00d4ecc4b51d2d6948e37466194c1e6c51.tar.gz";
          sha256 = "sha256:1yrqrpmrdzbzcwb7kv9m6gbzjk68ljs098fv246brq6mc3s4v5qk";
    }) { inherit (pkgs) system; };
    looking-glass-client-B7-rc1 = myLookingGlassPkgs.looking-glass-client;
  in [
    looking-glass-client-B7-rc1
  ];
```

#### Debug

If it gives a permission error like this:
```
[E]    242844972           ivshmem.c:159  | ivshmemOpenDev                 | Permission denied
```
You can fix it for the current session with `sudo chmod 777 /dev/shm/looking-glass`

If it gives a error like this:
```
Invalid value provided to the option: app:shmFile

 Error: Invalid path to the ivshmem file specified

Valid values are:
```

then `sudo touch /dev/shm/looking-glass` and `sudo chmod 777 /dev/shm/looking-glass` and THEN start the VM. If the VM was already running you'll need to reboot and try to run looking glass before starting the VM. These are accounted for in the `run-vm.sh` script.

### Share folders

The best way I found to share folders is through the network with samba, couldn't make `spice-webdav` work with looking-glass. 

Take a look at the following configuration to realise that:

```nix
  # For sharing folders with the windows VM
  # Make your local IP static for the VM to never lose the folders
  networking.interfaces.eth0.ipv4.addresses = [ {
    address = "192.168.1.109";
    prefixLength = 24;
  } ];
  services.samba-wsdd.enable = true; # make shares visible for windows 10 clients
  networking.firewall.allowedTCPPorts = [
    5357 # wsdd
  ];
  networking.firewall.allowedUDPPorts = [
    3702 # wsdd
  ];
  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = smbnix
      netbios name = smbnix
      security = user 
      #use sendfile = yes
      #max protocol = smb2
      # note: localhost is the ipv6 localhost ::1
      #hosts allow = 192.168.0. 127.0.0.1 localhost
      #hosts deny = 0.0.0.0/0
      guest account = nobody
      map to guest = bad user
    '';
    shares = {
      hdd-ntfs = {
        path = "/mnt/hdd-ntfs";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        #"force user" = "username";
        #"force group" = "groupname";
      };
      DataDisk = {
        path = "/mnt/DataDisk";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        #"force user" = "username";
        #"force group" = "groupname";
      };
    };
  };
  networking.firewall.allowPing = true;
  services.samba.openFirewall = true;
  # However, for this samba share to work you will need to run `sudo smbpasswd -a <yourusername>` after building your configuration! (as stated in the nixOS wiki for samba: https://nixos.wiki/wiki/Samba)
  # In windows you can access them in file explorer with `\\192.168.1.xxx` or whatever your local IP is
  # In Windowos you should also map them to a drive to use them in a lot of programs, for this:
  #   - Add a file MapNetworkDriveDataDisk and MapNetworkDriveHdd-ntfs to the folder C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup (to be accessible to every user in every startup):
  #      With these contents respectively:
  #         net use V: "\\192.168.1.109\DataDisk" /p:yes
  #      and
  #         net use V: "\\192.168.1.109\hdd-ntfs" /p:yes
  # Then to have those drives be usable by administrator programs, open a cmd with priviliges and also run both commands above! This might be needed if you want to for example install a game in them, see this reddit post: https://www.reddit.com/r/uplay/comments/tww5ey/any_way_to_install_games_to_a_network_drive/
  # You can make them always be mounted with admin too, through the Task Schedueler > New Task > Tick "Run as admin" and add the path to the script as a program (could be the one in C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup)
```

As explained in the comments in the above code you'll have to mount the network drives in windows.

I also advise you to make your local IP static, to prevent windows from loosing access to those folder because of IP changes:

```nix
  # This doesnt work if the network is being managed by networkmanager, you can make a static ip with the gui or figure out how to manage networkmanager declaritivley
  networking.interfaces.eth0.ipv4.addresses = [ {
    address = "192.168.1.109";
    prefixLength = 24;
  } ];
```
