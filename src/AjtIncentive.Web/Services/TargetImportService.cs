using System.Globalization;

namespace AjtIncentive.Web.Services;

/// <summary>
/// TargetImportRow — CSV import record
/// </summary>
public class TargetImportRow
{
    public int RowNumber { get; set; }
    public string SalesmanCode { get; set; } = string.Empty;
    public string ProductCode { get; set; } = string.Empty;
    public decimal TargetAmount { get; set; }
    public decimal? PctSalesman { get; set; }
    public string? ApprovedBy { get; set; }
    public DateTime? ApprovedAt { get; set; }
    public string? ErrorMessage { get; set; }
    public bool IsValid => string.IsNullOrEmpty(ErrorMessage);
}

/// <summary>
/// ImportValidationResult — Preview result after file parsing + validation
/// </summary>
public class ImportValidationResult
{
    public string FileName { get; set; } = string.Empty;
    public int TotalRows { get; set; }
    public List<TargetImportRow> Rows { get; set; } = new();
    public int ValidRowCount => Rows.Count(r => r.IsValid);
    public int ErrorRowCount => Rows.Count(r => !r.IsValid);
    public List<TargetImportRow> ErrorRows => Rows.Where(r => !r.IsValid).ToList();
    public List<TargetImportRow> ValidRows => Rows.Where(r => r.IsValid).ToList();
}

/// <summary>
/// TargetImportService — Handle CSV file import, parsing, validation (no external dependencies)
/// </summary>
public interface ITargetImportService
{
    Task<ImportValidationResult> ParseAndValidateAsync(
        Stream fileStream,
        string fileName,
        HashSet<string> validSalesmanCodes,
        HashSet<string> validProductCodes);

    string GenerateCsvTemplate();
}

public class TargetImportService : ITargetImportService
{
    /// <summary>
    /// Simple CSV parser without CsvHelper dependency
    /// </summary>
    public async Task<ImportValidationResult> ParseAndValidateAsync(
        Stream fileStream,
        string fileName,
        HashSet<string> validSalesmanCodes,
        HashSet<string> validProductCodes)
    {
        var result = new ImportValidationResult
        {
            FileName = fileName,
            Rows = new List<TargetImportRow>()
        };

        try
        {
            using var reader = new StreamReader(fileStream);
            var headerLine = await reader.ReadLineAsync();
            if (string.IsNullOrWhiteSpace(headerLine))
            {
                result.Rows.Add(new TargetImportRow
                {
                    RowNumber = 0,
                    ErrorMessage = "ไฟล์ CSV ว่างเปล่า"
                });
                return result;
            }

            var headers = ParseCsvLine(headerLine);
            var headerMap = new Dictionary<string, int>();
            for (int i = 0; i < headers.Count; i++)
            {
                var normalized = headers[i].Trim().ToLower()
                    .Replace("_", "")
                    .Replace(" ", "");
                headerMap[normalized] = i;
            }

            // Map columns
            var (salesmanIdx, productIdx, targetIdx, pctIdx, approvedByIdx, approvedAtIdx) 
                = FindColumns(headerMap);

            int rowNumber = 1;
            string? line;
            while ((line = await reader.ReadLineAsync()) != null)
            {
                rowNumber++;
                if (string.IsNullOrWhiteSpace(line)) continue;

                var values = ParseCsvLine(line);
                var row = new TargetImportRow { RowNumber = rowNumber };

                try
                {
                    row.SalesmanCode = SafeGet(values, salesmanIdx).Trim().ToUpper();
                    row.ProductCode = SafeGet(values, productIdx).Trim().ToUpper();
                    
                    if (!decimal.TryParse(SafeGet(values, targetIdx), NumberStyles.Any, 
                        CultureInfo.InvariantCulture, out var target))
                    {
                        row.ErrorMessage = "Target Amount: Invalid number format";
                    }
                    else
                    {
                        row.TargetAmount = target;
                    }

                    var pctStr = SafeGet(values, pctIdx).Trim();
                    if (!string.IsNullOrEmpty(pctStr) && 
                        decimal.TryParse(pctStr, NumberStyles.Any, 
                        CultureInfo.InvariantCulture, out var pct))
                    {
                        row.PctSalesman = pct;
                    }

                    row.ApprovedBy = SafeGet(values, approvedByIdx).Trim();
                    if (string.IsNullOrEmpty(row.ApprovedBy)) 
                        row.ApprovedBy = null;

                    var approvedAtStr = SafeGet(values, approvedAtIdx).Trim();
                    if (!string.IsNullOrEmpty(approvedAtStr) && 
                        DateTime.TryParse(approvedAtStr, out var approvedAt))
                    {
                        row.ApprovedAt = approvedAt;
                    }

                    // Validate
                    ValidateImportRow(row, validSalesmanCodes, validProductCodes);
                }
                catch (Exception ex)
                {
                    row.ErrorMessage = $"Parsing error: {ex.Message}";
                }

                result.Rows.Add(row);
            }

            result.TotalRows = result.Rows.Count;
        }
        catch (Exception ex)
        {
            result.Rows.Add(new TargetImportRow
            {
                RowNumber = 0,
                ErrorMessage = $"File parsing error: {ex.Message}"
            });
        }

        return result;
    }

