# AJT New Sale Incentive

Repository นี้ใช้เก็บเฉพาะส่วนที่จำเป็นสำหรับการพัฒนา Demo POC บน GitHub ได้แก่ source code, project planning และ test scenarios ของระบบ AJT Sale Incentive

> อัปเดตล่าสุด: 2026-06-22
> สถานะ: Demo POC พร้อมใช้งาน, build ผ่าน, มี Microsoft Entra ID sign-in ที่ navbar แบบ optional

---

## ภาพรวมระบบ

AJT Sale Incentive เป็น Web Application สำหรับคำนวณ incentive ของฝ่ายขายบน SQL Server โดยรองรับงานหลักดังนี้

1. Dashboard สำหรับติดตามสถานะรอบคำนวณ
2. Calculation สำหรับ MT, TT, SI และ Laos
3. Period master management
4. For HR export preparation
5. Prorate และ Special Adjustment

เทคโนโลยีหลัก

1. .NET 10
2. ASP.NET Core Razor Pages
3. EF Core 10
4. Dapper
5. SQL Server

---

## โครงสร้างที่เก็บบน GitHub

เพื่อให้ repo กระชับและสอดคล้องกับกติกาการ push ปัจจุบัน GitHub จะเก็บเฉพาะโฟลเดอร์ดังนี้

```text
.
├── README.md
├── src/
├── project-planner/
└── test-scenarios/
```

รายละเอียด

1. `README.md` : ภาพรวม repo และวิธีเริ่มใช้งาน
2. `src/` : source code ของ solution ทั้งหมด รวม git hooks ที่ใช้บังคับกติกาการ push
3. `project-planner/` : เอกสาร scope และแผนงานของ Demo POC
4. `test-scenarios/` : test cases และสคริปต์สำหรับตรวจสอบ flow หลักของระบบ

หมายเหตุ: เอกสารธุรกิจ, raw extracts, database scripts ภายนอก repo, deliverables และ backup folders อื่นๆ เก็บไว้ใน workspace ภายในเครื่อง แต่ไม่ถูก publish ขึ้น GitHub repo นี้

---

## โฟลเดอร์สำคัญ

### `src/`

ดูรายละเอียดเพิ่มได้ที่ `src/README.md`

องค์ประกอบหลัก

1. `AjtIncentive.Domain/` : entities และ enums
2. `AjtIncentive.Application/` : interfaces และ use case contracts
3. `AjtIncentive.Infrastructure/` : EF Core, Dapper, stored procedure runners
4. `AjtIncentive.Web/` : Razor Pages web application
5. `.githooks/pre-push` : guard สำหรับตรวจไฟล์ที่อนุญาตให้ push

### `project-planner/`

ดูรายละเอียดเพิ่มได้ที่ `project-planner/README.md`

1. `Demo-POC_Scope.md` : ขอบเขตงาน Demo POC
2. `Demo-POC_Project-Plan.md` : phase, milestone และแผนการดำเนินงาน

### `test-scenarios/`

ดูรายละเอียดเพิ่มได้ที่ `test-scenarios/README.md`

1. TC01: TT normal
2. TC02: MT normal
3. TC03: SI normal
4. TC04: Laos normal
5. TC05: Prorate mid-month
6. TC06: Special adjustment

---

## การตั้งค่าและการรัน

### Prerequisites

1. .NET SDK 10
2. SQL Server access ไปยังฐานข้อมูล `AJT_SALE_INCENTIVE`
3. ค่า connection string ที่ถูกต้อง

### Database connection

แอปจะอ่าน connection string จากลำดับนี้

1. Environment variable `DB_CONNECTION_STRING`
2. `src/AjtIncentive.Web/appsettings.json`

ตัวอย่าง

```json
{
    "ConnectionStrings": {
        "DefaultConnection": "Server=192.168.11.40;Database=AJT_SALE_INCENTIVE;User Id=sa;Password=<password>;Encrypt=True;TrustServerCertificate=True;"
    }
}
```

### Build

```powershell
dotnet build .\src\AjtIncentive.slnx
```

### Run Web App

```powershell
dotnet run --project .\src\AjtIncentive.Web\AjtIncentive.Web.csproj
```

### Run Test Scenarios

```powershell
.\test-scenarios\run-test-scenarios.ps1
```

---

## Authentication

Web app รองรับ Microsoft Entra ID แบบ optional ที่ navbar

ถ้าต้องการเปิดใช้งาน ให้ตั้งค่า `AzureAd` ใน `src/AjtIncentive.Web/appsettings.json` หรือผ่าน secrets/environment variables ดังนี้

1. `Instance`
2. `TenantId`
3. `ClientId`
4. `ClientSecret`
5. `CallbackPath`
6. `SignedOutCallbackPath`

หากยังไม่ตั้งค่าครบ ระบบจะยังรันได้ และจะแสดงสถานะ Entra ID แบบ disabled ใน navbar

---

## สถานะฟีเจอร์สำคัญ

1. Calculation page รองรับ MT, TT, SI และ Laos
2. TT คำนวณทุก WS Type ในครั้งเดียว
3. Dashboard แสดงภาพรวมแบบ control tower
4. Periods page รองรับ CRUD บน master data
5. มี Prorate และ Special Adjustment pages
6. มี readiness indicator ต่อ period บนหน้า Calculation

---

## กติกาการ Push

repo นี้มี pre-push hook ที่ `src/.githooks/pre-push` เพื่อจำกัดไฟล์ที่ push ขึ้น GitHub ได้

ปัจจุบันอนุญาต

1. `README.md`
2. ไฟล์ภายใต้ `src/`
3. ไฟล์ภายใต้ `project-planner/`
4. ไฟล์ภายใต้ `test-scenarios/`
5. ไฟล์ภายใต้ `test-scenarioes/`

หาก clone repo ไปเครื่องใหม่ ให้ตั้งค่า hook path อีกครั้ง

```powershell
git config core.hooksPath src/.githooks
```

---

## เอกสารอ้างอิงใน Repo

1. `src/README.md`
2. `project-planner/README.md`
3. `test-scenarios/README.md`

เอกสารเชิงวิเคราะห์และไฟล์ภายในอื่นๆ ยังคงอยู่ใน workspace ภายในทีม แต่ไม่ได้ถูกเก็บใน GitHub repository นี้
