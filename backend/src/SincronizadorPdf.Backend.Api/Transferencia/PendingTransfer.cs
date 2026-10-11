namespace SincronizadorPdf.Backend.Api.Transferencia;

public sealed class PendingTransfer
{
    public required string Hash { get; init; }
    public required Guid TargetDeviceId { get; init; }
    public required byte[] Content { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }
}
