using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using AjtIncentive.Domain.Entities;

namespace AjtIncentive.Infrastructure.Data.Configurations;

public class EmployeeConfiguration : IEntityTypeConfiguration<Employee>
{
    public void Configure(EntityTypeBuilder<Employee> builder)
    {
        builder.ToTable("mst_employee");

        builder.HasKey(e => e.EmployeeId);

        builder.Property(e => e.EmployeeCode)
               .HasMaxLength(50)
               .IsRequired();

        builder.Property(e => e.FullName)
               .HasMaxLength(200)
               .IsRequired();

        builder.Property(e => e.JobFunction)
               .HasMaxLength(100);

        builder.Property(e => e.Department)
               .HasMaxLength(100);
    }
}
