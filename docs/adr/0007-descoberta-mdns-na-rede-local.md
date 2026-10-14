---
status: accepted
---

# Descoberta mDNS na rede local substitui URL manual sempre-via-internet

A ADR-0003 e o código original de `pairing_screen.dart` partiam do pressuposto de que o Backend de Sincronização é "auto-hospedado, acessado pela internet" (ver CONTEXT.md, "Backend de Sincronização") e que não há descoberta automática — o usuário precisava digitar manualmente o endereço do Backend em ambos os Dispositivos. Isso não reflete o caso de uso real: PC e celular na mesma rede doméstica, com o Backend rodando como processo de vida curta do app desktop (ver #24, "backend como processo de vida curta do app desktop").

Decidimos trocar esse pressuposto por descoberta mDNS/DNS-SD na rede local, com fallback manual quando ela não se aplica. O app desktop anuncia o Backend local via mDNS enquanto está em execução (ver #25, "anúncio mDNS/DNS-SD do Backend na rede local"). No pareamento, o PC usa `http://localhost:<porta>` automaticamente quando o Backend local está disponível, sem pedir endereço (ver #26); sem ele, cai no formulário manual de URL como antes. O celular busca os Backends anunciados na rede a cada tentativa de Pareamento — tanto na confirmação inicial do código (ver #27) quanto, depois de pareado, a cada abertura do app (ver #28) — e tenta confirmar/sincronizar em cada candidato encontrado, sem guardar nem pedir URL manual. O Backend continua sem storage permanente do arquivo do Documento — essa parte da ADR-0003 não muda, só o transporte/descoberta da conexão entre os Dispositivos e o Backend.

## Considered Options

- Manter só a URL manual (status quo): rejeitada — exige digitação de endereço IP/porta em cada Dispositivo a cada troca de rede (ex: PC trocou de IP no DHCP), sem necessidade real já que os dois Dispositivos estão sempre na mesma rede doméstica.
- Serviço sempre ativo no PC (daemon/systemd), descoberto por um endereço fixo ou registrado uma única vez: rejeitada — contraria explicitamente a preferência do usuário por não ter um processo sempre em execução no PC; o Backend deve existir só enquanto o app desktop estiver aberto (ver #24).

## Consequences

A sincronização automática só funciona quando o app do PC está aberto e os dois Dispositivos estão na mesma rede local (mDNS não atravessa roteadores/sub-redes nem funciona pela internet). Fora dessas condições — app do PC fechado, ou Dispositivos em redes diferentes — o Pareamento/sincronização automática não encontra o Backend; o usuário cai no fallback manual de URL (se souber o endereço alcançável) ou fica sem sincronizar até voltar a estar na mesma rede com o app do PC aberto. O glossário de `CONTEXT.md` ("Backend de Sincronização") foi atualizado para refletir esta decisão.
