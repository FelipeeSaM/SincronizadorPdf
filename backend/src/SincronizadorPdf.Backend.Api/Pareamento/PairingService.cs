using Microsoft.EntityFrameworkCore;

namespace SincronizadorPdf.Backend.Api.Pareamento;

public enum ConfirmPairingOutcome
{
    Success,
    NotFound,
    NoLongerValid,
    SameDevice,
}

public sealed record ConfirmPairingResult(ConfirmPairingOutcome Outcome, DevicePairing? Pairing)
{
    public static ConfirmPairingResult Success(DevicePairing pairing) => new(ConfirmPairingOutcome.Success, pairing);
    public static ConfirmPairingResult NotFound() => new(ConfirmPairingOutcome.NotFound, null);
    public static ConfirmPairingResult NoLongerValid() => new(ConfirmPairingOutcome.NoLongerValid, null);
    public static ConfirmPairingResult SameDevice() => new(ConfirmPairingOutcome.SameDevice, null);
}

public enum PairingCodeStatus
{
    NotFound,
    Pending,
    Expired,
    Confirmed,
}

public sealed record PairingCodeStatusResult(PairingCodeStatus Status, DevicePairing? Pairing)
{
    public static PairingCodeStatusResult NotFound() => new(PairingCodeStatus.NotFound, null);
    public static PairingCodeStatusResult Pending() => new(PairingCodeStatus.Pending, null);
    public static PairingCodeStatusResult Expired() => new(PairingCodeStatus.Expired, null);
    public static PairingCodeStatusResult Confirmed(DevicePairing pairing) => new(PairingCodeStatus.Confirmed, pairing);
}

public sealed class PairingService(PairingDbContext db, TimeProvider timeProvider)
{
    public static readonly TimeSpan CodeLifetime = TimeSpan.FromMinutes(10);

    public async Task<PairingCode> GenerateCodeAsync(Guid originDeviceId, CancellationToken cancellationToken)
    {
        var now = timeProvider.GetUtcNow();

        while (true)
        {
            var code = new PairingCode
            {
                Code = PairingCodeGenerator.Generate(),
                OriginDeviceId = originDeviceId,
                CreatedAt = now,
                ExpiresAt = now + CodeLifetime,
            };

            db.PairingCodes.Add(code);

            try
            {
                await db.SaveChangesAsync(cancellationToken);
                return code;
            }
            catch (DbUpdateException)
            {
                // Colisão improvável de código já existente: descarta e tenta outro.
                db.Entry(code).State = EntityState.Detached;
            }
        }
    }

    public async Task<ConfirmPairingResult> ConfirmCodeAsync(string rawCode, Guid confirmingDeviceId, CancellationToken cancellationToken)
    {
        var normalizedCode = rawCode.Trim().ToUpperInvariant();
        var code = await db.PairingCodes.SingleOrDefaultAsync(p => p.Code == normalizedCode, cancellationToken);
        if (code is null)
        {
            return ConfirmPairingResult.NotFound();
        }

        var now = timeProvider.GetUtcNow();
        if (code.Used || code.ExpiresAt <= now)
        {
            return ConfirmPairingResult.NoLongerValid();
        }

        if (code.OriginDeviceId == confirmingDeviceId)
        {
            return ConfirmPairingResult.SameDevice();
        }

        code.Used = true;

        var pairing = new DevicePairing
        {
            Id = Guid.NewGuid(),
            DeviceAId = code.OriginDeviceId,
            DeviceBId = confirmingDeviceId,
            PairedAt = now,
        };
        db.DevicePairings.Add(pairing);
        code.PairingId = pairing.Id;

        await db.SaveChangesAsync(cancellationToken);

        return ConfirmPairingResult.Success(pairing);
    }

    public async Task<PairingCodeStatusResult> GetCodeStatusAsync(string rawCode, CancellationToken cancellationToken)
    {
        var normalizedCode = rawCode.Trim().ToUpperInvariant();
        var code = await db.PairingCodes.SingleOrDefaultAsync(p => p.Code == normalizedCode, cancellationToken);
        if (code is null)
        {
            return PairingCodeStatusResult.NotFound();
        }

        if (code.PairingId is { } pairingId)
        {
            var pairing = await db.DevicePairings.SingleAsync(p => p.Id == pairingId, cancellationToken);
            return PairingCodeStatusResult.Confirmed(pairing);
        }

        var now = timeProvider.GetUtcNow();
        return code.ExpiresAt <= now
            ? PairingCodeStatusResult.Expired()
            : PairingCodeStatusResult.Pending();
    }
}
