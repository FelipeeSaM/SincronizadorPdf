using System.Diagnostics;

namespace SincronizadorPdf.Backend.Api.Pareamento;

public sealed record GenerateCodeRequest(Guid DeviceId);

public sealed record GenerateCodeResponse(string Code, DateTimeOffset ExpiresAt);

public sealed record ConfirmCodeRequest(Guid DeviceId);

public sealed record ConfirmCodeResponse(Guid DeviceAId, Guid DeviceBId, DateTimeOffset PairedAt);

public sealed record PairingCodeStatusResponse(string Status, Guid? DeviceAId, Guid? DeviceBId, DateTimeOffset? PairedAt);

public static class PairingEndpoints
{
    public static IEndpointRouteBuilder MapPairingEndpoints(this IEndpointRouteBuilder app)
    {
        var group = app.MapGroup("/pareamento");

        group.MapPost("/codigos", async (GenerateCodeRequest request, PairingService service, CancellationToken cancellationToken) =>
        {
            var code = await service.GenerateCodeAsync(request.DeviceId, cancellationToken);
            return Results.Created(
                $"/pareamento/codigos/{code.Code}",
                new GenerateCodeResponse(code.Code, code.ExpiresAt));
        });

        group.MapPost("/codigos/{codigo}/confirmacoes", async (string codigo, ConfirmCodeRequest request, PairingService service, CancellationToken cancellationToken) =>
        {
            var result = await service.ConfirmCodeAsync(codigo, request.DeviceId, cancellationToken);
            return result.Outcome switch
            {
                ConfirmPairingOutcome.Success => Results.Ok(new ConfirmCodeResponse(
                    result.Pairing!.DeviceAId,
                    result.Pairing.DeviceBId,
                    result.Pairing.PairedAt)),
                ConfirmPairingOutcome.NotFound => Results.NotFound(),
                ConfirmPairingOutcome.NoLongerValid => Results.StatusCode(StatusCodes.Status410Gone),
                ConfirmPairingOutcome.SameDevice => Results.BadRequest(),
                _ => throw new UnreachableException(),
            };
        });

        group.MapGet("/codigos/{codigo}", async (string codigo, PairingService service, CancellationToken cancellationToken) =>
        {
            var result = await service.GetCodeStatusAsync(codigo, cancellationToken);
            return result.Status switch
            {
                PairingCodeStatus.NotFound => Results.NotFound(),
                PairingCodeStatus.Pending => Results.Ok(new PairingCodeStatusResponse("pendente", null, null, null)),
                PairingCodeStatus.Expired => Results.Ok(new PairingCodeStatusResponse("expirado", null, null, null)),
                PairingCodeStatus.Confirmed => Results.Ok(new PairingCodeStatusResponse(
                    "confirmado",
                    result.Pairing!.DeviceAId,
                    result.Pairing.DeviceBId,
                    result.Pairing.PairedAt)),
                _ => throw new UnreachableException(),
            };
        });

        return group;
    }
}
