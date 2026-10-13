# Sincronizador PDF

App Flutter pessoal que substitui o leitor de PDF no PC e no celular, mantendo a posição de leitura e os highlights sincronizados entre os dois dispositivos através de um Backend auto-hospedado.

## Como funciona

- **Documento**: o PDF é transferido de verdade entre os dois dispositivos (não fica só uma referência) — cada lado guarda uma cópia completa.
- **Pareamento**: feito uma única vez, via QR Code exibido no PC e escaneado pelo celular.
- **Backend de Sincronização**: serviço que você mesmo hospeda. Ele só retransmite os bytes do Documento (fila temporária até o outro lado confirmar o recebimento) e guarda permanentemente apenas dados pequenos: posição de leitura e highlights.
- **Sincronização automática**: enquanto o app está em foco, a posição de leitura e os highlights são enviados/recebidos a cada poucos segundos. Não há sincronização em segundo plano com o app fechado.

Para o glossário completo dos termos do domínio, veja [`CONTEXT.md`](CONTEXT.md). Decisões de arquitetura estão em [`docs/adr/`](docs/adr/).

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

## Configurando o Backend de Sincronização

O Backend não tem build pronto para baixar — cada pessoa hospeda a própria instância (ver [ADR-0003](docs/adr/0003-backend-relay-sem-storage-permanente.md)). É um serviço ASP.NET Core (.NET 10) simples, sem dependências externas (usa SQLite em arquivo).

### Pré-requisitos

- [.NET SDK 10](https://dotnet.microsoft.com/download)

### Rodando localmente (teste rápido)

```sh
cd backend/src/SincronizadorPdf.Backend.Api
dotnet run
```

Por padrão sobe em `http://localhost:5119` (e `https://localhost:7062` no perfil `https`). Na primeira execução ele cria e migra automaticamente 4 bancos SQLite na pasta do projeto: `pareamento.db`, `transferencia.db`, `posicao-leitura.db` e `highlights.db`.

### Hospedando para uso real (PC + celular em redes diferentes)

Para o Pareamento funcionar entre os dois dispositivos, o Backend precisa estar acessível pela internet (ou pela mesma rede local) a partir de **ambos**. Algumas formas comuns:

- VPS própria com um reverse proxy (nginx/Caddy) fazendo TLS e repassando para a porta do `dotnet run`/publish.
- Uma rede mesh como [Tailscale](https://tailscale.com/) entre os dois dispositivos, apontando para o IP interno do PC que roda o Backend.
- Um túnel temporário (ex: `ngrok`) para testes.

Depois de hospedado, anote a URL pública (ex: `https://meu-backend.exemplo.com`) — é ela que você vai informar no app ao parear.

## Usando o app

### 1. Parear os dois dispositivos (uma única vez)

1. Abra o app no PC e no celular.
2. Em cada um, toque em **"Parear Dispositivo"**.
3. Informe a URL do Backend de Sincronização (a mesma nos dois).
4. No PC aparece um QR Code.
5. No celular, a tela de Pareamento abre a câmera automaticamente — escaneie o QR do PC.
6. Pareamento confirmado nos dois lados.

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
