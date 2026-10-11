using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;

namespace SincronizadorPdf.Backend.Api.Transferencia;

public enum ConfirmReceiptOutcome
{
    Success,
    NotFound,
}

public sealed class TransferService(TransferDbContext db, TimeProvider timeProvider)
{
    public async Task<string> UploadAsync(Guid targetDeviceId, byte[] content, CancellationToken cancellationToken)
    {
        var hash = ComputeHash(content);

        var existing = await db.PendingTransfers.SingleOrDefaultAsync(
            p => p.Hash == hash && p.TargetDeviceId == targetDeviceId, cancellationToken);
        if (existing is not null)
        {
            return hash;
        }

        db.PendingTransfers.Add(new PendingTransfer
        {
            Hash = hash,
            TargetDeviceId = targetDeviceId,
            Content = content,
            CreatedAt = timeProvider.GetUtcNow(),
        });

        try
        {
            await db.SaveChangesAsync(cancellationToken);
        }
        catch (DbUpdateException)
        {
            // Reenvio concorrente do mesmo conteúdo para o mesmo destino: outro upload já venceu, mantém o registro existente.
        }

        return hash;
    }

    public async Task<byte[]?> DownloadAsync(string hash, Guid requestingDeviceId, CancellationToken cancellationToken)
    {
        var transfer = await db.PendingTransfers.SingleOrDefaultAsync(
            p => p.Hash == hash && p.TargetDeviceId == requestingDeviceId, cancellationToken);

        return transfer?.Content;
    }

    public async Task<ConfirmReceiptOutcome> ConfirmReceiptAsync(string hash, Guid confirmingDeviceId, CancellationToken cancellationToken)
    {
        var transfer = await db.PendingTransfers.SingleOrDefaultAsync(
            p => p.Hash == hash && p.TargetDeviceId == confirmingDeviceId, cancellationToken);
        if (transfer is null)
        {
            return ConfirmReceiptOutcome.NotFound;
        }

        db.PendingTransfers.Remove(transfer);
        await db.SaveChangesAsync(cancellationToken);

        return ConfirmReceiptOutcome.Success;
    }

    private static string ComputeHash(byte[] content) =>
        Convert.ToHexStringLower(SHA256.HashData(content));
}
