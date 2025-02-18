{
  lib,
  bundlerApp,
  makeWrapper,
  withJava ? true,
  jre, # Used by asciidoctor-diagram for ditaa and PlantUML
  ...
}:

let
  path = lib.makeBinPath (lib.optional withJava jre);
in
bundlerApp rec {
  pname = "asciidoctor";
  gemdir = ./.;

  extraConfigPaths = [ "${./.}/prawn" ];

  exes = [
    "asciidoctor"
    "asciidoctor-epub3"
    "asciidoctor-multipage"
    "asciidoctor-pdf"
    "asciidoctor-reducer"
    "asciidoctor-revealjs"
  ];

  nativeBuildInputs = [ makeWrapper ];

  postBuild = lib.optionalString (path != "") (
    lib.concatMapStrings (exe: ''
      wrapProgram $out/bin/${exe} \
        --prefix PATH : ${path}
    '') exes
  );
}
