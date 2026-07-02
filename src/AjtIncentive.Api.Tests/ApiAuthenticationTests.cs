using System.Net;
using System.Net.Http.Json;
using AjtIncentive.Api.Tests.Infrastructure;
using Xunit;

namespace AjtIncentive.Api.Tests;

public sealed class ApiAuthenticationTests : IClassFixture<ApiWebApplicationFactory>
{
    private readonly ApiWebApplicationFactory _factory;

    public ApiAuthenticationTests(ApiWebApplicationFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task HealthEndpoint_Should_Be_Accessible_Without_ApiKey()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/health");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task ProtectedEndpoint_Should_Return_Unauthorized_When_Missing_ApiKey()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/v1/formulas/validate", new
        {
            formulaExpr = "[base_rate] * [weight_pct]"
        });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task FormulaValidate_Should_Return_Success_When_ApiKey_Is_Provided()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", "test-api-key");

        var response = await client.PostAsJsonAsync("/api/v1/formulas/validate", new
        {
            formulaExpr = "[base_rate] * [weight_pct] * [goal_mult]"
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<Envelope<FormulaValidationData>>();
        Assert.NotNull(payload);
        Assert.True(payload!.Success);
        Assert.NotNull(payload.Data);
        Assert.True(payload.Data!.IsValid);
    }

    [Fact]
    public async Task FormulaValidate_Should_Fail_For_Unsupported_Variable()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", "test-api-key");

        var response = await client.PostAsJsonAsync("/api/v1/formulas/validate", new
        {
            formulaExpr = "[base_rate] + [hacker_var]"
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<Envelope<FormulaValidationData>>();
        Assert.NotNull(payload);
        Assert.True(payload!.Success);
        Assert.NotNull(payload.Data);
        Assert.False(payload.Data!.IsValid);
        Assert.Contains("Unsupported variables", payload.Data.ErrorMessage);
    }

    private sealed class Envelope<T>
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public T? Data { get; set; }
    }

    private sealed class FormulaValidationData
    {
        public bool IsValid { get; set; }
        public string? ErrorMessage { get; set; }
        public decimal? SampleResult { get; set; }
        public string[] Variables { get; set; } = Array.Empty<string>();
    }
}
