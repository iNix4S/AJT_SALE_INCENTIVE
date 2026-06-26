using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authentication.OpenIdConnect;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using AjtIncentive.Infrastructure.Data;
using AjtIncentive.Application.Interfaces;
using AjtIncentive.Infrastructure.StoredProcedures;
using AjtIncentive.Web.Services;

var builder = WebApplication.CreateBuilder(args);

var azureAdSection = builder.Configuration.GetSection("AzureAd");
var isEntraConfigured =
    IsConfiguredValue(azureAdSection["Instance"])
    && IsConfiguredValue(azureAdSection["TenantId"])
    && IsConfiguredValue(azureAdSection["ClientId"])
    && IsConfiguredValue(azureAdSection["ClientSecret"]);

// Add services to the container.
builder.Services.AddLocalization(options => options.ResourcesPath = "Resources");
builder.Services.AddRazorPages().AddViewLocalization();
builder.Services.AddAuthorization();
builder.Services.AddDistributedMemoryCache();
builder.Services.AddSession(options =>
{
    options.IdleTimeout = TimeSpan.FromMinutes(20);
    options.Cookie.HttpOnly = true;
    options.Cookie.IsEssential = true;
});

var authenticationBuilder = builder.Services
    .AddAuthentication(options =>
    {
        options.DefaultScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultAuthenticateScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultSignInScheme = CookieAuthenticationDefaults.AuthenticationScheme;
        options.DefaultChallengeScheme = isEntraConfigured
            ? OpenIdConnectDefaults.AuthenticationScheme
            : CookieAuthenticationDefaults.AuthenticationScheme;
    })
    .AddCookie(options =>
    {
        options.LoginPath = "/account/signin";
        options.LogoutPath = "/account/signout";
        options.AccessDeniedPath = "/";
    });

if (isEntraConfigured)
{
    authenticationBuilder.AddOpenIdConnect(OpenIdConnectDefaults.AuthenticationScheme, options =>
    {
        var instance = azureAdSection["Instance"]?.TrimEnd('/') ?? "https://login.microsoftonline.com";
        var tenantId = azureAdSection["TenantId"] ?? string.Empty;

        options.Authority = $"{instance}/{tenantId}/v2.0";
        options.ClientId = azureAdSection["ClientId"] ?? string.Empty;
        options.ClientSecret = azureAdSection["ClientSecret"] ?? string.Empty;
        options.CallbackPath = azureAdSection["CallbackPath"] ?? "/signin-oidc";
        options.SignedOutCallbackPath = azureAdSection["SignedOutCallbackPath"] ?? "/signout-callback-oidc";
        options.ResponseType = OpenIdConnectResponseType.Code;
        options.UsePkce = true;
        options.SaveTokens = true;
        options.Scope.Clear();
        options.Scope.Add("openid");
        options.Scope.Add("profile");
        options.Scope.Add("email");
        options.TokenValidationParameters.NameClaimType = "name";
    });
}

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

builder.Services.AddScoped<IPortalDataService>(sp =>
    new PortalDataService(connectionString));

builder.Services.AddScoped<IFormulaEvaluatorService>(sp =>
    new FormulaEvaluatorService(connectionString));

builder.Services.AddScoped<IDataInterfaceService>(sp =>
    new DataInterfaceService(connectionString));

builder.Services.AddScoped<ITargetImportService, TargetImportService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}

var supportedCultures = new[] { "th-TH", "en-US" };
var localizationOptions = new RequestLocalizationOptions()
    .SetDefaultCulture("th-TH")
    .AddSupportedCultures(supportedCultures)
    .AddSupportedUICultures(supportedCultures);

app.UseRequestLocalization(localizationOptions);

app.UseHttpsRedirection();

app.UseRouting();

app.UseSession();
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/account/signin", (HttpContext httpContext, string? returnUrl) =>
{
    if (!isEntraConfigured)
    {
        return Results.Redirect("/");
    }

    var redirectUri = string.IsNullOrWhiteSpace(returnUrl) ? "/" : returnUrl;

    return Results.Challenge(
        new AuthenticationProperties { RedirectUri = redirectUri },
        new[] { OpenIdConnectDefaults.AuthenticationScheme });
}).AllowAnonymous();

app.MapGet("/account/signout", () =>
    Results.SignOut(
        new AuthenticationProperties { RedirectUri = "/" },
        new[]
        {
            CookieAuthenticationDefaults.AuthenticationScheme,
            OpenIdConnectDefaults.AuthenticationScheme
        }))
    .RequireAuthorization();

app.MapStaticAssets();
app.MapRazorPages()
   .WithStaticAssets();

app.Run();

static bool IsConfiguredValue(string? value)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        return false;
    }

    return !value.Contains("__SET_IN_", StringComparison.OrdinalIgnoreCase)
        && !value.StartsWith("YOUR_", StringComparison.OrdinalIgnoreCase);
}
