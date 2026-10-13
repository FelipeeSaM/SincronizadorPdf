using Microsoft.EntityFrameworkCore;
using SincronizadorPdf.Backend.Api;
using SincronizadorPdf.Backend.Api.Highlights;
using SincronizadorPdf.Backend.Api.Pareamento;
using SincronizadorPdf.Backend.Api.PosicaoLeitura;
using SincronizadorPdf.Backend.Api.Transferencia;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton(TimeProvider.System);

var pairingConnectionString = builder.Configuration.GetConnectionString("Pairing")
    ?? $"Data Source={Path.Combine(builder.Environment.ContentRootPath, "pareamento.db")}";
builder.Services.AddDbContext<PairingDbContext>(options => options.UseSqlite(pairingConnectionString));
builder.Services.AddScoped<PairingService>();

var transferConnectionString = builder.Configuration.GetConnectionString("Transferencia")
    ?? $"Data Source={Path.Combine(builder.Environment.ContentRootPath, "transferencia.db")}";
builder.Services.AddDbContext<TransferDbContext>(options => options.UseSqlite(transferConnectionString));
builder.Services.AddScoped<TransferService>();

var readingPositionConnectionString = builder.Configuration.GetConnectionString("PosicaoLeitura")
    ?? $"Data Source={Path.Combine(builder.Environment.ContentRootPath, "posicao-leitura.db")}";
builder.Services.AddDbContext<ReadingPositionDbContext>(options => options.UseSqlite(readingPositionConnectionString));
builder.Services.AddScoped<ReadingPositionService>();

var highlightConnectionString = builder.Configuration.GetConnectionString("Highlights")
    ?? $"Data Source={Path.Combine(builder.Environment.ContentRootPath, "highlights.db")}";
builder.Services.AddDbContext<HighlightDbContext>(options => options.UseSqlite(highlightConnectionString));
builder.Services.AddScoped<HighlightService>();

// Modo LAN (ver #24): o Backend roda como processo filho do app desktop,
// nascendo e morrendo com ele, acessado só pela rede local — sem esse env
// var (ex: testes com WebApplicationFactory), nada muda no comportamento
// de sempre.
var lanModeAtiva = Environment.GetEnvironmentVariable("SINCRONIZADOR_PDF_LAN_MODE") == "1";
var portaLan = lanModeAtiva ? LanModePortSelector.SelectPort() : (int?)null;
if (portaLan is { } porta)
{
    builder.WebHost.UseUrls($"http://0.0.0.0:{porta}");
}

// Id deste PC (ver #25), repassado pelo app desktop via env var porque é
// lá que o `DeviceIdStore` vive — sem ele não há como o celular desambiguar
// entre múltiplos backends SincronizadorPdf na mesma rede, então o anúncio
// mDNS fica desativado (mesma tolerância a configuração ausente que o
// resto do modo LAN já tem).
var deviceId = Environment.GetEnvironmentVariable("SINCRONIZADOR_PDF_DEVICE_ID");

var app = builder.Build();

// Migrate() em vez de EnsureCreated(): aplica o schema via migrations
// versionadas, então uma mudança de modelo nunca deixa um banco
// existente com colunas desatualizadas (ver #17).
using (var scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<PairingDbContext>().Database.Migrate();
    scope.ServiceProvider.GetRequiredService<TransferDbContext>().Database.Migrate();
    scope.ServiceProvider.GetRequiredService<ReadingPositionDbContext>().Database.Migrate();
    scope.ServiceProvider.GetRequiredService<HighlightDbContext>().Database.Migrate();
}

// Em modo LAN não há certificado válido para o IP da rede local, então o
// redirect para HTTPS quebraria o acesso via HTTP puro (ver #24).
if (!lanModeAtiva)
{
    app.UseHttpsRedirection();
}

app.MapPairingEndpoints();
app.MapTransferEndpoints();
app.MapReadingPositionEndpoints();
app.MapHighlightEndpoints();

if (portaLan is { } portaEfetiva)
{
    // StartAsync/WaitForShutdownAsync (em vez de Run) para poder anunciar a
    // porta só depois do Kestrel já estar de fato escutando — sem isso, o
    // app desktop podia tentar conectar e receber "connection refused" por
    // chegar antes do bind acontecer. O try/finally com DisposeAsync abaixo
    // replica o que Run()/RunAsync() fazem por baixo dos panos, já que
    // chamar StartAsync/WaitForShutdownAsync direto pula esse descarte.
    // Só é criado depois de StartAsync, com a porta já efetiva (ver #25):
    // anunciar a porta padrão fixa seria errado sempre que ela estivesse
    // ocupada e o LanModePortSelector tivesse escolhido outra.
    MdnsAnnouncer? mdnsAnnouncer = null;
    try
    {
        await app.StartAsync();

        // O app desktop lê esta linha do stdout do processo filho para
        // saber em qual porta o Backend ficou disponível (porta padrão ou,
        // se ocupada, uma porta livre escolhida pelo SO — ver
        // LanModePortSelector).
        Console.WriteLine($"SINCRONIZADOR_PDF_PORT={portaEfetiva}");
        Console.Out.Flush();

        if (deviceId is { Length: > 0 })
        {
            try
            {
                mdnsAnnouncer = new MdnsAnnouncer(portaEfetiva, deviceId);
            }
            catch (Exception ex)
            {
                // O anúncio mDNS é só uma conveniência de descoberta (ver
                // #25) — se a rede não suportar multicast (ex: sem
                // interface ativa, sandboxing), o Backend continua
                // funcionando normalmente por HTTP direto, só sem anúncio
                // automático, em vez de derrubar o processo inteiro.
                Console.Error.WriteLine($"Falha ao iniciar o anúncio mDNS: {ex}");
            }
        }

        await app.WaitForShutdownAsync();
    }
    finally
    {
        mdnsAnnouncer?.Dispose();
        await app.DisposeAsync();
    }
}
else
{
    app.Run();
}

public partial class Program;