    /// <summary>
    /// Generate CSV template content
    /// </summary>
    public string GenerateCsvTemplate()
    {
        return @"Salesman Code,Product Code,Target Amount,Pct Salesman,Approved By,Approved At
SM0001,PRD-MT01,100000,1.0,ADMIN,2026-06-23
SM0002,PRD-MT02,150000,0.5,ADMIN,2026-06-23
SM0003,PRD-MT03,200000,1.0,,";
    }

    private void ValidateImportRow(
        TargetImportRow row,
        HashSet<string> validSalesmanCodes,
        HashSet<string> validProductCodes)
    {
        if (string.IsNullOrWhiteSpace(row.SalesmanCode))
        {
            row.ErrorMessage = "Salesman Code is required";
            return;
        }

        if (!validSalesmanCodes.Contains(row.SalesmanCode))
        {
            row.ErrorMessage = $"Salesman Code '{row.SalesmanCode}' not found";
            return;
        }

        if (string.IsNullOrWhiteSpace(row.ProductCode))
        {
            row.ErrorMessage = "Product Code is required";
            return;
        }

        if (!validProductCodes.Contains(row.ProductCode))
        {
            row.ErrorMessage = $"Product Code '{row.ProductCode}' not found";
            return;
        }

        if (row.TargetAmount <= 0)
        {
            row.ErrorMessage = "Target Amount must be > 0";
            return;
        }

        if (row.PctSalesman.HasValue && (row.PctSalesman <= 0 || row.PctSalesman > 100))
        {
            row.ErrorMessage = "Pct Salesman must be 0-100";
            return;
        }

        row.ErrorMessage = null; // Mark as valid
    }

    private static (int, int, int, int, int, int) FindColumns(Dictionary<string, int> headerMap)
    {
        int salesmanIdx = GetColumnIndex(headerMap, "salesmancode", "salesman");
        int productIdx = GetColumnIndex(headerMap, "productcode", "product");
        int targetIdx = GetColumnIndex(headerMap, "targetamount", "target");
        int pctIdx = GetColumnIndex(headerMap, "pctsalesman", "pct");
        int approvedByIdx = GetColumnIndex(headerMap, "approvedby", "approved");
        int approvedAtIdx = GetColumnIndex(headerMap, "approvedat");
        return (salesmanIdx, productIdx, targetIdx, pctIdx, approvedByIdx, approvedAtIdx);
    }

    private static int GetColumnIndex(Dictionary<string, int> headerMap, params string[] names)
    {
        foreach (var name in names)
        {
            if (headerMap.TryGetValue(name, out var idx)) 
                return idx;
        }
        return -1;
    }

    private static string SafeGet(List<string> values, int index)
        => index >= 0 && index < values.Count ? values[index] : string.Empty;

    private static List<string> ParseCsvLine(string line)
    {
        var result = new List<string>();
        var current = new System.Text.StringBuilder();
        var inQuotes = false;

        foreach (var ch in line)
        {
            if (ch == '"')
            {
                inQuotes = !inQuotes;
            }
            else if (ch == ',' && !inQuotes)
            {
                result.Add(current.ToString());
                current.Clear();
            }
            else
            {
                current.Append(ch);
            }
        }

        result.Add(current.ToString());
        return result;
    }
}
