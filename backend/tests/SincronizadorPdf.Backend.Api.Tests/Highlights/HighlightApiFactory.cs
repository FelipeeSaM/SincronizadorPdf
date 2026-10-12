using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;

namespace SincronizadorPdf.Backend.Api.Tests.Highlights;

public sealed class HighlightApiFactory(string? ownedDatabasePath = null) : WebApplicationFactory<Program>
{
    private readonly bool _ownsDatabaseFile = ownedDatabasePath is null;

    public string DatabasePath { get; } = ownedDatabasePath ?? Path.Combine(Path.GetTempPath(), $"highlights-tests-{Guid.NewGuid():N}.db");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseSetting("ConnectionStrings:Highlights", $"Data Source={DatabasePath}");
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
