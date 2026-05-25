{
  pkgs,
  lib,
  flake,
  versionCheckHook,
  versionCheckHomeHook,
  ...
}:
pkgs.buildNpmPackage rec {
  pname = "reasonix";
  version = "0.49.0";

  src = pkgs.fetchFromGitHub {
    owner = "esengine";
    repo = "DeepSeek-Reasonix";
    rev = "v${version}";
    hash = "sha256-msfAkLH/yReZiun6MCqNxcFRfnlVdWmHo6bofz1FBSA=";
  };

  npmDeps = pkgs.importNpmLock {
    npmRoot = src;
  };

  npmConfigHook = pkgs.importNpmLock.npmConfigHook;

  # Skip node-gyp rebuild of dev-only tree-sitter-typescript native addon;
  # runtime uses web-tree-sitter (WASM) instead.
  npmFlags = [ "--ignore-scripts" ];

  dontCheckForBrokenSymlinks = true;

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  meta = {
    description = "DeepSeek-native AI coding agent for your terminal";
    homepage = "https://github.com/esengine/DeepSeek-Reasonix";
    license = lib.licenses.mit;
    changelog = "https://github.com/esengine/DeepSeek-Reasonix/releases/tag/v${version}";
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with flake.lib.maintainers; [ arch-fan ];
    mainProgram = "reasonix";
    platforms = lib.platforms.unix;
  };

  passthru = {
    category = "AI Coding Agents";
  };
}
