using Microsoft.EntityFrameworkCore;

namespace SincronizadorPdf.Backend.Api.Highlights;

public sealed class HighlightDbContext(DbContextOptions<HighlightDbContext> options) : DbContext(options)
{
    public DbSet<Highlight> Highlights => Set<Highlight>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Highlight>().HasKey(h => h.Id);
    }
}
