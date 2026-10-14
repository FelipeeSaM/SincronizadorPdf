#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(dirname "$script_dir")"
repo_dir="$(dirname "$app_dir")"
manifest="$script_dir/com.felipesam.sincronizador_pdf.yml"
build_dir="$script_dir/.flatpak-builder-build"
bundle_dir="$app_dir/build/linux/x64/release/bundle"

(cd "$app_dir" && toolbox run -c sincronizador-pdf-build flutter build linux --release)

# Publica o Backend como executável self-contained (sem depender de `dotnet`
# instalado na máquina do usuário) dentro do bundle do Flutter, dentro de
# `backend/` — o manifesto do Flatpak já copia o bundle inteiro para
# `/app/bin/`, então isso basta para o app desktop achar e iniciar o Backend
# local sozinho (ver #24, #31), sem mudar o manifesto.
dotnet publish "$repo_dir/backend/src/SincronizadorPdf.Backend.Api" \
  -c Release \
  -r linux-x64 \
  --self-contained true \
  -o "$bundle_dir/backend"

flatpak run org.flatpak.Builder \
  --user \
  --install \
  --force-clean \
  "$build_dir" \
  "$manifest"
