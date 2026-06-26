using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using AjtIncentive.Domain.Entities;

namespace AjtIncentive.Infrastructure.Data.Configurations;

public class IncentiveResultConfiguration : IEntityTypeConfiguration<IncentiveResult>
{
    public void Configure(EntityTypeBuilder<IncentiveResult> builder)
    {
        builder.ToTable("incentive_results");

        builder.HasKey(e => e.CalcRunId); // Assuming CalcRunId is the PK or part of it, maybe composite?

        builder.Property(e => e.EmployeeCode)
               .HasMaxLength(50);

        builder.Property(e => e.FullName)
               .HasMaxLength(200);

        builder.Property(e => e.IncentiveAmount)
               .HasColumnType("decimal(18,2)");
    }
}
