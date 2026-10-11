using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SincronizadorPdf.Backend.Api.Pareamento;
using SincronizadorPdf.Backend.Api.Transferencia;

namespace SincronizadorPdf.Backend.Api.Tests.Transferencia;

public class TransferEndpointsTests
{
    private static async Task PairDevicesAsync(TransferApiFactory factory, Guid deviceAId, Guid deviceBId)
    {
        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<PairingDbContext>();
        db.DevicePairings.Add(new DevicePairing
        {
            Id = Guid.NewGuid(),
            DeviceAId = deviceAId,
            DeviceBId = deviceBId,
            PairedAt = DateTimeOffset.UtcNow,
        });
        await db.SaveChangesAsync();
    }

    private static Task<HttpResponseMessage> UploadRawAsync(HttpClient client, Guid originDeviceId, Guid targetDeviceId, byte[] content) =>
        client.PostAsync($"/transferencias?originDeviceId={originDeviceId}&targetDeviceId={targetDeviceId}", new ByteArrayContent(content));

    private static async Task<string> UploadAsync(HttpClient client, Guid originDeviceId, Guid targetDeviceId, byte[] content)
    {
        var response = await UploadRawAsync(client, originDeviceId, targetDeviceId, content);
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<UploadTransferResponse>();
        return body!.Hash;
    }

    private static Task<HttpResponseMessage> DownloadAsync(HttpClient client, string hash, Guid deviceId) =>
        client.GetAsync($"/transferencias/{hash}?deviceId={deviceId}");

    private static Task<HttpResponseMessage> ConfirmAsync(HttpClient client, string hash, Guid deviceId) =>
        client.PostAsJsonAsync($"/transferencias/{hash}/confirmacoes", new ConfirmReceiptRequest(deviceId));

    [Fact]
    public async Task Upload_BetweenPairedDevices_ReturnsContentHash()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var targetDeviceId = Guid.NewGuid();
        await PairDevicesAsync(factory, originDeviceId, targetDeviceId);
        var content = "documento-pdf-bytes"u8.ToArray();
        var expectedHash = Convert.ToHexStringLower(SHA256.HashData(content));

