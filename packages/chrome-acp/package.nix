{
  lib,
  buildNpmPackage,
  fetchurl,
  fetchNpmDepsWithPackuments,
  npmConfigHook,
  nodejs,
  jq,
  runCommand,
  versionCheckHook,
  versionCheckHomeHook,
}:

let
  versionData = lib.importJSON ./hashes.json;
  version = versionData.version;
  # Create a source with package-lock.json included and dev/peer deps stripped
  srcWithLock = runCommand "chrome-acp-src-with-lock" { nativeBuildInputs = [ jq ]; } ''
    mkdir -p $out
    tar -xzf ${
      fetchurl {
        url = "https://registry.npmjs.org/@chrome-acp/proxy-server/-/proxy-server-${version}.tgz";
        hash = versionData.sourceHash;
      }
    } -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
    # Strip devDependencies and peerDependencies so npm doesn't try to resolve
    # @types/node or typescript.  But add zod as a regular dependency — it's a
    # runtime peer dep of @agentclientprotocol/sdk and npm won't auto-install it.
    jq 'del(.devDependencies, .peerDependencies) | .dependencies["zod"] = "4.3.6"' \
      $out/package.json > $out/package.json.tmp
    mv $out/package.json.tmp $out/package.json
  '';
in
buildNpmPackage rec {
  inherit npmConfigHook nodejs;
  pname = "chrome-acp";
  inherit version;

  src = srcWithLock;

  npmDeps = fetchNpmDepsWithPackuments {
    inherit src;
    name = "${pname}-${version}-npm-deps";
    hash = versionData.npmDepsHash;
    fetcherVersion = 2;
  };

  makeCacheWritable = true;

  npmInstallFlags = [ "--ignore-scripts" ];
  npmRebuildFlags = [ "--ignore-scripts" ];

  # The package from npm is already built
  dontNpmBuild = true;

  # Use environment variables to forcefully disable all scripts
  NPM_CONFIG_IGNORE_SCRIPTS = "true";
  NPM_CONFIG_LEGACY_PEER_DEPS = "true";

  doInstallCheck = true;
  nativeInstallCheckInputs = [
    versionCheckHook
    versionCheckHomeHook
  ];

  passthru.category = "ACP Ecosystem";

  meta = with lib; {
    description = "Chrome extension and proxy server to connect ACP agents to your browser";
    homepage = "https://github.com/Areo-Joe/chrome-acp";
    downloadPage = "https://www.npmjs.com/package/@chrome-acp/proxy-server";
    changelog = "https://github.com/Areo-Joe/chrome-acp/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [ binaryBytecode ];
    maintainers = with lib.maintainers; [ daspk04 ];
    mainProgram = "acp-proxy";
    platforms = platforms.all;
  };
}
