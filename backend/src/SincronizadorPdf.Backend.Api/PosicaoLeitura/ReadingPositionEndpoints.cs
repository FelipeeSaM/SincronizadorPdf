using System.Diagnostics;

namespace SincronizadorPdf.Backend.Api.PosicaoLeitura;

public sealed record SetReadingPositionRequest(Guid DeviceId, int Page, double ScrollPercentage, DateTimeOffset UpdatedAt);

public sealed record ReadingPositionResponse(string Hash, int Page, double ScrollPercentage, DateTimeOffset UpdatedAt);

public static class ReadingPositionEndpoints
{
    public static IEndpointRouteBuilder MapReadingPositionEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/posicoes-leitura");

        group.MapPut("/{hash}", async (string hash, SetReadingPositionRequest request, ReadingPositionService service, CancellationToken cancellationToken) =>
        {
            var result = await service.SetAsync(hash, request.DeviceId, request.Page, request.ScrollPercentage, request.UpdatedAt, cancellationToken);
            return result.Outcome switch
            {
                SetReadingPositionOutcome.Applied => Results.NoContent(),
                SetReadingPositionOutcome.Stale => Results.Ok(ToResponse(result.Current)),
                _ => throw new UnreachableException(),
            };
        });

        group.MapGet("/{hash}", async (string hash, ReadingPositionService service, CancellationToken cancellationToken) =>
        {
            var position = await service.GetAsync(hash, cancellationToken);
            return position is null ? Results.NotFound() : Results.Ok(ToResponse(position));
        });

        return group;
    }

    private static ReadingPositionResponse ToResponse(ReadingPosition position) =>
        new(position.Hash, position.Page, position.ScrollPercentage, position.UpdatedAt);
}
