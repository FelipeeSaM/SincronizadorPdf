using Microsoft.EntityFrameworkCore;
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

app.UseHttpsRedirection();
app.MapPairingEndpoints();
app.MapTransferEndpoints();
app.MapReadingPositionEndpoints();
app.MapHighlightEndpoints();

app.Run();

public partial class Program;
