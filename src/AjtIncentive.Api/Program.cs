using AjtIncentive.Api.Contracts;
using AjtIncentive.Api.Security;
using AjtIncentive.Api.Services;
using AjtIncentive.Application.Interfaces;
using AjtIncentive.Domain.Entities;
using AjtIncentive.Infrastructure.CalculationEngines;
using AjtIncentive.Infrastructure.StoredProcedures;
using Dapper;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;
using Microsoft.OpenApi.Models;
using System.Threading.RateLimiting;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddAuthentication(ApiKeyAuthenticationHandler.SchemeName)
    .AddScheme<AuthenticationSchemeOptions, ApiKeyAuthenticationHandler>(
        ApiKeyAuthenticationHandler.SchemeName, _ => { });
builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("CanRunCalculation", policy =>
        policy.RequireRole("CalcRunner", "Admin"));

    options.AddPolicy("CanEditFormula", policy =>
        policy.RequireRole("FormulaEditor", "Admin"));

    options.AddPolicy("CanEditMaster", policy =>
        policy.RequireRole("MasterEditor", "Admin"));

    options.AddPolicy("CanRunSandbox", policy =>
        policy.RequireRole("SandboxRunner", "Admin"));

    options.AddPolicy("CanManageChannel", policy =>
        policy.RequireRole("ChannelAdmin", "Admin"));
});

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("api", context =>
    {
        var key = context.Request.Headers["X-API-Key"].ToString();
        if (string.IsNullOrWhiteSpace(key))
        {
            key = context.Connection.RemoteIpAddress?.ToString() ?? "anonymous";
        }

        return RateLimitPartition.GetFixedWindowLimiter(
            key,
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 60,
                Window = TimeSpan.FromMinutes(1),
                QueueProcessingOrder = QueueProcessingOrder.OldestFirst,
                QueueLimit = 0
            });
    });
});

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "AJT Incentive Calculation API",
        Version = "v1"
    });

    options.AddSecurityDefinition("ApiKey", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.ApiKey,
        Name = "X-API-Key",
        In = ParameterLocation.Header,
        Description = "API key for system-to-system access"
    });

    options.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme
            {
                Reference = new OpenApiReference
                {
                    Type = ReferenceType.SecurityScheme,
                    Id = "ApiKey"
                }
            },
            Array.Empty<string>()
        }
    });
});

// หมายเหตุ: resolve connection string แบบ lazy (ผ่าน factory ที่อ่าน IConfiguration ตอน resolve)
// เพื่อให้ WebApplicationFactory (integration tests) override ConnectionStrings:DefaultConnection ได้จริง
// ถ้า resolve ทันทีตอนนี้ (ก่อน builder.Build()) จะได้ค่าจาก appsettings.json ดั้งเดิมเสมอ ไม่ว่าจะ override อย่างไร
builder.Services.AddSingleton(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var value =
        Environment.GetEnvironmentVariable("DB_CONNECTION_STRING")
        ?? config.GetConnectionString("DefaultConnection")
        ?? "";

    if (string.IsNullOrWhiteSpace(value))
    {
        throw new InvalidOperationException("DefaultConnection is missing. Set DB_CONNECTION_STRING or appsettings connection string.");
    }

    return new ConnectionStringHolder(value);
});
builder.Services.AddScoped<IFormulaApiService, FormulaApiService>();
builder.Services.AddScoped<IMasterDataApiService, MasterDataApiService>();
builder.Services.AddScoped<ISandboxApiService, SandboxApiService>();
builder.Services.AddScoped<IGenericChannelCalculationEngine>(sp =>
    new GenericChannelNCalcEngine(sp.GetRequiredService<ConnectionStringHolder>().Value));
