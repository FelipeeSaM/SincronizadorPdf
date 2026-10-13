# SincronizadorPdf

App Flutter pessoal que substitui o leitor de PDF no PC e no celular, mantendo a posição de leitura e os highlights sincronizados entre os dois dispositivos.

## Language

**Documento**:
Um arquivo PDF rastreado pelo app. É transferido entre os dispositivos pareados (não só uma referência/ponteiro) e tem sua própria posição de leitura e lista de highlights.
_Avoid_: PDF, arquivo (usar "Documento" quando se referir à entidade rastreada pelo app)

**Dispositivo**:
Um dos dois pontos (PC ou celular) pareados ao usuário. Cada Documento pode estar presente em um ou nos dois Dispositivos.
_Avoid_: aparelho, máquina

**Posição de Leitura**:
O ponto exato em que o usuário parou de ler um Documento. É o estado sincronizado por padrão (sem ação manual do usuário) entre os Dispositivos. Cada Dispositivo guarda sempre o valor mais recente localmente (sem histórico de rolagens), marcado com o timestamp do próprio Dispositivo no momento em que foi definido — é esse timestamp, não o momento em que o Backend de Sincronização recebe o dado, que decide o last-write-wins quando os dois Dispositivos divergem.
_Avoid_: página atual, última página

**Highlight**:
Um grifo visual permanente sobre um trecho de texto de um Documento, criado ao selecionar texto (long-press no celular, seleção com mouse no PC). Sincroniza entre Dispositivos junto com o Documento.
_Avoid_: marcador, bookmark, anotação (termos descartados nesta decisão — ver sessão de grilling)

**Transferência**:
O envio de um Documento de um Dispositivo para o outro através do Backend de Sincronização, iniciado pelo usuário ao soltar/abrir o arquivo no app em qualquer um dos lados.
_Avoid_: upload, sync de arquivo

**Backend de Sincronização**:
Serviço auto-hospedado que roda como processo de vida curta do app desktop (só existe enquanto esse app está aberto) e é descoberto automaticamente pelos Dispositivos pareados via mDNS na rede local, com fallback de URL manual quando a descoberta não se aplica (ver ADR-0007). Tem duas responsabilidades distintas: (1) atua como **relay** dos bytes do Documento, guardando-os numa fila temporária só até o Dispositivo de destino confirmar o recebimento completo — nunca mantém cópia permanente do arquivo; (2) persiste permanentemente a Posição de Leitura e os Highlights de cada Documento, por serem dados pequenos.
_Avoid_: servidor, API, storage central (storage central só se aplica à Posição de Leitura e Highlights, não ao arquivo)

**Pareamento**:
O vínculo entre os dois Dispositivos de um mesmo usuário, estabelecido uma vez via código/QR gerado no PC e escaneado pelo celular.
_Avoid_: login, conta, autenticação

**Biblioteca**:
A lista, dentro do app, dos Documentos cujo arquivo completo já chegou a este Dispositivo (a Transferência sempre copia o arquivo inteiro de uma vez; não existe estado "conhecido mas não baixado").
_Avoid_: histórico, acervo

**Recuperação Manual**:
Se um Dispositivo perder o arquivo local de um Documento (reinstalação, troca de aparelho), a única forma de recuperá-lo é o outro Dispositivo (que ainda o tem) iniciar uma nova Transferência manualmente — não há fluxo de "solicitar reenvio" automático.
_Avoid_: restore, backup

**Fila Local de Sincronização**:
A lista, mantida em cada Dispositivo, de Highlights (criação/remoção) e pedidos de Transferência ainda não confirmados pelo Backend de Sincronização — por serem eventos discretos, não um único valor como a Posição de Leitura, eles precisam ser retidos localmente e reenviados até confirmação, em vez de simplesmente sobrescritos. O Dispositivo tenta esvaziar essa fila ao abrir o app e periodicamente enquanto ele está em foco; não há tentativa de sincronização em segundo plano com o app fechado.
_Avoid_: outbox, fila de upload
</content>
</invoke>
