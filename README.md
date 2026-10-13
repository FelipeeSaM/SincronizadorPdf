# Sincronizador PDF

App Flutter pessoal que substitui o leitor de PDF no PC e no celular, mantendo a posição de leitura e os highlights sincronizados entre os dois dispositivos — sem configuração manual, enquanto os dois estiverem na mesma rede local.

## Como funciona

- **Documento**: o PDF é transferido de verdade entre os dois dispositivos (não fica só uma referência) — cada lado guarda uma cópia completa.
- **Pareamento**: feito uma única vez, via QR Code exibido no PC e escaneado pelo celular — o celular descobre o Backend automaticamente na rede local (mDNS), sem precisar digitar nenhum endereço.
- **Backend de Sincronização**: sobe e desce junto com o app desktop (nasce quando você abre o app no PC, morre quando você fecha) — não é um serviço que fica rodando o tempo todo. Ele só retransmite os bytes do Documento (fila temporária até o outro lado confirmar o recebimento) e guarda permanentemente apenas dados pequenos: posição de leitura e highlights.
- **Sincronização automática**: enquanto o app está em foco, a posição de leitura e os highlights são enviados/recebidos a cada poucos segundos. Não há sincronização em segundo plano com o app fechado.

Para o glossário completo dos termos do domínio, veja [`CONTEXT.md`](CONTEXT.md). Decisões de arquitetura estão em [`docs/adr/`](docs/adr/), em especial a [ADR-0003](docs/adr/0003-backend-relay-sem-storage-permanente.md) (Backend sem storage permanente) e a [ADR-0007](docs/adr/0007-descoberta-mdns-na-rede-local.md) (descoberta mDNS na rede local).

## Instalação (uso no dia a dia)