builder.Services.AddScoped<ICalculationService>(sp =>
{
    var config = sp.GetRequiredService<IConfiguration>();
    var conn = sp.GetRequiredService<ConnectionStringHolder>().Value;

    var mtEngine = MtCalculationEngineFactory.Create(conn, config["CalculationEngine:MT"]);
    var siEngine = SiCalculationEngineFactory.Create(conn, config["CalculationEngine:SI"]);
    var ttEngine = TtCalculationEngineFactory.Create(conn, config["CalculationEngine:TT"]);
    var laosEngine = LaosCalculationEngineFactory.Create(conn, config["CalculationEngine:LAOS"]);

    return new MtCalculationRunner(conn, mtEngine, siEngine, ttEngine, laosEngine);
});

var app = builder.Build();

app.UseExceptionHandler(exceptionApp =>
{
    exceptionApp.Run(async context =>
    {
        var logger = context.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("GlobalExceptionHandler");
        var exception = context.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>()?.Error;

        if (exception is not null)
        {
            logger.LogError(exception, "Unhandled API exception. TraceId={TraceId}", context.TraceIdentifier);
        }

        context.Response.StatusCode = StatusCodes.Status500InternalServerError;
        context.Response.ContentType = "application/json";
        context.Response.Headers.Append("X-Correlation-Id", context.TraceIdentifier);

        await context.Response.WriteAsJsonAsync(ApiEnvelope<object>.Fail("Internal server error"));
    });
});

app.Use(async (context, next) =>
{
    var watch = System.Diagnostics.Stopwatch.StartNew();
    await next();
    watch.Stop();

    if (context.Request.Path.StartsWithSegments("/api/v1", StringComparison.OrdinalIgnoreCase))
    {
        var logger = context.RequestServices.GetRequiredService<ILoggerFactory>().CreateLogger("ApiAudit");
        logger.LogInformation(
            "API {Method} {Path} => {StatusCode} ({ElapsedMs}ms) TraceId={TraceId}",
            context.Request.Method,
            context.Request.Path,
            context.Response.StatusCode,
            watch.ElapsedMilliseconds,
            context.TraceIdentifier);
    }
});

app.UseSwagger();
app.UseSwaggerUI();

app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/health", () => Results.Ok(new { status = "ok" }));

static async Task<IResult> ExecuteWriteAsync(Func<Task<int>> action, Func<int, IResult> onSuccess)
{
    try
    {
        var result = await action();
        return onSuccess(result);
    }
    catch (InvalidOperationException ex)
    {
        return Results.BadRequest(ApiEnvelope<object>.Fail(ex.Message));
    }
}

var api = app.MapGroup("/api/v1").RequireAuthorization().RequireRateLimiting("api");
var calcApi = api.MapGroup("/calculation");
var formulaApi = api.MapGroup("/formulas").RequireAuthorization("CanEditFormula");
var masterApi = api.MapGroup("/masters").RequireAuthorization("CanEditMaster");
var channelApi = api.MapGroup("/channels").RequireAuthorization("CanManageChannel");
var sandboxApi = calcApi.MapGroup("/sandbox").RequireAuthorization("CanRunSandbox");

