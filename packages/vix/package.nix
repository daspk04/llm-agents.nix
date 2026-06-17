{
  lib,
  fetchFromGitHub,
  buildGoModule,
  versionCheckHook,
  pkg-config,
}:

buildGoModule rec {
  pname = "vix";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "get-vix";
    repo = "vix";
    rev = "v${version}";
    hash = "sha256-dlW07swW66Qkc7K0Ugt+dyqJnHE4cKiPOXIlEkAqiO8=";
  };

  # source already has vendor folder, so we set 'vendorHash = null;'
  vendorHash = null;

  subPackages = [
    "cmd/vix"
    "cmd/vixd"
  ];

  nativeBuildInputs = [ pkg-config ];

  # llamacpp endpoint: set LLAMACPP_BASE_URL at runtime (defaults to http://localhost:8080/v1 per upstream providers.json / interp.go).
  # Allow plain HTTP for non-loopback hosts when LLAMACPP_BASE_URL points at LAN llama.cpp (upstream checkURL otherwise rejects).
  postPatch = ''
    substituteInPlace internal/providers/validate.go \
      --replace-fail 'if !(allowLoopbackHTTP && isLoopback(host)) {' 'if false && !(allowLoopbackHTTP && isLoopback(host)) {'
  '';

  ldflags = [
    "-s"
    "-w"
    "-X main.Version=${version}"
    "-X github.com/get-vix/vix/internal/ui.Version=${version}"
  ];

  doCheck = true;
  doInstallCheck = true;

  nativeInstallCheckInputs = [
    versionCheckHook
  ];

  passthru.category = "AI Coding Agents";

  meta = with lib; {
    description = "Sleek, Fast and Token Efficient AI Coding Agent";
    homepage = "https://github.com/get-vix/vix";
    changelog = "https://github.com/get-vix/vix/releases/tag/v${version}";
    license = licenses.agpl3Only;
    maintainers = with lib.maintainers; [ daspk04 ];
    mainProgram = "vix";
    platforms = platforms.linux ++ platforms.darwin;
  };
}
