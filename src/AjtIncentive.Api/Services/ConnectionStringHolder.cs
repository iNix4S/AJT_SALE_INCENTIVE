namespace AjtIncentive.Api.Services;

public sealed class ConnectionStringHolder(string value)
{
    public string Value { get; } = value;
}
