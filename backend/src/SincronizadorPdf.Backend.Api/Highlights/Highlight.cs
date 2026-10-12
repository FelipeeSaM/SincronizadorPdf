namespace SincronizadorPdf.Backend.Api.Highlights;

/// Um grifo visual permanente sobre um trecho de texto de um Documento
/// (ver CONTEXT.md) — metadado do app, nunca grava a annotation no PDF
/// original (ADR-0001).
public sealed class Highlight
{
    public required Guid Id { get; init; }
    public required string Hash { get; init; }
    public required int Page { get; init; }
    public required string Coordenadas { get; init; }
    public string? TrechoTexto { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }
}
