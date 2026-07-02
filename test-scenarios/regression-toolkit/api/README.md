# API Regression Toolkit

สคริปต์นี้ใช้ทดสอบ API ระดับ integration/regression ผ่าน HTTP ตาม milestone M5

## ไฟล์
- run_api_regression.ps1

## Preconditions
1. รัน API แล้ว (เช่น `dotnet run --project src/AjtIncentive.Api/AjtIncentive.Api.csproj`)
2. ตั้งค่า `ApiSecurity:ApiKey` ใน config/user-secrets แล้ว
3. ฐานข้อมูลมี schema ล่าสุด (รวม DDL 54)

## ตัวอย่างการรัน

```powershell
pwsh test-scenarios/regression-toolkit/api/run_api_regression.ps1 \
  -BaseUrl "http://localhost:5115" \
  -ApiKey "your-api-key" \
  -PeriodId 1 \
  -MtEngine "StoredProcedure"
```

## โหมดที่แนะนำ
- quick smoke (ไม่ยิง calc run):

```powershell
pwsh test-scenarios/regression-toolkit/api/run_api_regression.ps1 \
  -BaseUrl "http://localhost:5115" \
  -ApiKey "your-api-key" \
  -SkipCalculationRun
```

- sandbox only:

```powershell
pwsh test-scenarios/regression-toolkit/api/run_api_regression.ps1 \
  -BaseUrl "http://localhost:5115" \
  -ApiKey "your-api-key" \
  -SkipCalculationRun:$true -SkipSandbox:$false
```
