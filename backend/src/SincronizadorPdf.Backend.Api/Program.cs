using Microsoft.EntityFrameworkCore;
using SincronizadorPdf.Backend.Api.Pareamento;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton(TimeProvider.System);

var pairingConnectionString = builder.Configuration.GetConnectionString("Pairing")
    ?? $"Data Source={Path.Combine(builder.Environment.ContentRootPath, "pareamento.db")}";
builder.Services.AddDbContext<PairingDbContext>(options => options.UseSqlite(pairingConnectionString));
builder.Services.AddScoped<PairingService>();

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    scope.ServiceProvider.GetRequiredService<PairingDbContext>().Database.EnsureCreated();
}

app.UseHttpsRedirection();
app.MapPairingEndpoints();

app.Run();

public partial class Program;
