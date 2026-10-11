using System.Net;
using System.Net.Http.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SincronizadorPdf.Backend.Api.Pareamento;

namespace SincronizadorPdf.Backend.Api.Tests.Pareamento;

public class PairingEndpointsTests
{
    private static async Task<GenerateCodeResponse> GenerateCodeAsync(HttpClient client, Guid originDeviceId)
    {
        var response = await client.PostAsJsonAsync("/pareamento/codigos", new GenerateCodeRequest(originDeviceId));
        response.EnsureSuccessStatusCode();
        return (await response.Content.ReadFromJsonAsync<GenerateCodeResponse>())!;
    }

    private static Task<HttpResponseMessage> ConfirmCodeAsync(HttpClient client, string code, Guid confirmingDeviceId) =>
        client.PostAsJsonAsync($"/pareamento/codigos/{code}/confirmacoes", new ConfirmCodeRequest(confirmingDeviceId));

    [Fact]
    public async Task GenerateCode_ReturnsCodeWithExpiry()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();

        var response = await client.PostAsJsonAsync("/pareamento/codigos", new GenerateCodeRequest(Guid.NewGuid()));

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<GenerateCodeResponse>();
        Assert.NotNull(body);
        Assert.False(string.IsNullOrWhiteSpace(body!.Code));
        Assert.Equal(factory.TimeProvider.GetUtcNow() + PairingService.CodeLifetime, body.ExpiresAt);
    }

    [Fact]
    public async Task ConfirmCode_WithValidCode_LinksBothDevices()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var confirmingDeviceId = Guid.NewGuid();

        var generated = await GenerateCodeAsync(client, originDeviceId);
        var confirmResponse = await ConfirmCodeAsync(client, generated.Code, confirmingDeviceId);

        Assert.Equal(HttpStatusCode.OK, confirmResponse.StatusCode);
        var confirmed = await confirmResponse.Content.ReadFromJsonAsync<ConfirmCodeResponse>();
        Assert.NotNull(confirmed);
        Assert.Equal(originDeviceId, confirmed!.DeviceAId);
        Assert.Equal(confirmingDeviceId, confirmed.DeviceBId);
    }

    [Fact]
    public async Task ConfirmCode_WithUnknownCode_ReturnsNotFound()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();

        var response = await ConfirmCodeAsync(client, "NAOEXISTE", Guid.NewGuid());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task ConfirmCode_AfterExpiry_ReturnsGone()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();

        var generated = await GenerateCodeAsync(client, Guid.NewGuid());
        factory.TimeProvider.Advance(PairingService.CodeLifetime + TimeSpan.FromSeconds(1));

        var confirmResponse = await ConfirmCodeAsync(client, generated.Code, Guid.NewGuid());

        Assert.Equal(HttpStatusCode.Gone, confirmResponse.StatusCode);
    }

    [Fact]
    public async Task ConfirmCode_WhenAlreadyUsed_ReturnsGoneOnSecondAttempt()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();

        var generated = await GenerateCodeAsync(client, Guid.NewGuid());

        var firstConfirm = await ConfirmCodeAsync(client, generated.Code, Guid.NewGuid());
        Assert.Equal(HttpStatusCode.OK, firstConfirm.StatusCode);

        var secondConfirm = await ConfirmCodeAsync(client, generated.Code, Guid.NewGuid());

        Assert.Equal(HttpStatusCode.Gone, secondConfirm.StatusCode);
    }

    [Fact]
    public async Task ConfirmCode_WithOriginDeviceItself_ReturnsBadRequest()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();
        var deviceId = Guid.NewGuid();

        var generated = await GenerateCodeAsync(client, deviceId);
        var confirmResponse = await ConfirmCodeAsync(client, generated.Code, deviceId);

        Assert.Equal(HttpStatusCode.BadRequest, confirmResponse.StatusCode);
    }

    [Fact]
    public async Task CodeStatus_BeforeConfirmation_IsPending()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();

        var generated = await GenerateCodeAsync(client, Guid.NewGuid());
        var statusResponse = await client.GetAsync($"/pareamento/codigos/{generated.Code}");

        Assert.Equal(HttpStatusCode.OK, statusResponse.StatusCode);
        var status = await statusResponse.Content.ReadFromJsonAsync<PairingCodeStatusResponse>();
        Assert.Equal("pendente", status!.Status);
    }

    [Fact]
    public async Task CodeStatus_AfterConfirmation_IsConfirmedWithBothDevices()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var confirmingDeviceId = Guid.NewGuid();

        var generated = await GenerateCodeAsync(client, originDeviceId);
        await ConfirmCodeAsync(client, generated.Code, confirmingDeviceId);
        var statusResponse = await client.GetAsync($"/pareamento/codigos/{generated.Code}");

        Assert.Equal(HttpStatusCode.OK, statusResponse.StatusCode);
        var status = await statusResponse.Content.ReadFromJsonAsync<PairingCodeStatusResponse>();
        Assert.Equal("confirmado", status!.Status);
        Assert.Equal(originDeviceId, status.DeviceAId);
        Assert.Equal(confirmingDeviceId, status.DeviceBId);
    }

    [Fact]
    public async Task CodeStatus_AfterExpiry_IsExpired()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();

        var generated = await GenerateCodeAsync(client, Guid.NewGuid());
        factory.TimeProvider.Advance(PairingService.CodeLifetime + TimeSpan.FromSeconds(1));
        var statusResponse = await client.GetAsync($"/pareamento/codigos/{generated.Code}");

        Assert.Equal(HttpStatusCode.OK, statusResponse.StatusCode);
        var status = await statusResponse.Content.ReadFromJsonAsync<PairingCodeStatusResponse>();
        Assert.Equal("expirado", status!.Status);
    }

    [Fact]
    public async Task CodeStatus_WithUnknownCode_ReturnsNotFound()
    {
        using var factory = new PairingApiFactory();
        var client = factory.CreateClient();

        var statusResponse = await client.GetAsync("/pareamento/codigos/NAOEXISTE");

        Assert.Equal(HttpStatusCode.NotFound, statusResponse.StatusCode);
    }

    [Fact]
    public async Task PairingState_PersistsAcrossBackendRestart()
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"pareamento-restart-{Guid.NewGuid():N}.db");
        var originDeviceId = Guid.NewGuid();
        var confirmingDeviceId = Guid.NewGuid();

        try
        {
            using (var firstRun = new PairingApiFactory(databasePath))
            {
                var client = firstRun.CreateClient();
                var generated = await GenerateCodeAsync(client, originDeviceId);
                var confirmResponse = await ConfirmCodeAsync(client, generated.Code, confirmingDeviceId);
                Assert.Equal(HttpStatusCode.OK, confirmResponse.StatusCode);
            }

            using var secondRun = new PairingApiFactory(databasePath);
            using var scope = secondRun.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<PairingDbContext>();

            var pairingExists = await db.DevicePairings.AnyAsync(p =>
                p.DeviceAId == originDeviceId && p.DeviceBId == confirmingDeviceId);
            Assert.True(pairingExists);
        }
        finally
        {
            File.Delete(databasePath);
        }
    }
}
