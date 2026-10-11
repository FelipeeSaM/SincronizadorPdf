using Microsoft.EntityFrameworkCore;

namespace SincronizadorPdf.Backend.Api.Transferencia;

public sealed class TransferDbContext(DbContextOptions<TransferDbContext> options) : DbContext(options)
{
    public DbSet<PendingTransfer> PendingTransfers => Set<PendingTransfer>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<PendingTransfer>().HasKey(p => new { p.Hash, p.TargetDeviceId });
    }
}