calcApi.MapPost(
    "/{channel}/run",
    async Task<IResult> (
        [FromRoute] string channel,
        [FromBody] RunCalculationRequest request,
        ConnectionStringHolder connection,
        IConfiguration configuration,
        IGenericChannelCalculationEngine genericEngine,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var normalized = channel.Trim().ToUpperInvariant();
        var approvedBy = string.IsNullOrWhiteSpace(request.ApprovedBy) ? "api" : request.ApprovedBy;

        int calcRunId;
        switch (normalized)
        {
            case "MT":
                if (request.PeriodId is null || request.PeriodId <= 0)
                {
                    return Results.BadRequest(ApiEnvelope<object>.Fail("periodId is required and must be > 0"));
                }

                calcRunId = await MtCalculationEngineFactory
                    .Create(connection.Value, request.Engine ?? configuration["CalculationEngine:MT"])
                    .RunAsync(request.PeriodId.Value, approvedBy);
                break;

            case "SI":
                if (request.PeriodId is null || request.PeriodId <= 0)
                {
                    return Results.BadRequest(ApiEnvelope<object>.Fail("periodId is required and must be > 0"));
                }

                calcRunId = await SiCalculationEngineFactory
                    .Create(connection.Value, request.Engine ?? configuration["CalculationEngine:SI"])
                    .RunAsync(request.PeriodId.Value, approvedBy);
                break;

            case "LAOS":
                if (request.PeriodId is null || request.PeriodId <= 0)
                {
                    return Results.BadRequest(ApiEnvelope<object>.Fail("periodId is required and must be > 0"));
                }

                await using (var conn = new SqlConnection(connection.Value))
                {
                    var periodCode = await conn.ExecuteScalarAsync<string?>(
                        new CommandDefinition(
                            "SELECT period_code FROM dbo.mst_period WHERE period_id = @PeriodId",
                            new { PeriodId = request.PeriodId.Value },
                            cancellationToken: cancellationToken));

                    if (string.IsNullOrWhiteSpace(periodCode))
                    {
                        return Results.BadRequest(ApiEnvelope<object>.Fail("periodId is not found in mst_period"));
                    }

                    calcRunId = await LaosCalculationEngineFactory
                        .Create(connection.Value, request.Engine ?? configuration["CalculationEngine:LAOS"])
                        .RunAsync(periodCode, approvedBy);
                }
                break;

            case "TT":
                if (string.IsNullOrWhiteSpace(request.PeriodCode))
                {
                    return Results.BadRequest(ApiEnvelope<object>.Fail("periodCode is required for TT"));
                }

                if (string.IsNullOrWhiteSpace(request.WsType))
                {
                    return Results.BadRequest(ApiEnvelope<object>.Fail("wsType is required for TT"));
                }

                calcRunId = await TtCalculationEngineFactory
                    .Create(connection.Value, request.Engine ?? configuration["CalculationEngine:TT"])
                    .RunAsync(request.PeriodCode, request.WsType, approvedBy);
                break;

            default:
                if (request.PeriodId is null || request.PeriodId <= 0)
                {
                    return Results.BadRequest(ApiEnvelope<object>.Fail("periodId is required and must be > 0"));
                }

                try
                {
                    calcRunId = await genericEngine.RunAsync(normalized, request.PeriodId.Value, approvedBy, request.WsType);
                }
                catch (InvalidOperationException ex)
                {
                    return Results.BadRequest(ApiEnvelope<object>.Fail(ex.Message));
                }
                break;
        }

        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(
            ApiEnvelope<RunCalculationResponse>.Ok(new RunCalculationResponse
            {
                Channel = normalized,
                CalcRunId = calcRunId,
                Status = "CALCULATED"
            }));
    }).RequireAuthorization("CanRunCalculation");

calcApi.MapGet(
    "/runs/{calcRunId:int}",
    async Task<IResult> (
        int calcRunId,
        ConnectionStringHolder connection,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        const string sql = @"
SELECT TOP(1)
    r.calc_run_id AS CalcRunId,
    r.period_id AS PeriodId,
    r.channel_id AS ChannelId,
    c.channel_code AS ChannelCode,
    r.run_status AS RunStatus,
    r.calculated_at AS CalculatedAt,
    r.approved_at AS ApprovedAt,
    r.approved_by AS ApprovedBy,
    r.created_at AS CreatedAt,
    r.updated_at AS UpdatedAt,
    ISNULL(d.DetailRows, 0) AS DetailRows,
    ISNULL(h.HrRows, 0) AS HrRows
FROM dbo.trn_calc_run r
INNER JOIN dbo.mst_channel c ON c.channel_id = r.channel_id
OUTER APPLY (
    SELECT COUNT(1) AS DetailRows
    FROM dbo.trn_incentive_detail d
    WHERE d.calc_run_id = r.calc_run_id
) d
OUTER APPLY (
    SELECT COUNT(1) AS HrRows
    FROM dbo.out_for_hr_variable h
    WHERE h.calc_run_id = r.calc_run_id
) h
WHERE r.calc_run_id = @CalcRunId;";

        await using var conn = new SqlConnection(connection.Value);
        var result = await conn.QuerySingleOrDefaultAsync<CalcRunStatusDto>(
            new CommandDefinition(sql, new { CalcRunId = calcRunId }, cancellationToken: cancellationToken));

        if (result is null)
        {
            return Results.NotFound(ApiEnvelope<object>.Fail("calcRunId not found"));
        }

        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<CalcRunStatusDto>.Ok(result));
    }).RequireAuthorization("CanRunCalculation");

