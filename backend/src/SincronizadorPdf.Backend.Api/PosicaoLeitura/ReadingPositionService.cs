using Microsoft.EntityFrameworkCore;

namespace SincronizadorPdf.Backend.Api.PosicaoLeitura;

public enum SetReadingPositionOutcome
{
    Applied,
    Stale,
}

public sealed record SetReadingPositionResult(SetReadingPositionOutcome Outcome, ReadingPosition Current)
{
    public static SetReadingPositionResult Applied(ReadingPosition current) => new(SetReadingPositionOutcome.Applied, current);
    public static SetReadingPositionResult Stale(ReadingPosition current) => new(SetReadingPositionOutcome.Stale, current);
}

public sealed class ReadingPositionService(ReadingPositionDbContext db)
{
    public async Task<SetReadingPositionResult> SetAsync(
        string hash, Guid deviceId, int page, double scrollPercentage, DateTimeOffset updatedAt, CancellationToken cancellationToken)
    {
        var normalizedHash = hash.ToLowerInvariant();

        while (true)
        {
            var existing = await db.ReadingPositions.SingleOrDefaultAsync(p => p.Hash == normalizedHash, cancellationToken);
            if (existing is not null)
            {
                if (updatedAt <= existing.UpdatedAt)
                {
                    // Timestamp do Dispositivo de origem, não ordem de chegada, decide o last-write-wins (ADR-0005).
                    return SetReadingPositionResult.Stale(existing);
                }

                existing.DeviceId = deviceId;
                existing.Page = page;
                existing.ScrollPercentage = scrollPercentage;
                existing.UpdatedAt = updatedAt;
                await db.SaveChangesAsync(cancellationToken);
                return SetReadingPositionResult.Applied(existing);
            }

            var created = new ReadingPosition
            {
                Hash = normalizedHash,
                DeviceId = deviceId,
                Page = page,
                ScrollPercentage = scrollPercentage,
                UpdatedAt = updatedAt,
            };
            db.ReadingPositions.Add(created);

            try
            {
                await db.SaveChangesAsync(cancellationToken);
                return SetReadingPositionResult.Applied(created);
            }
            catch (DbUpdateException)
            {
                // Gravação concorrente do mesmo Documento criou o registro primeiro: reavalia como atualização.
                db.Entry(created).State = EntityState.Detached;
            }
        }
    }

    public Task<ReadingPosition?> GetAsync(string hash, CancellationToken cancellationToken) =>
        db.ReadingPositions.SingleOrDefaultAsync(p => p.Hash == hash.ToLowerInvariant(), cancellationToken);
}
