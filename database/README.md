# database/ — AJT Sale Incentive Database Resources

SQL DDL, migration scripts และเอกสาร database design ทั้งหมด

อัปเดตล่าสุด: 2026-07-01

---

## โครงสร้าง

| Folder/File | เนื้อหา |
|---|---|
| `ddl/` | DDL SQL files — CREATE TABLE, INDEX, CONSTRAINT (48+ files) |
| `scripts/` | Migration scripts, utility scripts, seed data |
| `generated/` | Auto-generated database design documents |
| `database-dev.env` | Connection string สำหรับ dev environment |
| `database-dev - cds.env` | Connection string สำหรับ CDS dev environment |
| `AJT_SIS_Database_Design_v1.0_2026-06-13.docx` | Database design document v1.0 |
| `generate_db_design_doc.ps1` | PowerShell script สร้าง DB design doc |

---

## Connection Info — การเลือก Database Server

### 📍 ตัวเลือกที่ 1: Local Development (Docker/Local SQL Server)

**ไฟล์:** `database-dev.env`

```env
DB_SERVER=localhost,1437
DB_DATABASE=AJT_SIS
DB_USERNAME=sa
DB_PASSWORD=P@ssw0rd
```

**ใช้สำหรับ:**
- การพัฒนาแบบ local ด้วย Docker SQL Server
- การทดสอบ API และ business logic บนเครื่องส่วนตัว
- URL: `http://localhost:5288` (Web), `http://localhost:5000` (API)

---

### 📍 ตัวเลือกที่ 2: CDS Dev Server (192.168.11.40)

**ไฟล์:** `database-dev - cds.env`

```env
DB_SERVER=192.168.11.40
DB_DATABASE=AJT_SALE_INCENTIVE
DB_USERNAME=sa
DB_PASSWORD=P@ssw0rd
```

**ใช้สำหรับ:**
- การทดสอบบน staging/CDS server
- ทำงานเป็นทีม (shared database)
- Integration testing กับคนอื่น

---

### 🔑 วิธีเปลี่ยน Environment

**วิธี 1: ผ่าน Environment Variables (recommended)**

```powershell
# ตั้งค่าชั่วคราว (ใช้คำสั่งต่อไปนี้ก่อนรัน dev.ps1 หรือ dotnet run)
$env:DB_CONNECTION_STRING = "Server=192.168.11.40;Database=AJT_SALE_INCENTIVE;User Id=sa;Password=P@ssw0rd;Encrypt=True;TrustServerCertificate=True;"

# หรือใช้ PowerShell ที่ระบุไฟล์ .env
$env:DB_SERVER = "192.168.11.40"
$env:DB_DATABASE = "AJT_SALE_INCENTIVE"
```

**วิธี 2: แก้ไข appsettings.json โดยตรง**

> ⚠️ **ไม่แนะนำ** — อาจทำให้ commit ผิด file ขึ้น Git
> ใช้วิธี 1 หรือ user-secrets แทน

---

### 📝 ไฟล์ Credentials

รหัสผ่านทั้งหมดอยู่ใน `.env` files — **ห้าม commit ขึ้น GitHub**

| ไฟล์ | Server | Database | User | Password |
|---|---|---|---|---|
| `database-dev.env` | localhost,1437 | AJT_SIS | sa | P@ssw0rd |
| `database-dev - cds.env` | 192.168.11.40 | AJT_SALE_INCENTIVE | sa | P@ssw0rd |

> `.env` files อยู่ใน `.gitignore` ไปแล้ว

---

## การใช้งาน DDL

```powershell
# รัน DDL ทั้งหมดตามลำดับ (ดูลำดับ FK dependency ใน docs/02-technical/)
Get-ChildItem .\database\ddl\ -Filter *.sql | Sort-Object Name | ForEach-Object {
    Invoke-Sqlcmd -InputFile $_.FullName -ConnectionString (Get-Content .\database\database-dev.env)
}
```

---

## Stored Procedure Guides

เอกสาร SP ที่ใช้งานสำหรับ data management:

1. `scripts/usp_master_data_management.sql` (master data ชุดเดิม 14 procedures)
2. `scripts/usp_extended_data_management.sql` (extended write paths ชุดใหม่ 14 procedures)
3. `scripts/usp_extended_data_management_reference.md` (คู่มือเรียกใช้ทุก procedure พร้อม parameter และ EXEC ตัวอย่าง)
