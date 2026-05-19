{
  lib,
  flake,
  rustPlatform,
  fetchCrate,
}:

rustPlatform.buildRustPackage rec {
  pname = "toon-format";
  version = "0.4.6";

  src = fetchCrate {
    inherit pname version;
    hash = "sha256-QHrpg3EzAeDLzzVnQqQOYXCmAzBlWVKBMtlL02Arung=";
  };

  cargoHash = "sha256-x9LT/diIN6DSEbJE+QcmtScxUwnKAhsBZXy6q8LTK3w=";

  cargoBuildFlags = [
    "--features"
    "cli"
  ];

  doCheck = false;

  passthru.category = "Utilities";

  meta = with lib; {
    description = "Rust implementation of TOON - Token-Oriented Object Notation for LLM prompts";
    homepage = "https://github.com/toon-format/toon-rust";
    changelog = "https://github.com/toon-format/toon-rust/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ antono ];
    mainProgram = "toon";
    platforms = platforms.all;
  };
}
