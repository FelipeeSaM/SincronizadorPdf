using System.Diagnostics;

namespace SincronizadorPdf.Backend.Api.Transferencia;

public sealed record UploadTransferResponse(string Hash);

public sealed record ConfirmReceiptRequest(Guid DeviceId);

public static class TransferEndpoints
{
    public static IEndpointRouteBuilder MapTransferEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/transferencias");

        group.MapGet("", async (Guid deviceId, TransferService service, CancellationToken cancellationToken) =>
        {
            var hashes = await service.ListPendingAsync(deviceId, cancellationToken);
            return Results.Ok(hashes);
        });

        group.MapPost("", async (Guid originDeviceId, Guid targetDeviceId, HttpRequest request, TransferService service, CancellationToken cancellationToken) =>
        {
            var result = await service.UploadAsync(originDeviceId, targetDeviceId, request.Body, cancellationToken);
            return result.Outcome switch
            {
                UploadTransferOutcome.Success => Results.Created($"/transferencias/{result.Hash}", new UploadTransferResponse(result.Hash!)),
                UploadTransferOutcome.NotPaired => Results.StatusCode(StatusCodes.Status403Forbidden),
                _ => throw new UnreachableException(),
            };
        });

        group.MapGet("/{hash}", async (string hash, Guid deviceId, TransferService service, CancellationToken cancellationToken) =>
        {
            var content = await service.DownloadAsync(hash, deviceId, cancellationToken);
            return content is null ? Results.NotFound() : Results.Bytes(content, "application/octet-stream");
        });

        group.MapPost("/{hash}/confirmacoes", async (string hash, ConfirmReceiptRequest request, TransferService service, CancellationToken cancellationToken) =>
        {
            var outcome = await service.ConfirmReceiptAsync(hash, request.DeviceId, cancellationToken);
            return outcome switch
            {
                ConfirmReceiptOutcome.Success => Results.NoContent(),
                ConfirmReceiptOutcome.NotFound => Results.NotFound(),
                _ => throw new UnreachableException(),
            };
        });

        return group;
    }
}
