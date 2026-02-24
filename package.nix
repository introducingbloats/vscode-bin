{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,

  libgcc,
  glib,
  nspr,
  nss,
  dbus,
  at-spi2-atk,
  cups,
  cairo,
  gtk3,
  pango,
  libxcomposite,
  libxdamage,
  libxfixes,
  libxrandr,
  libgbm,
  libxkbcommon,
  alsa-lib,
  curl,
  openssl,
  webkitgtk_4_1,
  libsoup_3,
  xorg,
  libsecret,
  libxkbfile,
  util-linux,
  channel ? "stable",
}:
let
  versions = lib.importJSON ./version.json;
  currentVersion = versions.${channel};
  downloadUrl =
    platform: "https://update.code.visualstudio.com/${currentVersion.version}/${platform}/${channel}";
  pname = "vscode-bin-${channel}";
  defaultArgs =
    {
      "x86_64-linux" = {
        src = fetchurl {
          url = downloadUrl "linux-x64";
          hash = currentVersion."hash-linux-x64";
          name = "vscode-${channel}-${currentVersion.version}-linux-x64.tar.gz";
        };
      };
      "aarch64-linux" = {
        src = fetchurl {
          url = downloadUrl "linux-arm64";
          hash = currentVersion."hash-linux-arm64";
          name = "vscode-${channel}-${currentVersion.version}-linux-arm64.tar.gz";
        };
      };
    }
    .${stdenv.hostPlatform.system}
      or (throw "vscode-bin: Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation (finalAttrs: {
  inherit pname;
  version = currentVersion.version;
  inherit (defaultArgs) src;

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    libgcc
    glib
    nspr
    nss
    dbus
    at-spi2-atk
    cups
    cairo
    gtk3
    pango
    libxcomposite
    libxdamage
    libxfixes
    libxrandr
    libgbm
    libxkbcommon
    alsa-lib
    xorg.libX11
    xorg.libxcb
    xorg.libXext
    libsecret
    libxkbfile
    curl
    openssl
    webkitgtk_4_1
    libsoup_3
    util-linux
  ];

  dontBuild = true;
  dontConfigure = true;
  noDumpEnvVars = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    # The tarball extracts to a VSCode-linux-* or VSCode-Insiders-linux-* directory
    cp -r VSCode-*/* $out/ 2>/dev/null || cp -r * $out/
    runHook postInstall
  '';

  meta = {
    description = "Visual Studio Code${
      lib.optionalString (channel == "insider") " Insiders"
    } - Code editing. Redefined.";
    homepage = "https://code.visualstudio.com";
    license = lib.licenses.unfreeRedistributable;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = if channel == "insider" then "code-insiders" else "code";
  };
})