calcApi.MapGet(
    "/{channel}/results",
    async Task<IResult> (
        [FromRoute] string channel,
        [FromQuery] int periodId,
        ConnectionStringHolder connection,
        ICalculationService calculationService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        if (periodId <= 0)
        {
            return Results.BadRequest(ApiEnvelope<object>.Fail("periodId must be > 0"));
        }

        var normalized = channel.Trim().ToUpperInvariant();
        await using var conn = new SqlConnection(connection.Value);
        var channelId = await conn.ExecuteScalarAsync<int?>(
            new CommandDefinition(
                "SELECT TOP(1) channel_id FROM dbo.mst_channel WHERE UPPER(channel_code) = @Code",
                new { Code = normalized },
                cancellationToken: cancellationToken));

        if (channelId is null)
        {
            return Results.BadRequest(ApiEnvelope<object>.Fail("Unsupported channel"));
        }

        var results = (await calculationService.GetForHrResultsAsync(periodId, channelId.Value)).ToArray();

        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<IReadOnlyCollection<IncentiveResult>>.Ok(results));
    }).RequireAuthorization("CanRunCalculation");

formulaApi.MapGet(
    "",
    async Task<IResult> (
        [FromQuery] string? channel,
        [FromQuery] string? step,
        [FromQuery] bool activeOnly,
        IFormulaApiService formulaService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var rows = await formulaService.ListAsync(channel, step, activeOnly, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<IReadOnlyCollection<dynamic>>.Ok(rows));
    });

formulaApi.MapGet(
    "/{formulaCode}",
    async Task<IResult> (
        string formulaCode,
        IFormulaApiService formulaService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var row = await formulaService.GetByCodeAsync(formulaCode, cancellationToken);
        if (row is null)
        {
            return Results.NotFound(ApiEnvelope<object>.Fail("formulaCode not found"));
        }

        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<dynamic>.Ok(row));
    });

formulaApi.MapPost(
    "",
    async Task<IResult> (
        FormulaUpsertRequest request,
        IFormulaApiService formulaService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return await ExecuteWriteAsync(
            () => formulaService.CreateAsync(request, cancellationToken),
            formulaId => Results.Ok(ApiEnvelope<object>.Ok(new { FormulaId = formulaId })));
    });

formulaApi.MapPut(
    "/{formulaCode}",
    async Task<IResult> (
        string formulaCode,
        FormulaUpsertRequest request,
        IFormulaApiService formulaService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return await ExecuteWriteAsync(
            () => formulaService.UpdateAsync(formulaCode, request, cancellationToken),
            formulaId => Results.Ok(ApiEnvelope<object>.Ok(new { FormulaId = formulaId })));
    });

formulaApi.MapPost(
    "/{formulaCode}/activate",
    async Task<IResult> (
        string formulaCode,
        IFormulaApiService formulaService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var rows = await formulaService.ActivateAsync(formulaCode, isActive: true, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<object>.Ok(new { UpdatedRows = rows }));
    });

formulaApi.MapPost(
    "/{formulaCode}/deactivate",
    async Task<IResult> (
        string formulaCode,
        IFormulaApiService formulaService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var rows = await formulaService.ActivateAsync(formulaCode, isActive: false, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<object>.Ok(new { UpdatedRows = rows }));
    });

