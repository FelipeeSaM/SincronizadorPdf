using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using SincronizadorPdf.Backend.Api.Pareamento;

namespace SincronizadorPdf.Backend.Api.Transferencia;

public enum ConfirmReceiptOutcome
{
    Success,
    NotFound,
}

public enum UploadTransferOutcome
{
    Success,
    NotPaired,
}

public sealed record UploadTransferResult(UploadTransferOutcome Outcome, string? Hash)
{
    public static UploadTransferResult Success(string hash) => new(UploadTransferOutcome.Success, hash);
    public static UploadTransferResult NotPaired() => new(UploadTransferOutcome.NotPaired, null);
}

public sealed class TransferService(TransferDbContext db, PairingService pairingService, TimeProvider timeProvider)
{
    public async Task<UploadTransferResult> UploadAsync(Guid originDeviceId, Guid targetDeviceId, Stream contentStream, CancellationToken cancellationToken)
    {
        var paired = await pairingService.AreDevicesPairedAsync(originDeviceId, targetDeviceId, cancellationToken);
        if (!paired)
        {
            return UploadTransferResult.NotPaired();
        }

        using var buffer = new MemoryStream();
        await contentStream.CopyToAsync(buffer, cancellationToken);
        var content = buffer.ToArray();

        var hash = ComputeHash(content);

        var existing = await db.PendingTransfers.SingleOrDefaultAsync(
            p => p.Hash == hash && p.TargetDeviceId == targetDeviceId, cancellationToken);
        if (existing is not null)
        {
            return UploadTransferResult.Success(hash);
        }

        db.PendingTransfers.Add(new PendingTransfer
        {
            Hash = hash,
            OriginDeviceId = originDeviceId,
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

        return UploadTransferResult.Success(hash);
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
