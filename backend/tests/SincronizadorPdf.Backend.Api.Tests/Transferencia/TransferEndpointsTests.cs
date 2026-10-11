using System.Net;
using System.Net.Http.Json;
using System.Security.Cryptography;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using SincronizadorPdf.Backend.Api.Transferencia;

namespace SincronizadorPdf.Backend.Api.Tests.Transferencia;

public class TransferEndpointsTests
{
    private static async Task<string> UploadAsync(HttpClient client, Guid targetDeviceId, byte[] content)
    {
        var response = await client.PostAsync($"/transferencias?deviceId={targetDeviceId}", new ByteArrayContent(content));
        response.EnsureSuccessStatusCode();
        var body = await response.Content.ReadFromJsonAsync<UploadTransferResponse>();
        return body!.Hash;
    }

    private static Task<HttpResponseMessage> DownloadAsync(HttpClient client, string hash, Guid deviceId) =>
        client.GetAsync($"/transferencias/{hash}?deviceId={deviceId}");

    private static Task<HttpResponseMessage> ConfirmAsync(HttpClient client, string hash, Guid deviceId) =>
        client.PostAsJsonAsync($"/transferencias/{hash}/confirmacoes", new ConfirmReceiptRequest(deviceId));

    [Fact]
    public async Task Upload_ReturnsContentHash()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var content = "documento-pdf-bytes"u8.ToArray();
        var expectedHash = Convert.ToHexStringLower(SHA256.HashData(content));

        var response = await client.PostAsync($"/transferencias?deviceId={Guid.NewGuid()}", new ByteArrayContent(content));

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<UploadTransferResponse>();
        Assert.Equal(expectedHash, body!.Hash);
    }

    [Fact]
    public async Task FullCycle_UploadDownloadConfirm_DiscardsBytesAfterConfirmation()
    {
        using var factory = new TransferApiFactory();
        var client = factory.CreateClient();
        var targetDeviceId = Guid.NewGuid();
        var content = "ciclo-completo-de-transferencia"u8.ToArray();

        var hash = await UploadAsync(client, targetDeviceId, content);

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
        var targetDeviceId = Guid.NewGuid();
        var hash = await UploadAsync(client, targetDeviceId, "conteudo"u8.ToArray());

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
        var targetDeviceId = Guid.NewGuid();
        var hash = await UploadAsync(client, targetDeviceId, "conteudo-protegido"u8.ToArray());

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
        var firstTarget = Guid.NewGuid();
        var secondTarget = Guid.NewGuid();
        var content = "conteudo-compartilhado-entre-transferencias"u8.ToArray();

        var firstHash = await UploadAsync(client, firstTarget, content);
        var secondHash = await UploadAsync(client, secondTarget, content);

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
        var targetDeviceId = Guid.NewGuid();
        var content = "conteudo-reenviado"u8.ToArray();

        var firstHash = await UploadAsync(client, targetDeviceId, content);
        var secondHash = await UploadAsync(client, targetDeviceId, content);

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
        var targetDeviceId = Guid.NewGuid();
        var content = "sobrevive-ao-restart"u8.ToArray();

        try
        {
            string hash;
            using (var firstRun = new TransferApiFactory(databasePath))
            {
                var client = firstRun.CreateClient();
                hash = await UploadAsync(client, targetDeviceId, content);
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
