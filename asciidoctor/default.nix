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
  name = "asciidoctor";
  pname = null;
  version = "0.0.0";

  gemdir = ./.;

  extraConfigPaths = [
    "${./.}/prawn"
    "${./.}/asciidoctor-pdf"
    "${./.}/asciidoctor"
  ];

  exes = [
    "asciidoctor"
    "asciidoctor-epub3"
    "asciidoctor-multipage"
    "asciidoctor-pdf"
    "asciidoctor-reducer"
    "asciidoctor-revealjs"
  ];

  installManpages = false;

  nativeBuildInputs = [ makeWrapper ];

  postBuild = lib.optionalString (path != "") (
    lib.concatMapStrings (exe: ''
      wrapProgram $out/bin/${exe} \
        --prefix PATH : ${path}
    '') exes
  );
}
