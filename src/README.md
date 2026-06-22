# AJT Sale Incentive — Demo POC Source

> .NET Core 10 · Razor Pages · EF Core 10 · Dapper · MS SQL Server

---

## โครงสร้าง Solution

```
src/
├── AjtIncentive.slnx                      ← Solution file (.NET 10)
│
├── AjtIncentive.Domain/                   ← Domain Layer
│   ├── Entities/                          ← Entity classes
│   │   ├── Period.cs
│   │   ├── Employee.cs
│   │   └── IncentiveResult.cs
│   ├── Enums/
│   │   └── IncentiveEnums.cs              ← Channel, PositionLevel, ApprovalStatus
│   └── Common/                            ← Base classes / shared domain types
│
├── AjtIncentive.Application/              ← Application Layer (Use Cases)
│   ├── Interfaces/
│   │   ├── ICalculationService.cs         ← Interface สำหรับรัน SP
│   │   └── IPeriodRepository.cs
│   ├── Calculation/                       ← Calculation use case handlers
│   ├── Import/                            ← Import data use cases
│   ├── Parameters/                        ← Parameters use cases
│   └── Approvals/                         ← Approval workflow use cases
│
├── AjtIncentive.Infrastructure/           ← Infrastructure Layer
│   ├── Data/
│   │   ├── AjtIncentiveDbContext.cs       ← EF Core DbContext
│   │   └── Configurations/               ← IEntityTypeConfiguration files
│   ├── Repositories/                      ← EF Core repository implementations
│   └── StoredProcedures/
│       └── MtCalculationRunner.cs         ← เรียก usp_run_mt_incentive_calculation ผ่าน Dapper
│
└── AjtIncentive.Web/                      ← Presentation Layer (Razor Pages)
    ├── Pages/
    │   ├── Dashboard/
    │   ├── Periods/
    │   ├── Calculation/
    │   ├── ForHR/
    │   ├── Parameters/
    │   └── Approvals/
    ├── ViewModels/
    ├── appsettings.json                   ← Config template (ไม่มี password จริง)
    ├── appsettings.Development.json       ← Dev config (อยู่ใน .gitignore)
    └── wwwroot/                           ← Static assets (CSS, JS, Bootstrap)
```

---

## Project Dependencies (Clean Architecture)

```
Web  →  Application  →  Domain
         ↑                ↑
    Infrastructure  ────────
```

| Project | อ้างอิง |
|---|---|
| `AjtIncentive.Web` | Application, Infrastructure |
| `AjtIncentive.Application` | Domain |
| `AjtIncentive.Infrastructure` | Application, Domain |
| `AjtIncentive.Domain` | ไม่มี (ไม่ขึ้นกับใคร) |

---

## NuGet Packages หลัก

| Package | Version | Project | ใช้ทำอะไร |
|---|---|---|---|
| `Microsoft.EntityFrameworkCore.SqlServer` | 10.0.9 | Infrastructure | CRUD, Migrations |
| `Dapper` | 2.1.79 | Infrastructure | เรียก Stored Procedures |
| `Microsoft.EntityFrameworkCore.Tools` | 10.0.9 | Web | `dotnet ef` migrations CLI |

---

## Database Connection

**Server:** `192.168.11.40`  
**Database:** `AJT_SALE_INCENTIVE`

Connection string อยู่ใน `appsettings.Development.json` (ไม่ถูก commit)  
ก่อน run ให้แทน `__REPLACE_WITH_REAL_PASSWORD__` ด้วย password จริง

```jsonc
// appsettings.Development.json
{
  "ConnectionStrings": {
    "DefaultConnection": "Server=192.168.11.40;Database=AJT_SALE_INCENTIVE;User Id=sa;Password=<password>;Encrypt=True;TrustServerCertificate=True;"
  }
}
```

---

## วิธี Run

```powershell
# ครั้งแรก — trust dev certificate
dotnet dev-certs https --trust

# Run web app
dotnet run --project AjtIncentive.Web/AjtIncentive.Web.csproj

# หรือระบุ profile
dotnet run --project AjtIncentive.Web/AjtIncentive.Web.csproj --launch-profile https
```

เปิดใน browser: `https://localhost:7049` หรือ `http://localhost:5288`

---

## Stored Procedures ที่เชื่อมต่อ

| SP | Channel | ไฟล์ |
|---|---|---|
| `usp_run_mt_incentive_calculation` | MT (channel_id=1) | `Infrastructure/StoredProcedures/MtCalculationRunner.cs` |
| `usp_run_tt_incentive_calculation` | TT (channel_id=2) | (TODO) |
