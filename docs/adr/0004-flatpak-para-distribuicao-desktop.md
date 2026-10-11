---
status: accepted
---

# Flatpak como formato de distribuição do app desktop

O app precisa rodar no PC do usuário (Bazzite, Fedora Atômico/imutável) e ser enviável para rodar na máquina de outra pessoa com uma distro Linux diferente (CachyOS, baseado em Arch, mutável). Um build Linux do Flutter gera um binário linkado dinamicamente contra as bibliotecas do sistema (GTK, glib, etc.), o que não é portável entre distros com bases e versões de biblioteca distintas — o binário compilado numa pode falhar na outra.

Decidimos empacotar o app desktop como **Flatpak**. Ele roda num runtime isolado (sandbox via bubblewrap + OSTree) que empacota suas próprias dependências, então funciona igual em qualquer distro, independente do formato de pacote nativo (rpm, deb, pacman) e independente de o sistema base ser mutável ou imutável. É também o modelo de distribuição que o próprio Bazzite já privilegia por padrão, evitando lidar com rpm-ostree layering para instalar algo no sistema base.

## Considered Options

- Distribuir o binário/bundle Flutter bruto: rejeitado — não há garantia de portabilidade entre Bazzite e CachyOS (bases e versões de biblioteca diferentes).
- Snap / AppImage: não avaliados a fundo; Flatpak foi escolhido por ser o padrão já adotado pelo Bazzite e por sandboxing maduro.

## Consequences

O app passa a depender do runtime Flatpak (e de um runtime base como o GNOME/Freedesktop Platform) estar disponível nas máquinas de destino — praticamente universal em distros desktop modernas, incluindo CachyOS. Builds de desenvolvimento ainda podem rodar direto via `flutter run`; o empacotamento Flatpak é só para distribuição.
</content>
