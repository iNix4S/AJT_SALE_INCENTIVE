using System.Net;
using System.Net.Http.Json;
using System.Text.Json.Nodes;
using AjtIncentive.Api.Tests.Infrastructure;
using Xunit;

namespace AjtIncentive.Api.Tests;

public sealed class ApiDatabaseIntegrationTests
{
    [Fact]
    public async Task CalculationRun_Status_Results_Should_Work_Against_Real_Db()
    {
        var context = CreateContextOrSkip();
        if (context is null)
        {
            return;
        }

        await using var factory = new RealDbApiWebApplicationFactory(context.ConnectionString, context.ApiKey);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", context.ApiKey);

        var runResponse = await client.PostAsJsonAsync("/api/v1/calculation/MT/run", new
        {
            periodId = context.PeriodId,
            engine = "StoredProcedure",
            approvedBy = "api-db-test"
        });

        Assert.Equal(HttpStatusCode.OK, runResponse.StatusCode);
        var runPayload = await runResponse.Content.ReadFromJsonAsync<Envelope<JsonObject>>();
        Assert.NotNull(runPayload);
        Assert.True(runPayload!.Success);

        var calcRunId = runPayload.Data?["calcRunId"]?.GetValue<int>() ?? 0;
        Assert.True(calcRunId > 0);

        var statusResponse = await client.GetAsync($"/api/v1/calculation/runs/{calcRunId}");
        Assert.Equal(HttpStatusCode.OK, statusResponse.StatusCode);

        var statusPayload = await statusResponse.Content.ReadFromJsonAsync<Envelope<JsonObject>>();
        Assert.NotNull(statusPayload);
        Assert.True(statusPayload!.Success);
        Assert.Equal(calcRunId, statusPayload.Data?["calcRunId"]?.GetValue<int>());

        var resultsResponse = await client.GetAsync($"/api/v1/calculation/MT/results?periodId={context.PeriodId}");
        Assert.Equal(HttpStatusCode.OK, resultsResponse.StatusCode);

        var resultsPayload = await resultsResponse.Content.ReadFromJsonAsync<Envelope<JsonArray>>();
        Assert.NotNull(resultsPayload);
        Assert.True(resultsPayload!.Success);
        Assert.NotNull(resultsPayload.Data);
    }

    [Fact]
    public async Task SandboxCompare_Should_Work_Against_Real_Db()
    {
        var context = CreateContextOrSkip();
        if (context is null)
        {
            return;
        }

        await using var factory = new RealDbApiWebApplicationFactory(context.ConnectionString, context.ApiKey);
        using var client = factory.CreateClient();
        client.DefaultRequestHeaders.Add("X-API-Key", context.ApiKey);

        var runResponse = await client.PostAsJsonAsync("/api/v1/calculation/MT/run", new
        {
            periodId = context.PeriodId,
            engine = "StoredProcedure",
            approvedBy = "api-db-test"
        });

        Assert.Equal(HttpStatusCode.OK, runResponse.StatusCode);
        var runPayload = await runResponse.Content.ReadFromJsonAsync<Envelope<JsonObject>>();
        var baselineCalcRunId = runPayload?.Data?["calcRunId"]?.GetValue<int>() ?? 0;
        Assert.True(baselineCalcRunId > 0);

        var sandboxRunResponse = await client.PostAsJsonAsync("/api/v1/calculation/sandbox/run", new
        {
            targetChannel = "MT",
            sourceTransactionChannel = "MT",
            periodId = context.PeriodId,
            engine = "NCalc",
            formulaSetRef = "draft",
            persist = true,
            approvedBy = "api-db-test"
        });

        Assert.Equal(HttpStatusCode.OK, sandboxRunResponse.StatusCode);
        var sandboxRunPayload = await sandboxRunResponse.Content.ReadFromJsonAsync<Envelope<JsonObject>>();
        Assert.NotNull(sandboxRunPayload);
        Assert.True(sandboxRunPayload!.Success);

        var sandboxRunId = sandboxRunPayload.Data?["sandboxRunId"]?.GetValue<long>() ?? 0;
        Assert.True(sandboxRunId > 0);

        var compareResponse = await client.PostAsJsonAsync("/api/v1/calculation/sandbox/compare", new
        {
            sandboxRunId,
            baselineCalcRunId
        });

        Assert.Equal(HttpStatusCode.OK, compareResponse.StatusCode);
        var comparePayload = await compareResponse.Content.ReadFromJsonAsync<Envelope<JsonObject>>();
        Assert.NotNull(comparePayload);
        Assert.True(comparePayload!.Success);

        var sandboxRows = comparePayload.Data?["sandboxRows"]?.GetValue<int>() ?? -1;
        var baselineRows = comparePayload.Data?["baselineRows"]?.GetValue<int>() ?? -1;
        Assert.True(sandboxRows >= 0);
        Assert.True(baselineRows >= 0);
    }

    private static DbTestContext? CreateContextOrSkip()
    {
        var enabled = Environment.GetEnvironmentVariable("AJT_API_TEST_ENABLE_DB");
        if (!string.Equals(enabled, "true", StringComparison.OrdinalIgnoreCase))
        {
            return null;
        }

        var connectionString = Environment.GetEnvironmentVariable("AJT_API_TEST_DB_CONNECTION")
            ?? Environment.GetEnvironmentVariable("DB_CONNECTION_STRING");

        if (string.IsNullOrWhiteSpace(connectionString))
        {
            return null;
        }

        var apiKey = Environment.GetEnvironmentVariable("AJT_API_TEST_API_KEY");
        if (string.IsNullOrWhiteSpace(apiKey))
        {
            apiKey = "test-db-api-key";
        }

        var periodText = Environment.GetEnvironmentVariable("AJT_API_TEST_PERIOD_ID");
        var periodId = 1;
        if (!string.IsNullOrWhiteSpace(periodText) && int.TryParse(periodText, out var parsed) && parsed > 0)
        {
            periodId = parsed;
        }

        return new DbTestContext(connectionString, apiKey, periodId);
    }

    private sealed record DbTestContext(string ConnectionString, string ApiKey, int PeriodId);

    private sealed class Envelope<T>
    {
        public bool Success { get; set; }
        public string? Message { get; set; }
        public T? Data { get; set; }
    }
}
