using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Microsoft.Extensions.Time.Testing;

namespace SincronizadorPdf.Backend.Api.Tests.Pareamento;

public sealed class PairingApiFactory(string? ownedDatabasePath = null) : WebApplicationFactory<Program>
{
    private readonly bool _ownsDatabaseFile = ownedDatabasePath is null;

    public string DatabasePath { get; } = ownedDatabasePath ?? Path.Combine(Path.GetTempPath(), $"pareamento-tests-{Guid.NewGuid():N}.db");

    public FakeTimeProvider TimeProvider { get; } = new(DateTimeOffset.UtcNow);

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ConnectionStrings:Pairing", $"Data Source={DatabasePath}");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<TimeProvider>();
            services.AddSingleton<TimeProvider>(TimeProvider);
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);
        if (disposing && _ownsDatabaseFile)
        {
            File.Delete(DatabasePath);
        }
    }
}
