# Sheet: 3) Target & Cal (TT)

- **ไฟล์ต้นทาง:** TT (รวมทุกระดับใน 1 sheet — ต่างจาก MT ที่แยก 4 sheets)
- **ประเภท:** Calculation (หลัก)
- **จำนวนแถว x คอลัมน์:** หลายพันแถว x 65+ คอลัมน์

## วัตถุประสงค์ของ sheet
คำนวณ incentive ของ TT Salesman **ทุกระดับรวมในชีตเดียว**  
แต่ละแถว = 1 SalesmanCode × 1 Product (ตาม SKU/Product Code)

ต่างจาก MT ที่มี 4 sheets แยก (Staff/Sect/Dept/AD)  
TT มีแค่ 1 sheet แต่ใน 1) For HR จะแสดงผลแยกตามระดับ (Direct Sup, Dept Mgr, Div Mgr, AD)

## Input (รับข้อมูลจากไหน)
- **Target** (col D–O): เป้าหมายรายเดือน (Apr–Mar)
- **Actual** (col P–AA): ยอดขายจริงจาก Actual sheet (ไม่ผ่าน Mapping — TT ตรงได้เลย)
- **Shortage** sheet: override achievement เป็น 1.0
- **2) Table** sheet: อัตรา incentive ตาม GOAL bracket
- **Period** sheet: เดือนที่คำนวณ
- **ASTBase** sheet: hierarchy (DirectSupCode)

## Output (ส่งข้อมูลไปไหน)
- ถูกอ้างอิงโดย **1) For HR** และ **1) For HR (AD)** — SUMIFS บน col Incentive ตาม SalesmanCode

## สูตร/ตรรกะสำคัญ

### โครงสร้างคอลัมน์ (เหมือน MT Staff sheet)

| กลุ่มคอลัมน์ | ช่วง | ความหมาย |
|-------------|------|----------|
| SalesmanCode | A | รหัส Salesman (ตรงกับ BI — ไม่ต้อง Mapping) |
| Product | B | รหัส product (**TT codes**: A, R, B, AP, M, Q, NS, Y, P, T, RK) |
| Team | C | Team reference (Top WS = default) |
| Target | D–O | เป้าหมาย Apr–Mar |
| Actual | P–AA | ยอดขายจริง Apr–Mar |
| % raw | AB–AM | achievement ไม่ round |
| % Round + Shortage | AN–AY | achievement ROUND 4 + Shortage override |
| Incentive | AZ–BM | incentive ตาม GOAL bracket |
| Incentive (เดือนปัจจุบัน) | BN | ผลลัพธ์หลัก (ตาม Period) |
| DirectSupCode | BO | รหัส supervisor (ใช้ใน For HR) |
| %Salesman | BP | achievement รวม (ใช้แสดงผล) |

### Product Codes TT (ต่างจาก MT)

| TT Code | ชื่อสินค้า | MT Code เทียบเท่า |
|---------|-----------|-----------------|
| A | AJINOMOTO | AJ |
| R | ROSDEE | RD |
| B | BIRDY | BD |
| AP | AJI-PLUS | AJP |
| M | ROSDEE MENU | RM |
| Q | ROSDEE CUBE | RDC |
| NS | ROSDEE NOODLE | ND |
| Y | YUMYUM | YY |
| P | POWDER COFFEE | PDC |
| T | Takumi-Aji | TKM |
| RK | ROSDEE MENU KKR | RKR |

### ตัวอย่างข้อมูล (SalesmanCode 160001, Product A)
- Target Dec 2025 = 104,231 / Actual Dec 2025 = 104,164
- Achievement = 1.00 (≥1.00) → Incentive = 200 บาท
- DirectSupCode = 160000

## ข้อสังเกต / คำถามค้างคา
- **ไม่มี Mapping sheet** — SalesmanCode ใน TT ตรงกับ BI SalesmanCode ได้เลย
- col C "Team" = "Top WS" ใน TT (ต่างจาก MT ที่ใช้ Salesman Code จริง) — ❓ หมายความว่าอะไร?
- ❓ TT ไม่มี cascade แยก sheet → การคำนวณระดับ Dept/AD ทำอย่างไร? — คาดว่า 1) For HR ทำ SUMIFS ด้วย DirectSupCode chain
- ❓ ตัวเลข incentive TT (200 บาท/product) ต่ำกว่า MT (400+ บาท) — ตั้งใจหรือเป็น test data?
