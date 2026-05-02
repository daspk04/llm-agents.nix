{
  lib,
  stdenv,
  bun2nix,
  bun,
  fetchFromGitHub,
  jq,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = builtins.fromJSON (builtins.readFile ./hashes.json);
  inherit (versionData) version hash;
in
stdenv.mkDerivation rec {
  pname = "ccs";
  inherit version;

  src = fetchFromGitHub {
    owner = "kaitranntt";
    repo = "ccs";
    rev = "v${version}";
    inherit hash;
  };

  nativeBuildInputs = [
    bun2nix.hook
    bun
  ];

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = ./bun.nix;
  };

  # We handle build and install ourselves
  dontUseBunBuild = true;
  dontUseBunInstall = true;
  dontRunLifecycleScripts = true;

  patches = [
    ./fix-stale-bun-lock.patch
  ];

  postPatch = ''
    sed -i 's/payload = decompressPayload(payload, flags);/payload = decompressPayload(payload as any, flags) as any;/' src/cursor/cursor-executor.ts src/cursor/cursor-stream-parser.ts
    sed -i 's/normalizedEntryId.split('"'"':'"'"').at(-1)/normalizedEntryId.split('"'"':'"'"').slice(-1)[0]/' src/cliproxy/ai-providers/service.ts
    sed -i 's/log(`Watcher error: ''${error.message}`);/log(`Watcher error: ''${(error as any).message}`);/' src/cliproxy/sync/auto-sync-watcher.ts

    if [ -f ui/tsconfig.app.json ]; then
      ${lib.getExe jq} '
        del(.compilerOptions.erasableSyntaxOnly) |
        del(.compilerOptions.noUncheckedSideEffectImports)
      ' ui/tsconfig.app.json > ui/tsconfig.app.json.tmp && mv ui/tsconfig.app.json.tmp ui/tsconfig.app.json
    fi

    if [ -f ui/tsconfig.node.json ]; then
      ${lib.getExe jq} '
        del(.compilerOptions.erasableSyntaxOnly) |
        del(.compilerOptions.noUncheckedSideEffectImports) |
        .compilerOptions.target = "ES2022"
      ' ui/tsconfig.node.json > ui/tsconfig.node.json.tmp && mv ui/tsconfig.node.json.tmp ui/tsconfig.node.json
    fi

    ${lib.getExe jq} '
      if .dependencies    then .dependencies    |= with_entries(.value |= ltrimstr("^") | .value |= ltrimstr("~")) else . end |
      if .devDependencies then .devDependencies |= with_entries(.value |= ltrimstr("^") | .value |= ltrimstr("~")) else . end
    ' package.json > package.json.tmp && mv package.json.tmp package.json

    sed -i 's/: "\^/: "/g; s/: "~/: "/g' bun.lock
  '';

  buildPhase = ''
    runHook preBuild
    bun run build:all
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/lib/ccs

    cp -r dist $out/lib/ccs/
    cp package.json $out/lib/ccs/
    cp -a node_modules $out/lib/ccs/

    # Ensure all binaries in dist and dist/bin have the correct shebang
    find $out/lib/ccs/dist -name "*.js" -type f -exec chmod +x {} +

    # Replace shebangs with bun
    find $out/lib/ccs/dist -name "*.js" -type f -exec sed -i "1s|^#!/usr/bin/env node|#!${bun}/bin/bun|" {} +
    find $out/lib/ccs/dist -name "*.js" -type f -exec sed -i "1s|^#!/usr/bin/node|#!${bun}/bin/bun|" {} +

    ln -s $out/lib/ccs/dist/ccs.js $out/bin/ccs
    ln -s $out/lib/ccs/dist/bin/droid-runtime.js $out/bin/ccs-droid
    ln -s $out/lib/ccs/dist/bin/droid-runtime.js $out/bin/ccsd
    ln -s $out/lib/ccs/dist/bin/codex-runtime.js $out/bin/ccs-codex
    ln -s $out/lib/ccs/dist/bin/codex-runtime.js $out/bin/ccsx

    runHook postInstall
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "Claude Code Ecosystem";

  meta = with lib; {
    description = "Switch between Claude accounts, Gemini, Copilot, OpenRouter (300+ models) via CLIProxyAPI OAuth proxy";
    homepage = "https://github.com/kaitranntt/ccs";
    changelog = "https://github.com/kaitranntt/ccs/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    maintainers = with maintainers; [ ];
    mainProgram = "ccs";
    platforms = platforms.all;
  };
}
