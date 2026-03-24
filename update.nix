{
  lib,
  writeShellApplication,
  jq,
  coreutils,
  curl,
}:
let
  constants = lib.importJSON ./constants.json;
in
writeShellApplication {
  name = "vscode-bin-update";
  runtimeInputs = [
    jq
    coreutils
    curl
  ];
  text = ''
    set -euo pipefail

    update_channel() {
      local CHANNEL="$1"
      local API_RELEASES="$2"

      echo "=== Updating $CHANNEL channel ==="

      RELEASES=$(curl -sL "$API_RELEASES")
      VERSION=$(echo "$RELEASES" | jq -r '.[0]')
      echo "Latest $CHANNEL version: $VERSION"

      echo "Fetching update info for x86_64-linux"
      X64_INFO=$(curl -sL "${constants.api_update}/linux-x64/$CHANNEL/latest")
      COMMIT=$(echo "$X64_INFO" | jq -r '.version')
      X64_URL=$(echo "$X64_INFO" | jq -r '.url')
      echo "Commit: $COMMIT"

      echo "Fetching x86_64-linux tarball and calculating hash"
      X64_HASH=$(nix store prefetch-file --json "$X64_URL" | jq -r '.hash')
      echo "$CHANNEL x86_64-linux hash: $X64_HASH"

      echo "Fetching update info for aarch64-linux"
      ARM64_INFO=$(curl -sL "${constants.api_update}/linux-arm64/$CHANNEL/latest")
      ARM64_URL=$(echo "$ARM64_INFO" | jq -r '.url')

      echo "Fetching aarch64-linux tarball and calculating hash"
      ARM64_HASH=$(nix store prefetch-file --json "$ARM64_URL" | jq -r '.hash')
      echo "$CHANNEL aarch64-linux hash: $ARM64_HASH"

      CURRENT_X64_HASH=$(jq -r ".$CHANNEL.\"hash-linux-x64\"" version.json)
      CURRENT_ARM64_HASH=$(jq -r ".$CHANNEL.\"hash-linux-arm64\"" version.json)
      if [ "$X64_HASH" = "$CURRENT_X64_HASH" ] && [ "$ARM64_HASH" = "$CURRENT_ARM64_HASH" ]; then
        echo "$CHANNEL hashes unchanged, skipping update"
        return 0
      fi

      jq --arg channel "$CHANNEL" \
         --arg version "$VERSION" \
         --arg commit "$COMMIT" \
         --arg hash_linux_x64 "$X64_HASH" \
         --arg hash_linux_arm64 "$ARM64_HASH" \
         '.[$channel].version = $version |
          .[$channel].commit = $commit |
          .[$channel]."hash-linux-x64" = $hash_linux_x64 |
          .[$channel]."hash-linux-arm64" = $hash_linux_arm64' \
         version.json > version.json.tmp
      mv version.json.tmp version.json
      echo "done updating $CHANNEL"
    }

    update_channel "stable" "${constants.api_releases_stable}"
    update_channel "insider" "${constants.api_releases_insider}"

    echo "All channels updated"
  '';
}
