using System.Diagnostics;

namespace SincronizadorPdf.Backend.Api.Highlights;

public sealed record CreateHighlightRequest(string Hash, int Page, string Coordenadas, string? TrechoTexto);

public sealed record HighlightResponse(
    Guid Id, string Hash, int Page, string Coordenadas, string? TrechoTexto, DateTimeOffset CreatedAt);

public static class HighlightEndpoints
{
    public static IEndpointRouteBuilder MapHighlightEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/highlights");

        group.MapPost("", async (CreateHighlightRequest request, HighlightService service, CancellationToken cancellationToken) =>
        {
            var highlight = await service.CriarAsync(
                request.Hash, request.Page, request.Coordenadas, request.TrechoTexto, cancellationToken);
            return Results.Created($"/highlights/{highlight.Id}", ToResponse(highlight));
        });

        group.MapGet("", async (string hash, HighlightService service, CancellationToken cancellationToken) =>
        {
            var highlights = await service.ListarAsync(hash, cancellationToken);
            return Results.Ok(highlights.Select(ToResponse).ToList());
        });

        group.MapDelete("/{id:guid}", async (Guid id, HighlightService service, CancellationToken cancellationToken) =>
        {
            var outcome = await service.ApagarAsync(id, cancellationToken);
            return outcome switch
            {
                DeleteHighlightOutcome.Success => Results.NoContent(),
                DeleteHighlightOutcome.NotFound => Results.NotFound(),
                _ => throw new UnreachableException(),
            };
        });

        return group;
    }

    private static HighlightResponse ToResponse(Highlight highlight) => new(
        highlight.Id, highlight.Hash, highlight.Page, highlight.Coordenadas, highlight.TrechoTexto, highlight.CreatedAt);
}