Os binários prontos ficam na página de [**Releases**](https://github.com/FelipeeSaM/SincronizadorPdf/releases).

### Android

1. Baixe o `sincronizador_pdf-vX.Y.Z.apk` da release mais recente.
2. Abra o arquivo baixado no celular. Se o Android bloquear, vá em **Configurações → Segurança** (ou no aviso que aparecer) e permita **"Instalar apps de fontes desconhecidas"** para o app usado para baixar o APK (navegador, Telegram, etc.).
3. Toque em "Instalar".

### Linux

Há duas formas de instalar:

**Opção A — bundle zipado (mais simples, sem Flatpak):**

1. Baixe o `sincronizador_pdf-vX.Y.Z-linux-x64.zip` da release.
2. Extraia em qualquer pasta, por exemplo:
   ```sh
   unzip sincronizador_pdf-vX.Y.Z-linux-x64.zip -d ~/Apps/sincronizador_pdf
   ```
3. Execute o binário:
   ```sh
   ~/Apps/sincronizador_pdf/sincronizador_pdf
   ```
   Requer as bibliotecas GTK3 no sistema (já presentes na maioria das distros desktop).

**Opção B — pacote Flatpak (recomendado: integra com o menu de apps, sandboxed):**

1. Garanta que o `flatpak` está instalado ([flatpak.org/setup](https://flatpak.org/setup/)) e que o remoto Flathub existe:
   ```sh
   flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
   ```
2. Baixe o `sincronizador_pdf-vX.Y.Z-linux-x64.flatpak` da release.
3. Instale o bundle:
   ```sh
   flatpak install --user sincronizador_pdf-vX.Y.Z-linux-x64.flatpak
   ```
   (Isso também instala automaticamente o runtime `org.gnome.Platform//49` do Flathub, se ainda não estiver presente.)
4. Abra pelo menu de aplicativos ou via:
   ```sh
   flatpak run com.felipesam.sincronizador_pdf
   ```

Para gerar esse `.flatpak` você mesmo a partir do código-fonte, veja [`app/flatpak/README.md`](app/flatpak/README.md).

## O Backend de Sincronização (não precisa configurar nada)

O Backend vem **embutido no próprio app desktop** (Flatpak ou zip, ver #31): ao abrir o app no PC, ele já sobe o Backend localmente, numa porta livre, e o anuncia na rede local via mDNS/DNS-SD. Você não precisa instalar nem rodar nada à parte — nem o `.NET SDK` — para o uso normal com PC e celular na mesma rede doméstica.

O Backend nunca guarda cópia permanente dos seus Documentos (ver [ADR-0003](docs/adr/0003-backend-relay-sem-storage-permanente.md)); só retransmite os bytes e persiste os dados pequenos (posição de leitura, highlights) em bancos SQLite dentro da mesma pasta de dados do app onde já ficam a Biblioteca e os Highlights (ex: `~/.local/share/<app>/backend/` fora do Flatpak, ou `~/.var/app/com.felipesam.sincronizador_pdf/data/<app>/backend/` dentro dele).

### Limitação: só funciona com os dois dispositivos na mesma rede local

A descoberta automática usa mDNS, que não atravessa a internet nem redes diferentes (ver [ADR-0007](docs/adr/0007-descoberta-mdns-na-rede-local.md)). Isso cobre o caso de uso típico (PC e celular em casa, na mesma Wi-Fi), mas tem duas consequências:

- O Backend só existe enquanto o app do PC estiver aberto — fechar o app o encerra.
- Se o PC e o celular estiverem em redes diferentes (ex: celular fora de casa), a sincronização automática não encontra o Backend.

### Avançado: rodando o Backend separadamente (dev, ou PC + celular em redes diferentes)

Para quem está desenvolvendo o Backend, ou quer hospedá-lo separadamente (acessível pela internet, para sincronizar mesmo com os dispositivos em redes diferentes), ele também pode ser rodado à parte — é um serviço ASP.NET Core (.NET 10) simples, sem dependências externas:

```sh
cd backend/src/SincronizadorPdf.Backend.Api
dotnet run
```

Por padrão sobe em `http://localhost:5119` (e `https://localhost:7062` no perfil `https`), fora do modo LAN (sem anúncio mDNS) — nesse caso, informe a URL manualmente na tela de Pareamento do app, nos dois dispositivos. Requer [.NET SDK 10](https://dotnet.microsoft.com/download). Algumas formas comuns de hospedar para acesso pela internet:

- VPS própria com um reverse proxy (nginx/Caddy) fazendo TLS e repassando para a porta do `dotnet run`/publish.
- Uma rede mesh como [Tailscale](https://tailscale.com/) entre os dois dispositivos, apontando para o IP interno de quem hospeda o Backend.
- Um túnel temporário (ex: `ngrok`) para testes.

## Usando o app

### 1. Parear os dois dispositivos (uma única vez)

1. Abra o app no PC — o Backend local sobe automaticamente e já aparece um QR Code na tela de **"Parear Dispositivo"**.
2. No celular, toque em **"Parear Dispositivo"** e escaneie esse QR Code; a câmera abre automaticamente. O celular descobre o Backend sozinho na rede local — não pede endereço.
3. Pareamento confirmado nos dois lados.

Se o PC não tiver conseguido iniciar o Backend local (ex: rodando numa plataforma sem suporte, ou numa instalação antiga sem o Backend embutido), a tela do PC cai de volta no formulário manual de endereço — ver seção "Avançado" acima.

### 2. Abrir e transferir um Documento

- Toque em **"Abrir Documento"** (ou arraste um PDF para a janela, no desktop) para escolher um arquivo local.
- Se já houver um Dispositivo pareado, a Transferência começa automaticamente em segundo plano.
- No outro dispositivo, o Documento aparece na **Biblioteca** assim que a Transferência terminar.

### 3. Ler e marcar highlights

- Abra qualquer Documento da Biblioteca para visualizá-lo em rolagem contínua.
- Selecione um trecho de texto (mouse no PC, toque longo no celular) para criar um highlight — ele sincroniza para o outro dispositivo junto com a posição de leitura.
- Ao reabrir o mesmo Documento em qualquer um dos dois dispositivos, a leitura continua do último ponto sincronizado (o mais recente entre os dois vence).

### 4. Biblioteca

- Lista todos os Documentos já recebidos neste dispositivo.
- Excluir um Documento remove apenas a cópia local; a posição de leitura e os highlights já sincronizados não são apagados do outro dispositivo (ver [ADR-0006](docs/adr/0006-exclusao-local-mantem-posicao-e-highlights-orfaos.md)). Para recuperar o arquivo depois, é preciso fazer uma nova Transferência manual a partir do outro dispositivo.

### Observação sobre reinstalação/troca de celular/PC

Não existe um fluxo de "restaurar automaticamente". Se um dispositivo perder os Documentos locais, a única forma de recuperá-los é repetir a Transferência manualmente a partir do dispositivo que ainda os tem.

## Compilando a partir do código-fonte

Para desenvolvimento, testes e detalhes de build (Flutter, Android, Linux/toolbox, Flatpak, Backend), veja:

- [`app/README.md`](app/README.md)
- [`app/flatpak/README.md`](app/flatpak/README.md)
- [`CONTEXT.md`](CONTEXT.md) e [`docs/adr/`](docs/adr/)
