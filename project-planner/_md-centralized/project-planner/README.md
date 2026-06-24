# project-planner

โฟลเดอร์นี้ใช้เก็บไฟล์สำหรับ **วางแผนและกำหนดขอบเขต Demo POC**
ของระบบ AJT New Sale Incentive System
ที่พัฒนาด้วย **.NET Core 10 + Microsoft SQL Server**

---

## วัตถุประสงค์

Demo POC นี้มีเป้าหมายเพื่อ:
1. **แสดงให้ลูกค้าเห็น** ว่าระบบ Incentive ทำงานได้จริงบน Web Application
2. **ยืนยัน Architecture** — .NET Core 10 Web API + MS SQL Server
3. **ครอบคลุม Happy Path** ของ Monthly Workflow ตั้งแต่ Import → Calculate → Approve → Export

---

## ไฟล์ในโฟลเดอร์นี้

| ไฟล์ | วัตถุประสงค์ |
|---|---|
| `README.md` | Overview และ index |
| `Demo-POC_Scope.md` | ขอบเขต Demo POC — Feature list, In/Out-of-scope, Acceptance Criteria |
| `Demo-POC_Project-Plan.md` | Project Plan — Phases, Tasks, Timeline, Milestones |

---

## ข้อมูลอ้างอิงโครงการ

- **Tech Stack:** .NET Core 10, MS SQL Server (AJT_SALE_INCENTIVE)
- **DB Dev:** `192.168.11.40` / `AJT_SALE_INCENTIVE` / `sa`
- **Channel ที่รองรับ:** MT (CASCADE_4_LEVEL), TT (SINGLE_SHEET_5_LEVEL_AVG)
- **SP ที่มีแล้ว:** `usp_run_mt_incentive_calculation`, `usp_run_tt_incentive_calculation`

## เอกสารอ้างอิงหลัก

| เอกสาร | ที่อยู่ |
|---|---|
| Project Scope Summary | `final-docs/AJT_Project-Scope-Summary.md` |
| Solution & Tech Stack | `final-docs/AJT_Solution-and-Technology-Stack_Summary.md` |
| Business Process Design | `5.Docs/Business-Process-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md` |
| DB Design | `4.System Analyst and Design/database design/DB-Design_AJT-New-Sale-Incentive_v1.0_2026-06-13.md` |
| MT Quick Run & Check | `final-docs/AJT_MT_Quick_Run_And_Check.sql` |
| TT Quick Run & Check | `final-docs/AJT_TT_Quick_Run_And_Check.sql` |
