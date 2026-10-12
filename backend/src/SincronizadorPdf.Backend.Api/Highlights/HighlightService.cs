using Microsoft.EntityFrameworkCore;

namespace SincronizadorPdf.Backend.Api.Highlights;

public enum DeleteHighlightOutcome
{
    Success,
    NotFound,
}

public sealed class HighlightService(HighlightDbContext db, TimeProvider timeProvider)
{
    public async Task<Highlight> CriarAsync(
        string hash, int page, string coordenadas, string? trechoTexto, CancellationToken cancellationToken)
    {
        var highlight = new Highlight
        {
            Id = Guid.NewGuid(),
            Hash = hash.ToLowerInvariant(),
            Page = page,
            Coordenadas = coordenadas,
            TrechoTexto = trechoTexto,
            CreatedAt = timeProvider.GetUtcNow(),
        };

        db.Highlights.Add(highlight);
        await db.SaveChangesAsync(cancellationToken);

        return highlight;
    }

    public async Task<IReadOnlyList<Highlight>> ListarAsync(string hash, CancellationToken cancellationToken)
    {
        var normalizedHash = hash.ToLowerInvariant();

        // SQLite não suporta ORDER BY sobre DateTimeOffset na query: ordena em
        // memória depois de materializar (listas de Highlight por Documento são pequenas).
        var highlights = await db.Highlights.Where(h => h.Hash == normalizedHash).ToListAsync(cancellationToken);
        return highlights.OrderBy(h => h.CreatedAt).ToList();
    }

    public async Task<DeleteHighlightOutcome> ApagarAsync(Guid id, CancellationToken cancellationToken)
    {
        var highlight = await db.Highlights.SingleOrDefaultAsync(h => h.Id == id, cancellationToken);
        if (highlight is null)
        {
            return DeleteHighlightOutcome.NotFound;
        }

        db.Highlights.Remove(highlight);
        await db.SaveChangesAsync(cancellationToken);

        return DeleteHighlightOutcome.Success;
    }
}
