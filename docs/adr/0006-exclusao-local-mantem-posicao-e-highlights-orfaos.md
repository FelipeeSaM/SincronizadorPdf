---
status: accepted
---

# Exclusão local do Documento mantém Posição de Leitura e Highlights órfãos em disco

A exclusão de um Documento da Biblioteca (ver #20) remove a entrada do índice e o arquivo físico deste Dispositivo. Ficou em aberto se a Posição de Leitura e os Highlights locais desse mesmo hash — guardados em `PosicaoLeituraStore`/`HighlightStore`, indexados por hash, independentes do arquivo físico — deveriam ser apagados junto.

Decidimos não apagá-los: ficam órfãos em disco, sem acompanhamento. São dados pequenos (um JSON por Documento), sem custo relevante de armazenamento, e o Backend de Sincronização ainda os mantém persistidos (ver CONTEXT.md, "Backend de Sincronização"). Se o mesmo Documento (mesmo hash) for recebido de novo depois — a única forma de recuperação é via nova Transferência manual do outro Dispositivo, ver "Recuperação Manual" no CONTEXT.md — a Posição de Leitura e os Highlights voltam a sincronizar normalmente a partir do Backend, como em qualquer Documento já conhecido.

## Considered Options

- Apagar Posição de Leitura e Highlights locais junto com o Documento: rejeitada — exigiria um método de remoção em `PosicaoLeituraStore` e `HighlightStore` (nenhum dos dois tem hoje) só para economizar um dado pequeno, sem ganho real, já que o Backend os mantém de qualquer forma.

## Consequences

`PosicaoLeituraStore` e `HighlightStore` continuam sem método de remoção. Dados órfãos de Documentos excluídos ficam em disco indefinidamente (até o Documento ser recebido de novo ou o app ser desinstalado); sem impacto na sincronização, já que ela ocorre por hash e não depende de o Documento estar na Biblioteca.
