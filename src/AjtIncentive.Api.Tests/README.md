# AjtIncentive.Api.Tests

ชุดทดสอบนี้แบ่งเป็น 2 กลุ่ม

1. API auth/policy tests (รันเสมอ)
2. DB integration tests (opt-in)

## คำสั่งรันปกติ

```powershell
dotnet test src/AjtIncentive.Api.Tests/AjtIncentive.Api.Tests.csproj
```

## เปิดใช้ DB integration tests (แตะ DB จริง)

ตั้งค่า environment variables ก่อนรัน:

```powershell
$env:AJT_API_TEST_ENABLE_DB = "true"
$env:AJT_API_TEST_DB_CONNECTION = "Server=...;Database=AJT_SALE_INCENTIVE;User Id=...;Password=...;TrustServerCertificate=True;Encrypt=False;"
$env:AJT_API_TEST_API_KEY = "your-db-test-api-key"
$env:AJT_API_TEST_PERIOD_ID = "1"
```

แล้วรัน:

```powershell
dotnet test src/AjtIncentive.Api.Tests/AjtIncentive.Api.Tests.csproj
```

## สิ่งที่ DB tests ตรวจ

1. `POST /api/v1/calculation/MT/run`
2. `GET /api/v1/calculation/runs/{calcRunId}`
3. `GET /api/v1/calculation/MT/results?periodId=`
4. `POST /api/v1/calculation/sandbox/run` (persist=true)
5. `POST /api/v1/calculation/sandbox/compare`

หมายเหตุ: DB tests จะทำงานต่อเมื่อ `AJT_API_TEST_ENABLE_DB=true` เท่านั้น
