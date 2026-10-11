---
status: accepted
---

# Backend como relay temporário, sem storage permanente dos arquivos

O Backend de Sincronização precisa transferir o Documento (arquivo PDF) entre os dois Dispositivos pareados. Decidimos que ele atua como relay: guarda o arquivo numa fila temporária só até o Dispositivo de destino confirmar o recebimento completo, e descarta a cópia depois disso. Ele nunca mantém um storage permanente dos arquivos — essa responsabilidade fica só com Posição de Leitura e Highlights, que são persistidos permanentemente por serem dados pequenos.

A alternativa seria o backend manter uma cópia permanente de cada Documento, funcionando como fonte de verdade recuperável mesmo que nenhum dos dois Dispositivos ainda tenha o arquivo. Rejeitamos isso porque, para uso pessoal entre dois dispositivos já com cópia local de cada arquivo, o storage permanente só adiciona custo de armazenamento crescente, superfície de dados sensíveis acumulados num servidor próprio, e complexidade de gestão de retenção — sem benefício proporcional.

## Considered Options

- Storage permanente no backend: rejeitada por custo/complexidade desproporcionais ao ganho, dado que os dois Dispositivos já são a fonte de verdade dos arquivos.

## Consequences

Se os dois Dispositivos perderem o arquivo local de um Documento ao mesmo tempo (ex: ambos reinstalados sem transferência prévia), o Documento é irrecuperável — não há terceira cópia em lugar nenhum. A recuperação de um Dispositivo que perdeu o arquivo depende de reenvio manual do outro Dispositivo, enquanto este ainda o tiver (ver [[Recuperação Manual]] em `CONTEXT.md`). Esse risco foi considerado aceitável para uso pessoal.
</content>
