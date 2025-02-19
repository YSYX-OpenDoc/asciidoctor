{
  inputs.nixpkgs.url = "github:Anillc/nixpkgs/gem-path";
  outputs = inputs@{
    self, nixpkgs, flake-parts,
  }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    perSystem = { pkgs, self', ... }: let
      asciidoctor = pkgs.callPackage ./asciidoctor {};
      gen = pkgs.writeScriptBin "gen" ''
        #!${pkgs.runtimeShell}
        export PATH=$PATH:${pkgs.lib.makeBinPath (with pkgs; [ ruby bundix ])}
        cd $SHELL_PATH/asciidoctor
        bundle lock --update prawn
        bundix
      '';
      subtrees = map (name: pkgs.writeScriptBin "${name}-subtree" ''
        #!${pkgs.runtimeShell}
        export PATH=$PATH:${pkgs.lib.makeBinPath (with pkgs; [ git ])}
        cd $SHELL_PATH
        git subtree --prefix=asciidoctor/${name} "$@"
      '') [ "prawn" "asciidoctor-pdf" ];
    in {
      packages.default = asciidoctor;
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [];
        nativeBuildInputs = with pkgs; [
          asciidoctor gen
          nodePackages.wavedrom-cli
        ] ++ subtrees;
        shellHook = ''
          export SHELL_PATH=$PWD
        '';
      };
    };
  };
}
