using Microsoft.EntityFrameworkCore;

namespace SincronizadorPdf.Backend.Api.Pareamento;

public sealed class PairingDbContext(DbContextOptions<PairingDbContext> options) : DbContext(options)
{
    public DbSet<PairingCode> PairingCodes => Set<PairingCode>();
    public DbSet<DevicePairing> DevicePairings => Set<DevicePairing>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<PairingCode>().HasKey(p => p.Code);
        modelBuilder.Entity<DevicePairing>().HasKey(p => p.Id);
    }
}
