using System.Text.Json.Nodes;

namespace AjtIncentive.Api.Contracts;

public sealed class MasterRowWriteRequest
{
    public JsonObject Values { get; set; } = new();
}

public sealed class ChannelCreateRequest
{
    public string ChannelCode { get; set; } = string.Empty;
    public string ChannelNameTh { get; set; } = string.Empty;
    public string ChannelNameEn { get; set; } = string.Empty;
    public string CalcType { get; set; } = "CASCADE_4_LEVEL";
}

public sealed class MasterCloneRequest
{
    public string SourceChannel { get; set; } = string.Empty;
}
