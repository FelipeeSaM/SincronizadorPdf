namespace SincronizadorPdf.Backend.Api.PosicaoLeitura;

public sealed class ReadingPosition
{
    public required string Hash { get; init; }
    public required Guid DeviceId { get; set; }
    public required int Page { get; set; }
    public required double ScrollPercentage { get; set; }
    public required DateTimeOffset UpdatedAt { get; set; }
}
