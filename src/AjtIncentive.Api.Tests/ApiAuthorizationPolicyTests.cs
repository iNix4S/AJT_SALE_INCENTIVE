using System.Net;
using System.Net.Http.Json;
using AjtIncentive.Api.Tests.Infrastructure;
using Xunit;

namespace AjtIncentive.Api.Tests;

public sealed class ApiAuthorizationPolicyTests
{
    [Fact]
    public async Task CalcRunner_Should_Not_Edit_Formula()
    {
        await using var factory = new RoleScopedApiWebApplicationFactory(
            apiKey: "calc-only-key",
            roles: ["CalcRunner"]);

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", "calc-only-key");

        var response = await client.PostAsJsonAsync("/api/v1/formulas/validate", new
        {
            formulaExpr = "[base_rate] * [weight_pct]"
        });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task FormulaEditor_Should_Not_Run_Calculation()
    {
        await using var factory = new RoleScopedApiWebApplicationFactory(
            apiKey: "formula-only-key",
            roles: ["FormulaEditor"]);

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", "formula-only-key");

        var response = await client.PostAsJsonAsync("/api/v1/calculation/MT/run", new
        {
            periodId = 1,
            engine = "StoredProcedure",
            approvedBy = "policy-test"
        });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task SandboxRunner_Should_Not_Edit_Master()
    {
        await using var factory = new RoleScopedApiWebApplicationFactory(
            apiKey: "sandbox-only-key",
            roles: ["SandboxRunner"]);

        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", "sandbox-only-key");

        var response = await client.GetAsync("/api/v1/masters/mst_channel?take=5");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}
