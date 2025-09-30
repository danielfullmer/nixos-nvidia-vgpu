{ lib
, rustPlatform
, fetchCrate
, docutils
, installShellFiles
, bash
}:

rustPlatform.buildRustPackage rec {
  pname = "mdevctl";
  version = "1.2.0";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-0X/3DWNDPOgSNNTqcj44sd7DNGFt+uGBjkc876dSgU8=";
  };

  cargoHash = "sha256-TmumQBWuH5fJOe2qzcDtEGbmCs2G9Gfl8mH7xifzRGc=";

  nativeBuildInputs = [
    docutils
    installShellFiles
  ];

  # had to add this
  doCheck = false;
  postPatch = ''
    substituteInPlace 60-mdevctl.rules \
      --replace /usr/sbin/ $out/ \
      --replace /bin/sh ${bash}/bin/sh
  '';

  postInstall = ''
    ln -s mdevctl $out/bin/lsmdev

    install -Dm444 60-mdevctl.rules -t $out/lib/udev/rules.d

    installManPage $releaseDir/build/mdevctl-*/out/mdevctl.8
    ln -s mdevctl.8 $out/share/man/man8/lsmdev.8

    installShellCompletion $releaseDir/build/mdevctl-*/out/{lsmdev,mdevctl}.bash
  '';

  meta = with lib; {
    homepage = "https://github.com/mdevctl/mdevctl";
    description = "A mediated device management utility for linux";
    license = licenses.lgpl21Only;
    maintainers = with maintainers; [ edwtjo ];
    platforms = platforms.linux;
  };
}

/* { lib, stdenv, fetchFromGitHub, makeWrapper, bash, getopt, jq }:

stdenv.mkDerivation rec {
  name = "mdevctl";
  version = "0.78";

  src = fetchFromGitHub {
    owner = name;
    repo = name;
    rev = version;
    sha256 = "0crrsixs0pc3kj7gmg8p5kaxjp35dlal7pwal0h7wddpc0nsq3ql";
  };

  nativeBuildInputs = [ makeWrapper ];

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

    wrapProgram $out/bin/mdevctl  --prefix PATH : ${lib.makeBinPath [ getopt jq ]}
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
*/