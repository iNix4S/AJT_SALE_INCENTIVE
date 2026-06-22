# Sheet: Aji Plus / RDQ / RDM / RDNS (+ Actual_*) — Special Product Incentive

> เวอร์ชัน: Draft v0.1 — 2026-06-13
> ครอบคลุม: **ทั้ง MT และ TT** (โครงสร้างเหมือนกัน ต่างที่ค่าฐาน payout)
> ที่มา (หลักฐาน): MT `24_Aji Plus`, `26_RDQ`, `28_RDM`, `30_RDNS` + `Actual_*` / TT `18`,`20`,`22`,`24` + `Actual_*` / `04_Test`
> สถานะ: ปิดช่องว่างใหญ่ที่สุดจาก [05.Process-Flow ❓ข้อ 1](../../05.Process-Flow/01_Data-Flow-Diagram.md)

- **ไฟล์ต้นทาง:** MT **และ** TT (มีครบทั้ง 2 ช่องทาง)
- **ประเภท:** Calculation (sheet คำนวณ incentive ของสินค้าพิเศษ) + Input (`Actual_*`)
- **จำนวนแถว x คอลัมน์:** sheet คำนวณ 58 x ~68 / `Actual_*` 62–63 x 8

---

## 1. สรุปสั้น (Executive Summary)

มีสินค้า **4 ตัวที่ถูกแยกออกมาคำนวณ Incentive ต่างหาก** จากสูตรหลัก (Target & Cal) แต่ละตัวมี sheet คำนวณของตัวเอง + sheet `Actual_*` ของตัวเอง:

| Sheet | สินค้า | กลุ่มเดิม | คาดว่าตรงกับรหัส |
|-------|--------|----------|------------------|
| `Aji Plus` | AJI-PLUS | G2 (GD) | MT `AJP` / TT `AP` |
| `RDQ` | ROSDEE CUBE (Q) | G2 (GD) | MT `RDC`/`QM` / TT `Q` |
| `RDM` | ROSDEE MENU | G2 (GD) | MT `RM` / TT `M` |
| `RDNS` | ROSDEE NOODLE | G2 (GD) | MT `ND` / TT `NS` |

> 🔑 **ทั้ง 4 ตัวคือสินค้ากลุ่ม G2 "GD" ทั้งหมด** — น่าจะเป็นกลุ่ม **Growth Driver** ที่บริษัทต้องการผลักดันยอดเป็นพิเศษ จึงตั้ง incentive แยกราย "สินค้า x salesman x เดือน" ของตัวเอง

> ⚠️ **ข้อค้นพบวิกฤต:** จากการ grep ทั้งชุด — sheet ทั้ง 4 **ไม่ถูกอ้างอิงโดย `Target & Cal` หรือ `For HR` เลย** ในไฟล์ทดสอบนี้ (ถูกอ้างเฉพาะใน sheet `Test` ซึ่งเป็น sandbox มี `#REF!` + ชื่อ "MR.X") → **ยังไม่มีเส้นทางต่อยอดเข้าผลลัพธ์จ่ายจริง** ดู §5

---

## 2. โครงสร้างแต่ละ sheet (เหมือนกันทั้ง 4 ตัว)

ตัวอย่างแกน column (จาก `Aji Plus`):

| ช่วงคอลัมน์ | เนื้อหา | ที่มา |
|-------------|---------|-------|
| A | Salesman Code (รหัสบัญชี BI เช่น `1190011201`) | key |
| B, C, D | Emp code, ชื่อ, Sales Office | |
| E–P (12 คอลัมน์) | **Target** ราย 12 เดือน (Apr→Mar) | กรอกในชีต |
| R–AC (12) | **Actual** ราย 12 เดือน | `=XLOOKUP/VLOOKUP(A, 'Actual_<X>'!, …)` ดึงจาก sheet Actual ของตัวเอง |
| AE–AP (12) | achievement ดิบ = Actual ÷ Target ราย product/เดือน | `=R2/E2` … |
| AR–BC (12) | `=ROUND(achievement, 4)` | ปัด 4 ตำแหน่ง |
| BE–BP (12) | **payout รายเดือน** = `VLOOKUP(rounded_ach, 'Top WS'!$A$19:$C$28, col)` | ดูตาราง payout §3 |
| BQ | `=SUM(BE:BP)` = **ยอด incentive รวมทั้งปีของสินค้านี้ ต่อ salesman** | (มีใน RDQ/RDM/RDNS; Aji Plus คำนวณรายเดือนเช่นกัน) |

**`Actual_<X>` sheet** (8 คอลัมน์): `Salesman Code, Sales Office, April, May, June, July, August, September`
→ ปัจจุบันมีข้อมูลจริง **6 เดือน (Apr–Sep)** เท่านั้น (ไฟล์ทดสอบ) ที่เหลือเป็น 0/ว่าง

---

## 3. ตรรกะการคำนวณ (ยืนยันจากสูตรจริง ✅)

