{
  inputs.nixpkgs.url = "github:Anillc/nixpkgs/gem-path";
  inputs.nix2container.url = "github:nlewo/nix2container";
  outputs = inputs@{
    self, nixpkgs, flake-parts, nix2container,
  }: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = [ "x86_64-linux" ];
    perSystem = { self', pkgs, system, ... }: let
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
      n2c = nix2container.packages.${system}.nix2container;
      target = [ asciidoctor pkgs.nodePackages.wavedrom-cli pkgs.gnumake ];
    in {
      packages.default = asciidoctor;
      packages.docker = n2c.buildImage {
        name = "asciidoctor";
        tag = "latest";
        copyToRoot = pkgs.buildEnv {
          name = "image-root";
          # pathsToLink = [ "/bin" ];
          paths = [ pkgs.busybox ] ++ target;
        };
      };
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [];
        nativeBuildInputs = with pkgs; [ gen ] ++ subtrees ++ target;
        shellHook = ''
          export SHELL_PATH=$PWD
        '';
      };
    };
  };
}