formulaApi.MapPost(
    "/validate",
    (FormulaValidationRequest request, IFormulaApiService formulaService, HttpContext httpContext) =>
    {
        var result = formulaService.Validate(request);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<FormulaValidationResponse>.Ok(result));
    });

masterApi.MapGet(
    "/{table}",
    async Task<IResult> (
        string table,
        [FromQuery] int take,
        IMasterDataApiService masterService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var rows = await masterService.ListRowsAsync(table, take <= 0 ? 200 : take, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<IReadOnlyCollection<dynamic>>.Ok(rows));
    });

masterApi.MapPost(
    "/{table}",
    async Task<IResult> (
        string table,
        MasterRowWriteRequest request,
        IMasterDataApiService masterService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return await ExecuteWriteAsync(
            () => masterService.InsertRowAsync(table, request.Values, cancellationToken),
            id => Results.Ok(ApiEnvelope<object>.Ok(new { Id = id })));
    });

masterApi.MapPut(
    "/{table}/{id:long}",
    async Task<IResult> (
        string table,
        long id,
        MasterRowWriteRequest request,
        IMasterDataApiService masterService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return await ExecuteWriteAsync(
            () => masterService.UpdateRowAsync(table, id, request.Values, cancellationToken),
            rows => Results.Ok(ApiEnvelope<object>.Ok(new { UpdatedRows = rows })));
    });

masterApi.MapDelete(
    "/{table}/{id:long}",
    async Task<IResult> (
        string table,
        long id,
        IMasterDataApiService masterService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var rows = await masterService.DeactivateRowAsync(table, id, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<object>.Ok(new { UpdatedRows = rows }));
    });

channelApi.MapPost(
    "",
    async Task<IResult> (
        ChannelCreateRequest request,
        IMasterDataApiService masterService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var channelId = await masterService.CreateChannelAsync(
            request.ChannelCode,
            request.ChannelNameTh,
            request.ChannelNameEn,
            request.CalcType,
            cancellationToken);

        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<object>.Ok(new { ChannelId = channelId }));
    });

channelApi.MapPost(
    "/{channel}/formulas/clone-from/{sourceChannel}",
    async Task<IResult> (
        string channel,
        string sourceChannel,
        [FromQuery] bool setInactive,
        IFormulaApiService formulaService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var rows = await formulaService.CloneChannelFormulasAsync(channel, sourceChannel, setInactive, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<object>.Ok(new { ClonedRows = rows }));
    });

channelApi.MapPost(
    "/{channel}/masters/clone-from/{sourceChannel}",
    async Task<IResult> (
        string channel,
        string sourceChannel,
        IMasterDataApiService masterService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var rows = await masterService.CloneMasterByChannelAsync(channel, sourceChannel, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<object>.Ok(new { ClonedRows = rows }));
    });

sandboxApi.MapPost(
    "/run",
    async Task<IResult> (
        SandboxRunRequest request,
        ISandboxApiService sandboxService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var result = await sandboxService.RunAsync(request, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<SandboxRunResponse>.Ok(result));
    });

sandboxApi.MapGet(
    "/{sandboxRunId:long}",
    async Task<IResult> (
        long sandboxRunId,
        ISandboxApiService sandboxService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var rows = await sandboxService.GetDetailsAsync(sandboxRunId, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<IReadOnlyCollection<dynamic>>.Ok(rows));
    });

sandboxApi.MapPost(
    "/compare",
    async Task<IResult> (
        SandboxCompareRequest request,
        ISandboxApiService sandboxService,
        HttpContext httpContext,
        CancellationToken cancellationToken) =>
    {
        var result = await sandboxService.CompareAsync(request, cancellationToken);
        httpContext.Response.Headers.Append("X-Correlation-Id", httpContext.TraceIdentifier);
        return Results.Ok(ApiEnvelope<SandboxCompareResponse>.Ok(result));
    });

app.Run();

public partial class Program;
