namespace SincronizadorPdf.Backend.Api.Transferencia;

public sealed class PendingTransfer
{
    public required string Hash { get; init; }
    public required Guid OriginDeviceId { get; init; }
    public required Guid TargetDeviceId { get; init; }
    public required byte[] Content { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }

    /// Nome do arquivo original na origem (ver #19), propagado ao
    /// Dispositivo de destino em vez de um nome derivado do hash.
    /// `null` para registros de antes da #19. Mutável (não `init`): um
    /// reenvio do mesmo (hash, destino) ainda pendente pode chegar com
    /// nome depois de um upload anterior sem nome (ver
    /// TransferService.UploadAsync).
    public string? Name { get; set; }
}
