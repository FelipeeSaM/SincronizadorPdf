# Empacotamento Flatpak

Manifesto e pipeline que produzem um pacote Flatpak instalável do app desktop, a partir do build Linux do Flutter (ver ADR-0004).

## Build local (requer o bundle Linux do Flutter já compilado)

```sh
./build.sh
```

Isso roda, em sequência: (1) `flutter build linux --release` dentro do toolbox `sincronizador-pdf-build` (necessário em sistemas imutáveis como Bazzite, que não tem `cmake`/`gtk3-devel` no host); (2) `dotnet publish` do Backend como executável **self-contained** para `linux-x64`, direto no host, dentro de `bundle/backend/` (ver ADR-0007, #31) — não precisa de `dotnet` instalado na máquina de quem só for *usar* o pacote; (3) `flatpak run org.flatpak.Builder -- --user --install --force-clean` no host, usando `com.felipesam.sincronizador_pdf.yml`, que copia o bundle inteiro (app + `backend/`) para `/app/bin/`. Ao final, o pacote fica instalado para o usuário atual (`flatpak run com.felipesam.sincronizador_pdf`) e já sobe o Backend local sozinho, sem configuração manual.

Dependências de build:

- No toolbox `sincronizador-pdf-build`: `cmake`, `ninja`, `gtk3-devel`, um compilador C/C++.
- No host: [.NET SDK 10](https://dotnet.microsoft.com/download) (para o `dotnet publish` do Backend) e runtime/SDK Flatpak `org.gnome.Platform`/`org.gnome.Sdk` (branch `49`) + `org.flatpak.Builder`, instaláveis via:

```sh
flatpak install --user flathub org.flatpak.Builder org.gnome.Sdk//49
```

## Validado até agora

- [x] Build + instalação local no Bazzite (host de desenvolvimento) — pacote instala, abre e renderiza a janela normalmente (confirmado visualmente via `flatpak run com.felipesam.sincronizador_pdf`), sem crash.
- [x] Backend empacotado inicia sozinho de dentro do sandbox (ver #31) — confirmado que `flatpak run com.felipesam.sincronizador_pdf` sobe o executável self-contained em `backend/` e cria os bancos SQLite em `~/.var/app/com.felipesam.sincronizador_pdf/data/sincronizador_pdf/backend/` (remapeamento padrão do Flatpak para `XDG_DATA_HOME`), sem erro de permissão.
- [ ] Segunda distro (ex: CachyOS) — ver checklist abaixo.

## Checklist: validar numa segunda distro (ex: CachyOS)

Rodar na outra máquina, com `flatpak` já instalado (vem por padrão em muitas distros; senão, ver https://flatpak.org/setup/):

1. Copiar o pacote construído (`.flatpak-builder-build/` não é portável; em vez disso, exporte um `.flatpak` single-file bundle na máquina de origem):
   ```sh
   flatpak build-bundle ~/.local/share/flatpak/repo com.felipesam.sincronizador_pdf.flatpak com.felipesam.sincronizador_pdf
   ```
2. Transferir o arquivo `com.felipesam.sincronizador_pdf.flatpak` para a segunda máquina (pendrive, scp, etc.).
3. Na segunda máquina, garantir o remoto Flathub (para resolver a dependência do runtime `org.gnome.Platform//49`):
   ```sh
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   ```
4. Instalar o bundle:
   ```sh
   flatpak install --user com.felipesam.sincronizador_pdf.flatpak
   ```
5. Abrir o app e confirmar que a janela aparece normalmente, sem erro:
   ```sh
   flatpak run com.felipesam.sincronizador_pdf
   ```
6. Marcar o critério de aceite da issue #4 como validado (comentário na issue com a distro/versão testada).
