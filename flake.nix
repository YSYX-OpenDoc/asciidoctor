{
  inputs.nixpkgs.url = "github:Anillc/nixpkgs/gem-path";
  outputs = inputs@{
    self, nixpkgs, flake-parts,
  }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    perSystem = { pkgs, ... }: let
      asciidoctor = pkgs.callPackage ./asciidoctor {};
      gen = pkgs.writeScriptBin "gen" ''
        #!${pkgs.runtimeShell}
        export PATH=$PATH:${pkgs.lib.makeBinPath (with pkgs; [ ruby bundix ])}
        cd $MANUAL_PATH/asciidoctor
        bundle lock --update prawn
        bundix
      '';
      prawn-subtree = pkgs.writeScriptBin "prawn-subtree" ''
        #!${pkgs.runtimeShell}
        export PATH=$PATH:${pkgs.lib.makeBinPath (with pkgs; [ git ])}
        cd $MANUAL_PATH
        git subtree --prefix=asciidoctor/prawn "$@"
      '';
    in {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [];
        nativeBuildInputs = with pkgs; [
          asciidoctor gen prawn-subtree
          nodePackages.wavedrom-cli
        ];
        shellHook = ''
          export MANUAL_PATH=$PWD
        '';
      };
    };
  };
}
