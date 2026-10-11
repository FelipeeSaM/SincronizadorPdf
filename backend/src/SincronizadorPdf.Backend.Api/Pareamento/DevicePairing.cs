namespace SincronizadorPdf.Backend.Api.Pareamento;

public sealed class DevicePairing
{
    public required Guid Id { get; init; }
    public required Guid DeviceAId { get; init; }
    public required Guid DeviceBId { get; init; }
    public required DateTimeOffset PairedAt { get; init; }
}
