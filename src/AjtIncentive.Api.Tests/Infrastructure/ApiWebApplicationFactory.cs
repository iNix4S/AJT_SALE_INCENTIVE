using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace AjtIncentive.Api.Tests.Infrastructure;

public class ApiWebApplicationFactory : WebApplicationFactory<Program>
{
    private readonly string? _connectionStringOverride;
    private readonly string _apiKey;
    private readonly IReadOnlyCollection<string> _roles;

    public ApiWebApplicationFactory()
        : this(
            connectionStringOverride: null,
            apiKey: "test-api-key",
            roles: ["Admin", "CalcRunner", "FormulaEditor", "MasterEditor", "SandboxRunner", "ChannelAdmin"])
    {
    }

    protected ApiWebApplicationFactory(
        string? connectionStringOverride = null,
        string apiKey = "test-api-key",
        IReadOnlyCollection<string>? roles = null)
    {
        _connectionStringOverride = connectionStringOverride;
        _apiKey = apiKey;
        _roles = roles is { Count: > 0 } ? roles : ["Admin"];
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((_, configBuilder) =>
        {
            var connectionString = _connectionStringOverride
                ?? "Server=localhost;Database=AJT_SALE_INCENTIVE;User Id=sa;Password=dummy;TrustServerCertificate=True;Encrypt=False;";

            var overrides = new Dictionary<string, string?>
            {
                ["ConnectionStrings:DefaultConnection"] = connectionString,
                ["ApiSecurity:ApiKey"] = _apiKey,
                ["ApiSecurity:Clients:0:Name"] = "api-admin",
                ["ApiSecurity:Clients:0:ApiKey"] = _apiKey,
                ["CalculationEngine:MT"] = "StoredProcedure",
                ["CalculationEngine:SI"] = "StoredProcedure",
                ["CalculationEngine:TT"] = "StoredProcedure",
                ["CalculationEngine:LAOS"] = "StoredProcedure"
            };

            var index = 0;
            foreach (var role in _roles)
            {
                overrides[$"ApiSecurity:Clients:0:Roles:{index}"] = role;
                index++;
            }

            configBuilder.AddInMemoryCollection(overrides);
        });
    }
}

public sealed class RealDbApiWebApplicationFactory : ApiWebApplicationFactory
{
    public RealDbApiWebApplicationFactory(string connectionString, string apiKey)
        : base(
            connectionString,
            apiKey,
            ["Admin", "CalcRunner", "FormulaEditor", "MasterEditor", "SandboxRunner", "ChannelAdmin"])
    {
    }
}

public sealed class RoleScopedApiWebApplicationFactory : ApiWebApplicationFactory
{
    public RoleScopedApiWebApplicationFactory(string apiKey, IReadOnlyCollection<string> roles)
        : base(connectionStringOverride: null, apiKey: apiKey, roles: roles)
    {
    }
}
