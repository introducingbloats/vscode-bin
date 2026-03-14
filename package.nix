{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  copyDesktopItems,
  makeDesktopItem,
  installShellFiles,

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
  mainBin = if channel == "insider" then "code-insiders" else "code";

  # For insider: always re-download with builtins.fetchTarball (impure, no hash)
  # since Microsoft's CDN breaks hashing randomly for insider builds.
  # For stable: use fetchurl with a pinned hash as usual.
  mkSrc =
    platform: hashKey:
    if channel == "insider" then
      builtins.fetchTarball {
        url = downloadUrl platform;
      }
    else
      fetchurl {
        url = downloadUrl platform;
        hash = currentVersion.${hashKey};
        name = "vscode-${channel}-${currentVersion.version}-${platform}.tar.gz";
      };

  defaultArgs =
    {
      "x86_64-linux" = {
        src = mkSrc "linux-x64" "hash-linux-x64";
      };
      "aarch64-linux" = {
        src = mkSrc "linux-arm64" "hash-linux-arm64";
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
    copyDesktopItems
    installShellFiles
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
    mkdir -p $out/bin $out/share

    # The tarball extracts to a VSCode-linux-* or VSCode-Insiders-linux-* directory
    cp -r VSCode-*/* $out/ 2>/dev/null || cp -r * $out/

    # Install icon
    if [ -f "$out/resources/app/resources/linux/code.png" ]; then
      install -Dm644 "$out/resources/app/resources/linux/code.png" \
        "$out/share/icons/hicolor/512x512/apps/${mainBin}.png"
    fi

    # Install shell completions
    if [ -f "$out/resources/completions/bash/code" ]; then
      installShellCompletion --bash --name ${mainBin} "$out/resources/completions/bash/code"
    fi
    if [ -f "$out/resources/completions/zsh/_code" ]; then
      installShellCompletion --zsh --name _${mainBin} "$out/resources/completions/zsh/_code"
    fi
    if [ -f "$out/resources/completions/fish/code.fish" ]; then
      installShellCompletion --fish --name ${mainBin}.fish "$out/resources/completions/fish/code.fish"
    fi

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = mainBin;
      desktopName = "Visual Studio Code${lib.optionalString (channel == "insider") " - Insiders"}";
      exec = "${mainBin} %F";
      icon = mainBin;
      comment = "Code editing. Redefined.";
      categories = [ "Utility" "TextEditor" "Development" "IDE" ];
      startupWMClass = if channel == "insider" then "Code - Insiders" else "Code";
      mimeTypes = [
        "text/plain"
        "inode/directory"
        "x-scheme-handler/vscode${lib.optionalString (channel == "insider") "-insiders"}"
      ];
      startupNotify = true;
      keywords = [ "vscode" ];
    })
  ];

  meta = {
    description = "Visual Studio Code${
      lib.optionalString (channel == "insider") " Insiders"
    } - Code editing. Redefined.";
    homepage = "https://code.visualstudio.com";
    license = lib.licenses.unfreeRedistributable;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = lib.platforms.linux;
    mainProgram = mainBin;
  };
})
