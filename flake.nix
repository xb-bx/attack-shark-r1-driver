{
  description = "Linux driver for Attack Shark R1 mouse";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }:
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages.default = pkgs.stdenv.mkDerivation {
          pname = "attack-shark-r1-driver";
          version = "1.0.0";

          src = ./.;

          buildInputs = with pkgs; [ libusb1 ];

          nativeBuildInputs = with pkgs; [
            odin
          ];

          dontConfigure = true;

          buildPhase = ''
            runHook preBuild
            
            odin build . -o:speed -out:attack-shark-r1-driver

            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            
            mkdir -p $out/bin
            cp attack-shark-r1-driver $out/bin/
            mkdir -p $out/etc/udev/rules.d
            cp ./99-attack-shark-r1.rules  $out/etc/udev/rules.d

            runHook postInstall
          '';
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            odin
            ols 
            libusb1
            gnumake
          ];
        };
      }
    );
}
