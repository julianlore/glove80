# Based off https://github.com/GaetanLepage/glove80-zmk-config with some modifications
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    glove80-zmk = {
      # Fork supporting per layer RGB
      url = "github:darknao/zmk/rgb-layer-24.12";
      flake = false;
    };
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, glove80-zmk, flake-parts, devshell }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = nixpkgs.lib.systems.flakeExposed;
      imports = [ inputs.devshell.flakeModule ];

      perSystem = { config, pkgs, ... }: {
        packages.default = let
          firmware = import glove80-zmk { inherit pkgs; };

          keymap = ./glove80.keymap;

          glove80_left = firmware.zmk.override {
            board = "glove80_lh";
            inherit keymap;
          };

          glove80_right = firmware.zmk.override {
            board = "glove80_rh";
            inherit keymap;
          };
        in firmware.combine_uf2 glove80_left glove80_right;

        devshells.default.commands = [{
          name = "flash";
          command = ''
            set +e

            root="/run/media/$(whoami)"
            # Redirect ls stderr to null as /run/media won't exist if nothing is mounted
            dest_folder_name=$(ls $root 2> /dev/null | grep GLV80)

            if [ -n "$dest_folder_name" ]; then
              cp ${config.packages.default}/glove80.uf2 "$root"/"$dest_folder_name"/CURRENT.UF2
              exit 0
            fi

            echo "Waiting for Glove80 to be mounted in bootloader mode..."
            while :; do
              sleep 1
              dest_folder_name=$(ls $root 2> /dev/null | grep GLV80)
              if [ -n "$dest_folder_name" ]; then
                cp ${config.packages.default}/glove80.uf2 "$root"/"$dest_folder_name"/CURRENT.UF2
                exit 0
              fi
            done
          '';
          help =
            "Builds the firmware and copies it to the plugged-in keyboard half.";
        }];
      };
    };
}
