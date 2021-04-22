{ lib, stdenv, fetchFromGitHub, bash, jq }:

stdenv.mkDerivation rec {
  name = "mdevctl";
  version = "0.78";

  src = fetchFromGitHub {
    owner = name;
    repo = name;
    rev = version;
    sha256 = "0crrsixs0pc3kj7gmg8p5kaxjp35dlal7pwal0h7wddpc0nsq3ql";
  };
  
  buildInputs = [ jq ];

  postPatch = ''
    substituteInPlace 60-mdevctl.rules \
      --replace /usr/sbin/ $out/ \
      --replace /bin/sh ${bash}/bin/sh
  '';

  installPhase = ''
    install -Dm755 mdevctl $out/bin/mdevctl
    install -Dm644 60-mdevctl.rules $out/lib/udev/rules.d/60-mdevctl.rules
    install -Dm644 mdevctl.8 $out/share/man8/mdevctl.8
    ln -s $out/share/man8/mdevctl.8 $out/share/man8/lsmdev.8
  '';

  meta = with lib; {
    description = "A mediated device management and persistence utility";
    longDescription = ''
      mdevctl is a utility for managing and persisting devices in the mediated
      device device framework of the Linux kernel. Mediated devices are
      sub-devices of a parent device (ex. a vGPU) which can be dynamically
      created and potentially used by drivers like vfio-mdev for assignment to
      virtual machines.
    '';
    homepage = "https://github.com/mdevctl/mdevctl";
    license = licenses.lgpl21;
    maintainers = [ maintainers.danielfullmer ];
    platforms = platforms.linux;
  };
}
