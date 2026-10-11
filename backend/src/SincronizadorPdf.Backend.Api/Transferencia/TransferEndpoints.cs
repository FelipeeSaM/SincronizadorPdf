using System.Diagnostics;

namespace SincronizadorPdf.Backend.Api.Transferencia;

public sealed record UploadTransferResponse(string Hash);

public sealed record ConfirmReceiptRequest(Guid DeviceId);

public static class TransferEndpoints
{
    public static IEndpointRouteBuilder MapTransferEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/transferencias");

        group.MapPost("", async (Guid deviceId, HttpRequest request, TransferService service, CancellationToken cancellationToken) =>
        {
            using var buffer = new MemoryStream();
            await request.Body.CopyToAsync(buffer, cancellationToken);
            var hash = await service.UploadAsync(deviceId, buffer.ToArray(), cancellationToken);
            return Results.Created($"/transferencias/{hash}", new UploadTransferResponse(hash));
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
