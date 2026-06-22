using Microsoft.EntityFrameworkCore;
using AjtIncentive.Infrastructure.Data;
using AjtIncentive.Application.Interfaces;
using AjtIncentive.Infrastructure.StoredProcedures;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorPages();

var connectionString =
    Environment.GetEnvironmentVariable("DB_CONNECTION_STRING")
    ?? builder.Configuration.GetConnectionString("DefaultConnection")
    ?? "";

if (string.IsNullOrWhiteSpace(connectionString))
{
    throw new InvalidOperationException("DefaultConnection is missing. Set DB_CONNECTION_STRING or appsettings connection string.");
}

builder.Services.AddDbContext<AjtIncentiveDbContext>(options =>
    options.UseSqlServer(connectionString));

builder.Services.AddScoped<ICalculationService>(sp => 
    new MtCalculationRunner(connectionString));

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

app.UseHttpsRedirection();

app.UseRouting();

app.UseAuthorization();

app.MapStaticAssets();
app.MapRazorPages()
   .WithStaticAssets();

app.Run();
