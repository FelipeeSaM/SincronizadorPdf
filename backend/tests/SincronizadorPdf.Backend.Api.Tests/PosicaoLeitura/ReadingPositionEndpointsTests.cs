using System.Net;
using System.Net.Http.Json;
using SincronizadorPdf.Backend.Api.PosicaoLeitura;

namespace SincronizadorPdf.Backend.Api.Tests.PosicaoLeitura;

public class ReadingPositionEndpointsTests
{
    private static Task<HttpResponseMessage> SetAsync(
        HttpClient client, string hash, Guid deviceId, int page, double scrollPercentage, DateTimeOffset updatedAt) =>
        client.PutAsJsonAsync($"/posicoes-leitura/{hash}", new SetReadingPositionRequest(deviceId, page, scrollPercentage, updatedAt));

    private static Task<HttpResponseMessage> GetAsync(HttpClient client, string hash) =>
        client.GetAsync($"/posicoes-leitura/{hash}");

    [Fact]
    public async Task Set_ThenGet_ReturnsStoredPosition()
    {
        using var factory = new ReadingPositionApiFactory();
        var client = factory.CreateClient();
        var hash = "documento-1";
        var deviceId = Guid.NewGuid();
        var updatedAt = DateTimeOffset.UtcNow;

        var setResponse = await SetAsync(client, hash, deviceId, page: 10, scrollPercentage: 0.42, updatedAt);
        Assert.Equal(HttpStatusCode.NoContent, setResponse.StatusCode);

        var getResponse = await GetAsync(client, hash);
        Assert.Equal(HttpStatusCode.OK, getResponse.StatusCode);
        var body = await getResponse.Content.ReadFromJsonAsync<ReadingPositionResponse>();
        Assert.Equal(hash, body!.Hash);
        Assert.Equal(10, body.Page);
        Assert.Equal(0.42, body.ScrollPercentage);
        Assert.Equal(updatedAt, body.UpdatedAt);
    }

    [Fact]
    public async Task Get_UnknownDocument_ReturnsNotFound()
    {
        using var factory = new ReadingPositionApiFactory();
        var client = factory.CreateClient();

        var response = await GetAsync(client, "documento-desconhecido");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Set_WithNewerTimestamp_OverwritesOlderPosition()
    {
        using var factory = new ReadingPositionApiFactory();
        var client = factory.CreateClient();
        var hash = "documento-2";
        var deviceA = Guid.NewGuid();
        var deviceB = Guid.NewGuid();
        var olderTimestamp = DateTimeOffset.UtcNow;
        var newerTimestamp = olderTimestamp.AddMinutes(5);

        var firstResponse = await SetAsync(client, hash, deviceA, page: 1, scrollPercentage: 0.1, olderTimestamp);
        Assert.Equal(HttpStatusCode.NoContent, firstResponse.StatusCode);

        var secondResponse = await SetAsync(client, hash, deviceB, page: 20, scrollPercentage: 0.9, newerTimestamp);
        Assert.Equal(HttpStatusCode.NoContent, secondResponse.StatusCode);

        var response = await GetAsync(client, hash);
        var body = await response.Content.ReadFromJsonAsync<ReadingPositionResponse>();
        Assert.Equal(20, body!.Page);
        Assert.Equal(0.9, body.ScrollPercentage);
        Assert.Equal(newerTimestamp, body.UpdatedAt);
    }

    [Fact]
    public async Task Set_WithOlderTimestampArrivingAfterNewer_DoesNotOverwrite()
    {
        // Simula o Backend ficar fora do ar: o Dispositivo A grava às 10h mas só chega ao
        // Backend depois que o Dispositivo B, já online, grava às 12h. A ordem de chegada é
        // B-depois-A, mas o timestamp de A (10h) é mais antigo e não deve vencer (ADR-0005).
        using var factory = new ReadingPositionApiFactory();
        var client = factory.CreateClient();
        var hash = "documento-3";
        var deviceA = Guid.NewGuid();
        var deviceB = Guid.NewGuid();
        var timestampA = new DateTimeOffset(2026, 1, 1, 10, 0, 0, TimeSpan.Zero);
        var timestampB = new DateTimeOffset(2026, 1, 1, 12, 0, 0, TimeSpan.Zero);

        await SetAsync(client, hash, deviceB, page: 20, scrollPercentage: 0.9, timestampB);
        var staleResponse = await SetAsync(client, hash, deviceA, page: 1, scrollPercentage: 0.1, timestampA);

        Assert.Equal(HttpStatusCode.OK, staleResponse.StatusCode);
        var staleBody = await staleResponse.Content.ReadFromJsonAsync<ReadingPositionResponse>();
        Assert.Equal(20, staleBody!.Page);
        Assert.Equal(timestampB, staleBody.UpdatedAt);

        var response = await GetAsync(client, hash);
        var body = await response.Content.ReadFromJsonAsync<ReadingPositionResponse>();
        Assert.Equal(20, body!.Page);
        Assert.Equal(0.9, body.ScrollPercentage);
        Assert.Equal(timestampB, body.UpdatedAt);
    }

    [Fact]
    public async Task Set_WithSameTimestamp_DoesNotOverwriteExisting()
    {
        using var factory = new ReadingPositionApiFactory();
        var client = factory.CreateClient();
        var hash = "documento-4";
        var deviceA = Guid.NewGuid();
        var deviceB = Guid.NewGuid();
        var timestamp = DateTimeOffset.UtcNow;

        await SetAsync(client, hash, deviceA, page: 5, scrollPercentage: 0.5, timestamp);
        var secondResponse = await SetAsync(client, hash, deviceB, page: 99, scrollPercentage: 0.99, timestamp);

        Assert.Equal(HttpStatusCode.OK, secondResponse.StatusCode);
        var response = await GetAsync(client, hash);
        var body = await response.Content.ReadFromJsonAsync<ReadingPositionResponse>();
        Assert.Equal(5, body!.Page);
        Assert.Equal(0.5, body.ScrollPercentage);
    }

    [Fact]
    public async Task Hash_IsCaseInsensitive()
    {
        using var factory = new ReadingPositionApiFactory();
        var client = factory.CreateClient();
        var deviceId = Guid.NewGuid();
        var updatedAt = DateTimeOffset.UtcNow;

        await SetAsync(client, "ABCDEF", deviceId, page: 3, scrollPercentage: 0.3, updatedAt);

        var response = await GetAsync(client, "abcdef");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<ReadingPositionResponse>();
        Assert.Equal(3, body!.Page);
    }

    [Fact]
    public async Task Position_PersistsAcrossBackendRestart()
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"posicao-leitura-restart-{Guid.NewGuid():N}.db");
        var hash = "documento-restart";
        var deviceId = Guid.NewGuid();
        var updatedAt = DateTimeOffset.UtcNow;

        try
        {
            using (var firstRun = new ReadingPositionApiFactory(databasePath))
            {
                var client = firstRun.CreateClient();
                await SetAsync(client, hash, deviceId, page: 7, scrollPercentage: 0.33, updatedAt);
            }

            using var secondRun = new ReadingPositionApiFactory(databasePath);
            var secondClient = secondRun.CreateClient();

            var response = await GetAsync(secondClient, hash);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var body = await response.Content.ReadFromJsonAsync<ReadingPositionResponse>();
            Assert.Equal(7, body!.Page);
            Assert.Equal(0.33, body.ScrollPercentage);
        }
        finally
        {
            File.Delete(databasePath);
        }
    }
}
