---
status: accepted
---

# Fila Local de Sincronização, com timestamp de autoridade do Dispositivo

O Backend de Sincronização é auto-hospedado (ADR-0003) e pode ficar fora do ar por período indefinido. Sem tratamento explícito, qualquer Highlight criado ou Posição de Leitura atualizada enquanto o Backend está indisponível se perderia, ou poderia ser resolvida incorretamente quando o Backend voltasse.

Decidimos que: (1) cada Dispositivo mantém uma **Fila Local de Sincronização** com os eventos discretos ainda não confirmados (criação/remoção de Highlight, pedidos de Transferência), reenviados até confirmação — a Posição de Leitura não entra nessa fila porque é um único valor sobrescrito localmente, não um log de eventos; (2) o timestamp usado para resolver conflitos por last-write-wins é sempre registrado no momento da ação, pelo relógio do próprio Dispositivo, nunca pelo momento em que o Backend recebe o dado; (3) a tentativa de esvaziar a fila e sincronizar só ocorre com o app aberto/em foco, sem serviço de sincronização em segundo plano.

A alternativa de usar o timestamp de recebimento do Backend foi rejeitada: se o Dispositivo A atualiza a Posição de Leitura às 10h mas o Backend só volta ao ar às 14h, enquanto o Dispositivo B atualiza (já online) às 12h, usar o horário de recebimento faria a atualização de A (mais antiga de fato) vencer incorretamente por chegar depois. Sincronização em segundo plano foi rejeitada por adicionar complexidade de serviço/permissões no Android sem benefício proporcional para um app de uso pessoal.

## Considered Options

- Timestamp de recebimento do Backend como autoridade: rejeitado — produz resultados incorretos quando o Backend fica fora do ar por tempo desigual entre Dispositivos.
- Sincronização em segundo plano (app fechado): rejeitada — complexidade desproporcional (background service no Android) para o ganho, dado uso pessoal.

## Consequences

Exige que os relógios dos dois Dispositivos estejam razoavelmente sincronizados entre si (NTP padrão do SO é suficiente; não há reconciliação de clock skew nesta fase). A Fila Local de Sincronização é um componente novo no cliente Flutter, compartilhado entre os fluxos de Highlight e Transferência.
</content>
