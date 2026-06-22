using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using AjtIncentive.Domain.Entities;

namespace AjtIncentive.Infrastructure.Data.Configurations;

public class PeriodConfiguration : IEntityTypeConfiguration<Period>
{
    public void Configure(EntityTypeBuilder<Period> builder)
    {
        builder.ToTable("mst_period");

        builder.HasKey(e => e.PeriodId);

        builder.Property(e => e.PeriodName)
               .HasMaxLength(50)
               .IsRequired();
    }
}
