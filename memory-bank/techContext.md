# Tech Context — AJT New Sale Incentive

## Tech Stack

| Layer | เทคโนโลยี |
|---|---|
| Backend | .NET 10, ASP.NET Core Razor Pages |
| REST API | ASP.NET Core Minimal APIs (`src/AjtIncentive.Api`), Swagger/OpenAPI |
| ORM/Data Access | EF Core 10 (บางส่วน) + Dapper (ส่วนใหญ่ของ query/command ใน Web project) |
| Database | SQL Server |
| Formula Engine | NCalc 6.3.0 (PascalCase function names เท่านั้น เช่น `Round`) |
| Frontend | Bootstrap 5, Chart.js (UMD minified) สำหรับ Dashboard charts |
| UI Design System | Microsoft Fluent Design (เริ่มใช้ 2026-07-03) |

## โครงสร้าง Solution (csproj)

```
src/
├── AjtIncentive.Domain/          ← Entities, value objects
├── AjtIncentive.Application/     ← Interfaces, calculation engines, services
├── AjtIncentive.Infrastructure/  ← EF Core, Dapper implementations, DI registration
├── AjtIncentive.Web/             ← Razor Pages (หน้าเว็บหลัก)
└── AjtIncentive.Api/             ← REST API (Minimal APIs, แยก process จาก Web)
```

ทุก csproj target `net10.0` — **ต้องใช้ .NET SDK 10.x เท่านั้น** (SDK 9.x จะ error NETSDK1045)

## Database

- **Server**: `192.168.11.40`
- **Database**: `AJT_SALE_INCENTIVE` (⚠️ บาง session เก่าเคยต่อผิดเป็น `AJT_SIS` — ชื่อนั้นผิด/legacy)
- **Auth**: SQL Login — credential เก็บใน `environment/database-dev - cds.env`
  (⚠️ **ห้าม hardcode/copy password ลงไฟล์ที่ commit เข้า git หรือไฟล์ memory-bank นี้** —
  เปิดไฟล์ env ในเครื่องเพื่อดู connection string จริง)
- Windows Auth (`-E` ใน sqlcmd) **ใช้ไม่ได้** กับ server นี้ — ต้องใช้ SQL Login เท่านั้น
- เชื่อมต่อผ่าน `sqlcmd -S 192.168.11.40 -d AJT_SALE_INCENTIVE -U <user> -P <password> -C -i <script>.sql`
  (ต้องใส่ `-C` เพื่อ trust server certificate)
- DDL scripts ทั้งหมดอยู่ที่ `database/ddl/` เรียงเลขลำดับ (01_..., 02_..., ล่าสุดถึงประมาณ 54_...)
  รันตามลำดับเลขเสมอเมื่อ setup DB ใหม่

## Dev Workflow

```powershell
# รันแอป (default = src/AjtIncentive.Web)
.\dev.ps1 run

# build อย่างเดียว
.\dev.ps1 build

# build project อื่น (เช่น src_antigravity ซึ่งเป็น branch ทดลอง/backup)
.\dev.ps1 build -Project src_antigravity
```

App รันที่ `http://localhost:5288` — **ต้องรัน `dev.ps1 run` ใหม่ทุกครั้งที่เปิด session ใหม่**
(async background terminal จะถูกเคลียร์เมื่อปิด terminal/VS Code)

## Git & Push Policy

- Remote: `https://github.com/iNix4S/AJT_SALE_INCENTIVE.git`, branch `main`
- **Pre-push hook**: `src/.githooks/pre-push` — จำกัด path ที่ push ได้เฉพาะ:
  `src/`, `test-scenarios/`, `database/`, `README.md`
  (ปรับเพิ่ม `database/` เมื่อ 2026-07-03 — ก่อนหน้านั้นบล็อก)
- ไฟล์/โฟลเดอร์อื่น (`docs/`, `chat-log/`, `memory-bank/`, `assets/`, `_archive/`) **เก็บเฉพาะ
  local + OneDrive เท่านั้น ไม่ push ขึ้น GitHub**
- OneDrive path มักทำให้ git commit ล้มเหลว (`unable to append to .git/logs/HEAD`) —
  แก้ด้วย `git config windows.appendAtomically false`
- ถ้า `git reset --hard` ล้มเหลวเพราะ OneDrive lock ไฟล์ ให้ใช้ git plumbing commands
  (`commit-tree`, `update-ref`) หรือ worktree แยกแทน

## Known Constraints / Gotchas

1. **SDK version**: ต้อง .NET SDK 10.0.301+ — ถ้า `winget` บอกว่าติดตั้งแล้วแต่
   `dotnet --list-sdks` ไม่เห็น ให้ `winget install --id Microsoft.DotNet.SDK.10 --force` ใหม่
2. **NCalc function case**: ฟังก์ชันต้องเป็น PascalCase (`Round` ไม่ใช่ `ROUND`) มิฉะนั้น
   evaluate fail แบบเงียบ
3. **employee_code ≠ salesman_code**: ดูรายละเอียดใน `systemPatterns.md` หัวข้อ Org Hierarchy
   Resolution Pattern — เป็นบั๊กที่เคยเกิดจริงเมื่อ join view ผิด
4. **mst_org_hierarchy.ws_type (MT)**: เคย mis-store salesman_code แทน ws_type จริง —
   ปัจจุบัน scope การใช้ ws_type (TOP_WS/WS_SF/WS_WH) เฉพาะ TT channel เท่านั้น
5. **OneDrive + git**: ระวัง lock ไฟล์เสมอเวลาทำ destructive git operation (reset --hard, worktree)
