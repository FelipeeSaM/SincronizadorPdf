namespace SincronizadorPdf.Backend.Api.Pareamento;

public sealed class PairingCode
{
    public required string Code { get; init; }
    public required Guid OriginDeviceId { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }
    public required DateTimeOffset ExpiresAt { get; init; }
    public bool Used { get; set; }
}
