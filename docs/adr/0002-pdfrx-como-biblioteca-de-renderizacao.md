---
status: accepted
---

# pdfrx como biblioteca de renderização de PDF

O app precisa renderizar PDF e dar suporte a seleção de texto em dois ambientes: Linux desktop (PC, via Flutter desktop) e Android. Decidimos usar `pdfrx` (baseado em PDFium) como biblioteca única para ambas as plataformas, em vez de `syncfusion_flutter_pdfviewer` ou de libs mobile-only (`flutter_pdfview`, `pdfx`, `native_pdf_renderer`).

`flutter_pdfview`, `pdfx` e `native_pdf_renderer` foram eliminados de imediato: nenhum suporta Linux desktop, requisito não-negociável já que o PC é a plataforma de leitura principal do usuário. Entre `pdfrx` e `syncfusion_flutter_pdfviewer`, ambos suportam Linux desktop, mas o suporte do Syncfusion é oficial apenas desde meados de 2025 (menos tempo de maturidade nessa plataforma específica) e sua licença Community tem teto de receita/tamanho de equipe. `pdfrx` tem suporte a Linux mais consolidado, licença permissiva sem teto comercial, e já expõe a API necessária para o highlight (bounding boxes de texto selecionado via `PdfTextSelectionParams`, overlays customizados por página via `pageOverlaysBuilder`) — suficiente dado que highlights são metadado do app, não annotation nativa ([ADR-0001](./0001-highlight-como-metadado-do-app.md)).

## Considered Options

- `syncfusion_flutter_pdfviewer`: rejeitada — vantagem de annotation nativa não é aproveitada (ADR-0001), e carrega teto de licença e suporte a Linux mais recente.
- `flutter_pdfview`, `pdfx`, `native_pdf_renderer`: rejeitadas — sem suporte a Linux desktop.

## Consequences

Trocar a biblioteca de renderização mais adiante exigiria reescrever toda a camada de visualização e seleção de texto; esta é a decisão mais cara de reverter das três tomadas nesta fase de design.
</content>
