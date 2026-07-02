using System.Security.Claims;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.Extensions.Options;

namespace AjtIncentive.Api.Security;

public sealed class ApiKeyAuthenticationHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "ApiKey";
    private const string HeaderName = "X-API-Key";
    private readonly IConfiguration _configuration;

    public ApiKeyAuthenticationHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder,
        IConfiguration configuration)
        : base(options, logger, encoder)
    {
        _configuration = configuration;
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue(HeaderName, out var providedKey))
        {
            return Task.FromResult(AuthenticateResult.Fail("Missing API key header."));
        }

        var candidateKey = providedKey.ToString();
        if (string.IsNullOrWhiteSpace(candidateKey))
        {
            return Task.FromResult(AuthenticateResult.Fail("Invalid API key."));
        }

        var client = ResolveClient(candidateKey);
        if (client is null)
        {
            return Task.FromResult(AuthenticateResult.Fail("Invalid API key."));
        }

        var claims = new List<Claim>
        {
            new(ClaimTypes.Name, client.Name)
        };

        foreach (var role in client.Roles)
        {
            claims.Add(new Claim(ClaimTypes.Role, role));
        }

        var identity = new ClaimsIdentity(claims, SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);

        return Task.FromResult(AuthenticateResult.Success(ticket));
    }

    private ApiClient? ResolveClient(string providedKey)
    {
        var clients = _configuration.GetSection("ApiSecurity:Clients").GetChildren();
        foreach (var clientSection in clients)
        {
            var key = clientSection["ApiKey"];
            if (!string.Equals(key, providedKey, StringComparison.Ordinal))
            {
                continue;
            }

            var name = clientSection["Name"];
            var roles = clientSection.GetSection("Roles")
                .GetChildren()
                .Select(x => x.Value)
                .Where(x => !string.IsNullOrWhiteSpace(x))
                .Select(x => x!)
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .ToList();

            if (roles.Count == 0)
            {
                roles.Add("Admin");
            }

            return new ApiClient(name ?? "api-client", roles);
        }

        var configuredKey = _configuration["ApiSecurity:ApiKey"];
        if (string.IsNullOrWhiteSpace(configuredKey)
            || !string.Equals(configuredKey, providedKey, StringComparison.Ordinal))
        {
            return null;
        }

        return new ApiClient("api-client", ["Admin"]);
    }

    private sealed record ApiClient(string Name, IReadOnlyCollection<string> Roles);
}
