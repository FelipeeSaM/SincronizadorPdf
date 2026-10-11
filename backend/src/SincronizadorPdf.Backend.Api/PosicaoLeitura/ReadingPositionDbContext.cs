using Microsoft.EntityFrameworkCore;

namespace SincronizadorPdf.Backend.Api.PosicaoLeitura;

public sealed class ReadingPositionDbContext(DbContextOptions<ReadingPositionDbContext> options) : DbContext(options)
{
    public DbSet<ReadingPosition> ReadingPositions => Set<ReadingPosition>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<ReadingPosition>().HasKey(p => p.Hash);
    }
}
