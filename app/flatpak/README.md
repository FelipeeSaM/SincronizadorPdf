# Empacotamento Flatpak

Manifesto e pipeline que produzem um pacote Flatpak instalável do app desktop, a partir do build Linux do Flutter (ver ADR-0004).

## Build local (requer o bundle Linux do Flutter já compilado)

```sh
./build.sh
```

Isso roda `flutter build linux --release` e em seguida `flatpak run org.flatpak.Builder -- --user --install --force-clean` usando `com.felipesam.sincronizador_pdf.yml`. Ao final, o pacote fica instalado para o usuário atual (`flatpak run com.felipesam.sincronizador_pdf`).

Dependências de build (fora do sandbox do Flatpak, usadas só para compilar): `cmake`, `ninja`, `gtk3-devel`, um compilador C/C++, e o runtime/SDK Flatpak `org.gnome.Platform`/`org.gnome.Sdk` (branch `49`) + `org.flatpak.Builder`, instaláveis via:

```sh
flatpak install --user flathub org.flatpak.Builder org.gnome.Sdk//49
```

Em sistemas imutáveis (ex: Bazzite), rode a etapa de `flutter build linux` dentro de um `toolbox`/`distrobox` com `cmake ninja-build gtk3-devel pkgconf-pkg-config clang` instalados, para não precisar de `rpm-ostree install` + reboot.

## Validado até agora

- [x] Build + instalação local no Bazzite (host de desenvolvimento) — pacote instala, abre e renderiza a janela normalmente (confirmado visualmente via `flatpak run com.felipesam.sincronizador_pdf`), sem crash.
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
