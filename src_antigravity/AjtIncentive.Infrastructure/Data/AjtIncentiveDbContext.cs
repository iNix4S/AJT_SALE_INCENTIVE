using Microsoft.EntityFrameworkCore;
using AjtIncentive.Domain.Entities;

namespace AjtIncentive.Infrastructure.Data;

public class AjtIncentiveDbContext : DbContext
{
    public AjtIncentiveDbContext(DbContextOptions<AjtIncentiveDbContext> options)
        : base(options)
    {
    }

    public DbSet<Period> Periods => Set<Period>();
    public DbSet<Employee> Employees => Set<Employee>();
    public DbSet<IncentiveResult> IncentiveResults => Set<IncentiveResult>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.ApplyConfigurationsFromAssembly(typeof(AjtIncentiveDbContext).Assembly);
        base.OnModelCreating(modelBuilder);
    }
}
