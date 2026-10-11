#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(dirname "$script_dir")"
manifest="$script_dir/com.felipesam.sincronizador_pdf.yml"
build_dir="$script_dir/.flatpak-builder-build"

(cd "$app_dir" && flutter build linux --release)

flatpak run org.flatpak.Builder \
  --user \
  --install \
  --force-clean \
  "$build_dir" \
  "$manifest"
