using System.Net;
using System.Net.Http.Json;
using SincronizadorPdf.Backend.Api.Highlights;

namespace SincronizadorPdf.Backend.Api.Tests.Highlights;

public class HighlightEndpointsTests
{
    private static Task<HttpResponseMessage> CriarAsync(
        HttpClient client, string hash, int page, string coordenadas, string? trechoTexto = null) =>
        client.PostAsJsonAsync("/highlights", new CreateHighlightRequest(hash, page, coordenadas, trechoTexto));

    private static Task<HttpResponseMessage> ListarAsync(HttpClient client, string hash) =>
        client.GetAsync($"/highlights?hash={hash}");

    private static Task<HttpResponseMessage> ApagarAsync(HttpClient client, Guid id) =>
        client.DeleteAsync($"/highlights/{id}");

    [Fact]
    public async Task Criar_ThenListar_RetornaOHighlightCriado()
    {
        using var factory = new HighlightApiFactory();
        var client = factory.CreateClient();
        var hash = "documento-1";

        var criarResponse = await CriarAsync(client, hash, page: 3, coordenadas: "[[10,20,30,40]]", trechoTexto: "trecho grifado");
        Assert.Equal(HttpStatusCode.Created, criarResponse.StatusCode);
        var criado = await criarResponse.Content.ReadFromJsonAsync<HighlightResponse>();
        Assert.NotEqual(Guid.Empty, criado!.Id);

        var listarResponse = await ListarAsync(client, hash);
        Assert.Equal(HttpStatusCode.OK, listarResponse.StatusCode);
        var highlights = await listarResponse.Content.ReadFromJsonAsync<List<HighlightResponse>>();
        Assert.Equal(
            [(criado.Id, 3, "[[10,20,30,40]]", "trecho grifado")],
            highlights!.Select(h => (h.Id, h.Page, h.Coordenadas, h.TrechoTexto)));
    }

    [Fact]
    public async Task Hash_EhInsensivelACaixa()
    {
        using var factory = new HighlightApiFactory();
        var client = factory.CreateClient();

        await CriarAsync(client, "ABCDEF", page: 1, coordenadas: "[[0,0,1,1]]");

        var response = await ListarAsync(client, "abcdef");

        var highlights = await response.Content.ReadFromJsonAsync<List<HighlightResponse>>();
        Assert.Single(highlights!);
    }

    [Fact]
    public async Task Listar_DocumentoSemHighlights_RetornaListaVazia()
    {
        using var factory = new HighlightApiFactory();
        var client = factory.CreateClient();

        var response = await ListarAsync(client, "documento-sem-highlights");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var highlights = await response.Content.ReadFromJsonAsync<List<HighlightResponse>>();
        Assert.Empty(highlights!);
    }

    [Fact]
    public async Task Listar_NaoInclueHighlightsDeOutrosDocumentos()
    {
        using var factory = new HighlightApiFactory();
        var client = factory.CreateClient();
        await CriarAsync(client, "documento-a", page: 1, coordenadas: "[[0,0,1,1]]");
        await CriarAsync(client, "documento-b", page: 1, coordenadas: "[[2,2,3,3]]");

        var response = await ListarAsync(client, "documento-a");

        var highlights = await response.Content.ReadFromJsonAsync<List<HighlightResponse>>();
        Assert.Single(highlights!);
        Assert.Equal("documento-a", highlights![0].Hash);
    }

    [Fact]
    public async Task Criar_MultiplosHighlightsParaOMesmoDocumento_TodosListados()
    {
        using var factory = new HighlightApiFactory();
        var client = factory.CreateClient();
        var hash = "documento-varios";
        await CriarAsync(client, hash, page: 1, coordenadas: "[[0,0,1,1]]");
        await CriarAsync(client, hash, page: 2, coordenadas: "[[2,2,3,3]]");

        var response = await ListarAsync(client, hash);

        var highlights = await response.Content.ReadFromJsonAsync<List<HighlightResponse>>();
        Assert.Equal(2, highlights!.Count);
    }

    [Fact]
    public async Task Apagar_RemoveOHighlight_NaoApareceMaisNaListagem()
    {
        using var factory = new HighlightApiFactory();
        var client = factory.CreateClient();
        var hash = "documento-apagar";
        var criarResponse = await CriarAsync(client, hash, page: 1, coordenadas: "[[0,0,1,1]]");
        var criado = await criarResponse.Content.ReadFromJsonAsync<HighlightResponse>();

        var apagarResponse = await ApagarAsync(client, criado!.Id);
        Assert.Equal(HttpStatusCode.NoContent, apagarResponse.StatusCode);

        var listarResponse = await ListarAsync(client, hash);
        var highlights = await listarResponse.Content.ReadFromJsonAsync<List<HighlightResponse>>();
        Assert.Empty(highlights!);
    }

    [Fact]
    public async Task Apagar_IdDesconhecido_RetornaNotFound()
    {
        using var factory = new HighlightApiFactory();
        var client = factory.CreateClient();

        var response = await ApagarAsync(client, Guid.NewGuid());

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Highlights_PersistemEntreReinicializacoesDoBackend()
    {
        var databasePath = Path.Combine(Path.GetTempPath(), $"highlights-restart-{Guid.NewGuid():N}.db");
        var hash = "documento-restart";

        try
        {
            using (var primeiraExecucao = new HighlightApiFactory(databasePath))
            {
                var client = primeiraExecucao.CreateClient();
                await CriarAsync(client, hash, page: 5, coordenadas: "[[1,2,3,4]]", trechoTexto: "sobrevive ao restart");
            }

            using var segundaExecucao = new HighlightApiFactory(databasePath);
            var segundoClient = segundaExecucao.CreateClient();

            var response = await ListarAsync(segundoClient, hash);

            Assert.Equal(HttpStatusCode.OK, response.StatusCode);
            var highlights = await response.Content.ReadFromJsonAsync<List<HighlightResponse>>();
            Assert.Single(highlights!);
            Assert.Equal("sobrevive ao restart", highlights![0].TrechoTexto);
        }
        finally
        {
            File.Delete(databasePath);
        }
    }
}