```
achievement[เดือน] = ROUND( Actual[เดือน] / Target[เดือน] , 4 )      ← ราย product ตัวเดียว

payout[เดือน]      = IFERROR( VLOOKUP( achievement[เดือน],
                                       'Top WS'!$A$19:$C$28,           ← ตาราง threshold→เงิน
                                       col_ของสินค้านั้น ) , 0 )

incentive_ปี[สินค้า, salesman] = SUM( payout ทุกเดือน )                ← คอลัมน์ BQ
```

### จุดสำคัญที่ต่างจากสูตรหลัก
1. **payout เป็น "จำนวนเงินคงที่ตามขั้น" ไม่ใช่ base × goal × weight** — VLOOKUP คืน "จำนวนบาท" ตรง ๆ ตามขั้น achievement (ไม่มี weight, ไม่มี incentive base ตามตำแหน่ง)
2. **แต่ละสินค้าอ่านคนละคอลัมน์ในตาราง `Top WS` rows 19–28** จึงได้ค่าฐานต่างกัน:

| สินค้า | คอลัมน์ที่ VLOOKUP | ค่าฐาน (ที่ ach 100%) MT | ค่าฐาน TT |
|--------|--------------------|--------------------------|-----------|
| Aji Plus | col 2 | **200** (ช่วง 200–260) | **180** (180–260) |
| RDQ | col 3 | **400** (ช่วง 400–520) | (ตรวจเพิ่ม) |
| RDM | (ตรวจเพิ่ม) | — | — |
| RDNS | (ตรวจเพิ่ม) | — | — |

3. **ขั้นบันได payout** (จาก `Test` แถว 4–5, ฐาน 200): ach 0.90/0.95/1.00/1.03 → 200 คงที่, 1.06→206, 1.10→216, 1.15→220, 1.20→230, 1.25→240, 1.30→260
   → โครงสร้างขั้นเดียวกับ GOAL หลัก แต่ map เป็น "เงินบาท" แทน "ตัวคูณ"

---

## 4. Input / Output

**Input:**
- Target รายเดือน — กรอกตรงในชีต (ต้องยืนยันแหล่งที่มา/ผู้กรอก ❓)
- Actual รายเดือน — ดึงจาก `Actual_<X>` ซึ่ง copy มาจาก **BI** (เหมือน Actual หลัก แต่เป็นคนละชุด/คนละ sheet)
- ตาราง payout — `Top WS` (และ `WS SF`/`WS WH` สำหรับ salesman บางตำแหน่ง — สูตรบางแถวชี้ไป `' WS SF'`/`'WS WH'`)

**Output:**
- ❌ **ไม่พบการส่งต่อไป `Target & Cal` หรือ `For HR`** — ปลายทางที่แท้จริงยังไม่ชัด (ดู §5)

---

## 5. ช่องว่าง / คำถามที่ต้องปิดกับ Business (สำคัญต่อ BRD/SRS)

| # | คำถาม | ผลกระทบต่อ BRD/SRS |
|---|-------|---------------------|
| SP-1 | incentive ของ 4 สินค้านี้ **ถูกนำไปจ่ายอย่างไร** — รวมเข้า For HR (บวกเพิ่ม) หรือจ่ายแยกคนละก้อน? | สูง — กำหนด scope ของ Output/Payout engine |
| SP-2 | เหตุใดในไฟล์ทดสอบจึงยังไม่ wire เข้า For HR — เป็น scheme ใหม่ที่ยัง prototype หรือ workbook นี้ไม่สมบูรณ์? | สูง — กำหนดว่าต้อง implement หรือไม่ |
| SP-3 | สินค้า G2 เหล่านี้ **ถูกคิด incentive ซ้ำซ้อนหรือไม่** (ทั้งใน weight 0.05 ของสูตรหลัก + ใน scheme แยกนี้)? | สูง — risk จ่ายเบิ้ล |
| SP-4 | Target รายเดือนของ scheme นี้มาจากไหน ใครอนุมัติ | กลาง — data source/governance |
| SP-5 | payout ฐาน (200/400/…) ของ RDM, RDNS และค่าฝั่ง TT ที่เหลือ — ต้องสกัดเพิ่ม | กลาง — parameter table |
| SP-6 | ทำไม Actual มีแค่ 6 เดือน (Apr–Sep) — รอบ scheme = ครึ่งปี หรือข้อมูลทดสอบไม่ครบ? | กลาง — period model |

---

## 6. ข้อเสนอเพื่อบรรจุใน BRD/SRS (Draft)

- เพิ่ม **"Special Product Incentive (Growth Driver / GD)"** เป็น functional area แยกใน Calculation Engine:
  - FR ใหม่: คำนวณ incentive ราย product พิเศษ (Aji Plus/RDQ/RDM/RDNS) ด้วย achievement → step payout table (คนละคอลัมน์ต่อสินค้า) → รวมรายปี
  - Business Rule ใหม่: ระบุว่า scheme นี้ **เพิ่มเติม** หรือ **แทนที่** น้ำหนัก G2 ในสูตรหลัก (ปิด SP-3)
- เพิ่ม Data Entity: `SpecialProductTarget`, `SpecialProductActual` (รายเดือน), `SpecialProductPayoutTable`
- เพิ่ม Open Question SP-1…SP-6 เข้า §16 ของ BRD/SRS
