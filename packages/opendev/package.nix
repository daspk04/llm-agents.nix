{
  lib,
  rustPlatform,
  fetchFromGitHub,
  fetchurl,
  pkg-config,
  openssl,
  stdenv,
  darwin,
  dbus,
  versionCheckHook,
}:

let
  # opendev uses microsandbox which downloads agentd during build.
  # We pre-fetch it to satisfy the Nix sandbox.
  # https://github.com/zerocore-ai/microsandbox/releases/download/v0.3.1/agentd-x86_64
  agentd-x86_64 = fetchurl {
    url = "https://github.com/zerocore-ai/microsandbox/releases/download/v0.3.1/agentd-x86_64";
    hash = "sha256-Sd0FZynSPHL1M6gFcSqHrfO+9DO61iyKEYIVI/tabD0=";
  };
in
rustPlatform.buildRustPackage rec {
  pname = "opendev";
  version = "0.1.8";

  src = fetchFromGitHub {
    owner = "opendev-to";
    repo = "opendev";
    tag = "v${version}";
    hash = "sha256-v61AVb56K50okXsiAFuzJz5WU5ZcD97jXrTdbddlyLQ=";
  };

  cargoHash = "sha256-Bez4/In5EvEjp0t+yxKdrutOmoyJOkm5UPcOA6N7MDE=";

  # We can't use cargoPatches for vendored crates easily.
  # Instead, we patch the build script in the vendor directory after it's unpacked.
  preBuild = lib.optionalString stdenv.hostPlatform.isLinux ''
    # Find the vendored microsandbox-filesystem
    MSB_FS_DIR=$(find .. -name "microsandbox-filesystem-*" -type d | head -n 1)
    MSB_FS_BUILD_RS="$MSB_FS_DIR/build.rs"
    if [ -f "$MSB_FS_BUILD_RS" ]; then
      echo "Patching $MSB_FS_BUILD_RS"
      chmod +w "$MSB_FS_BUILD_RS"
      # The build script expects the file to be named "agentd" in OUT_DIR (based on AGENTD_BINARY in microsandbox-utils)
      # microsandbox-utils defines AGENTD_BINARY as "agentd"
      sed -i '/fn main() {/a \    let out_dir = std::path::PathBuf::from(std::env::var("OUT_DIR").unwrap()); let dest = out_dir.join("agentd"); if let Ok(agentd_path) = std::env::var("AGENTD_BIN") { std::fs::copy(&agentd_path, &dest).expect("failed to copy agentd to OUT_DIR"); return; }' "$MSB_FS_BUILD_RS"
    fi
  '';

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    openssl
    dbus
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    darwin.apple_sdk.frameworks.Security
    darwin.apple_sdk.frameworks.SystemConfiguration
  ];

  AGENTD_BIN = lib.optionalString stdenv.hostPlatform.isLinux "${agentd-x86_64}";

  # Some tests might require network or specific environment
  # doCheck = false;

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Open-source AI coding agent that spawns parallel agents";
    homepage = "https://github.com/opendev-to/opendev";
    changelog = "https://github.com/opendev-to/opendev/releases/tag/v${version}";
    license = licenses.mit;
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode # for the pre-fetched agentd
    ];
    maintainers = with lib.maintainers; [ ];
    mainProgram = "opendev";
    platforms = platforms.all;
  };
}
