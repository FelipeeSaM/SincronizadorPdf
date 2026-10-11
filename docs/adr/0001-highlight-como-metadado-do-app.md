---
status: accepted
---

# Highlight como metadado do app, não como annotation nativa no PDF

O app precisa gravar highlights permanentes sobre trechos de texto selecionados. A alternativa óbvia seria gravar uma annotation PDF padrão (`/Highlight`) dentro do próprio arquivo, o que a tornaria visível em qualquer leitor externo (ex: Okular). Decidimos não fazer isso: guardamos o highlight como metadado separado do app (documento, página, coordenadas/texto) e desenhamos um overlay por cima do PDF original na renderização, sem nunca modificar o arquivo.

A decisão foi motivada por uma limitação técnica real do `pdfrx`/PDFium (biblioteca escolhida em [ADR-0002](./0002-pdfrx-como-biblioteca-de-renderizacao.md)): a gravação de annotations via PDFium hoje viola a spec PDF (omite `/Rect`), podendo gerar grifos inválidos ou invisíveis em outros leitores. A única lib madura para gravar annotations válidas é `syncfusion_flutter_pdf`, uma dependência extra com restrições de licença (Community License com teto de receita/equipe) que não se justificam, já que o objetivo do app é uso pessoal dentro do próprio fluxo de leitura — não compartilhar PDFs grifados com terceiros.

## Considered Options

- Annotation PDF nativa via `syncfusion_flutter_pdf`: rejeitada por somar dependência e risco de licença sem necessidade real de portabilidade.
- Annotation PDF nativa via PDFium puro (pdfrx): rejeitada por gerar annotations potencialmente inválidas (falta de `/Rect`).

## Consequences

O PDF original nunca é modificado; highlights não aparecem se o arquivo for aberto fora do app. Migrar para annotation nativa no futuro é possível (basta "bakear" os metadados existentes num passo de migração); o caminho inverso seria mais custoso.
</content>