        var response = await UploadRawAsync(client, originDeviceId, targetDeviceId, content);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<UploadTransferResponse>();
        Assert.Equal(expectedHash, body!.Hash);
    }

    [Fact]
    public async Task Upload_WithPairingInReverseDirection_Succeeds()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var targetDeviceId = Guid.NewGuid();
        await PairDevicesAsync(factory, targetDeviceId, originDeviceId);

        var response = await UploadRawAsync(client, originDeviceId, targetDeviceId, "conteudo-pareado-ao-contrario"u8.ToArray());

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    [Fact]
    public async Task Upload_BetweenUnpairedDevices_ReturnsForbidden()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var targetDeviceId = Guid.NewGuid();

        var response = await UploadRawAsync(client, originDeviceId, targetDeviceId, "conteudo-sem-pareamento"u8.ToArray());

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task FullCycle_UploadDownloadConfirm_DiscardsBytesAfterConfirmation()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var targetDeviceId = Guid.NewGuid();
        await PairDevicesAsync(factory, originDeviceId, targetDeviceId);
        var content = "ciclo-completo-de-transferencia"u8.ToArray();

        var hash = await UploadAsync(client, originDeviceId, targetDeviceId, content);

        var downloadResponse = await DownloadAsync(client, hash, targetDeviceId);
        Assert.Equal(HttpStatusCode.OK, downloadResponse.StatusCode);
        Assert.Equal(content, await downloadResponse.Content.ReadAsByteArrayAsync());

        var confirmResponse = await ConfirmAsync(client, hash, targetDeviceId);
        Assert.Equal(HttpStatusCode.NoContent, confirmResponse.StatusCode);

        var secondDownload = await DownloadAsync(client, hash, targetDeviceId);
        Assert.Equal(HttpStatusCode.NotFound, secondDownload.StatusCode);
    }

    [Fact]
    public async Task Download_ForDifferentDevice_ReturnsNotFound()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var targetDeviceId = Guid.NewGuid();
        await PairDevicesAsync(factory, originDeviceId, targetDeviceId);
        var hash = await UploadAsync(client, originDeviceId, targetDeviceId, "conteudo"u8.ToArray());

        var response = await DownloadAsync(client, hash, Guid.NewGuid());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Download_UnknownHash_ReturnsNotFound()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();

        var response = await DownloadAsync(client, new string('0', 64), Guid.NewGuid());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Confirm_ForDifferentDevice_DoesNotDiscardBytes()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var targetDeviceId = Guid.NewGuid();
        await PairDevicesAsync(factory, originDeviceId, targetDeviceId);
        var hash = await UploadAsync(client, originDeviceId, targetDeviceId, "conteudo-protegido"u8.ToArray());

        var confirmResponse = await ConfirmAsync(client, hash, Guid.NewGuid());
        Assert.Equal(HttpStatusCode.NotFound, confirmResponse.StatusCode);

        var downloadResponse = await DownloadAsync(client, hash, targetDeviceId);
        Assert.Equal(HttpStatusCode.OK, downloadResponse.StatusCode);
    }

    [Fact]
    public async Task Confirm_UnknownHash_ReturnsNotFound()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();

        var response = await ConfirmAsync(client, new string('0', 64), Guid.NewGuid());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task UploadingSameContentToDifferentTargets_CreatesIndependentTransfers()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var firstTarget = Guid.NewGuid();
        var secondTarget = Guid.NewGuid();
        await PairDevicesAsync(factory, originDeviceId, firstTarget);
        await PairDevicesAsync(factory, originDeviceId, secondTarget);
        var content = "conteudo-compartilhado-entre-transferencias"u8.ToArray();

        var firstHash = await UploadAsync(client, originDeviceId, firstTarget, content);
        var secondHash = await UploadAsync(client, originDeviceId, secondTarget, content);

        Assert.Equal(firstHash, secondHash);

        var firstDownload = await DownloadAsync(client, firstHash, firstTarget);
        Assert.Equal(HttpStatusCode.OK, firstDownload.StatusCode);

        var secondDownload = await DownloadAsync(client, secondHash, secondTarget);
        Assert.Equal(HttpStatusCode.OK, secondDownload.StatusCode);
    }

    [Fact]
    public async Task ReuploadingSameContent_DoesNotCreateDuplicateRecord()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var originDeviceId = Guid.NewGuid();
        var targetDeviceId = Guid.NewGuid();
        await PairDevicesAsync(factory, originDeviceId, targetDeviceId);
        var content = "conteudo-reenviado"u8.ToArray();

        var firstHash = await UploadAsync(client, originDeviceId, targetDeviceId, content);
        var secondHash = await UploadAsync(client, originDeviceId, targetDeviceId, content);

        Assert.Equal(firstHash, secondHash);

        using var scope = factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<TransferDbContext>();
        var count = await db.PendingTransfers.CountAsync(p => p.Hash == firstHash);
        Assert.Equal(1, count);
    }

    [Fact]
    public async Task TransferState_PersistsAcrossBackendRestart()
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"transferencia-restart-{Guid.NewGuid():N}.db");
        var originDeviceId = Guid.NewGuid();
        var targetDeviceId = Guid.NewGuid();
        var content = "sobrevive-ao-restart"u8.ToArray();

        try
        {
            string hash;
            using (var firstRun = new TransferApiFactory(databasePath))
            {
                var client = firstRun.CreateClient();
                await PairDevicesAsync(firstRun, originDeviceId, targetDeviceId);
                hash = await UploadAsync(client, originDeviceId, targetDeviceId, content);
            }

            using var secondRun = new TransferApiFactory(databasePath);
            using var scope = secondRun.Services.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<TransferDbContext>();

            var transferExists = await db.PendingTransfers.AnyAsync(p => p.Hash == hash);
            Assert.True(transferExists);
        }
        finally
        {
            File.Delete(databasePath);
        }
    }
}
