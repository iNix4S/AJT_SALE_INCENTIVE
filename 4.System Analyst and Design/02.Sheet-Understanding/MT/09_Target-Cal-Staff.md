# Sheet: 3) Target & Cal_Staff

- **ไฟล์ต้นทาง:** MT (แยกเป็น 4 sheets: Staff / Sect / Dept / AD)  
  TT (รวมเป็น sheet เดียว: 3) Target & Cal)
- **ประเภท:** Calculation (หลัก)
- **จำนวนแถว x คอลัมน์:** หลายร้อยแถว x 65+ คอลัมน์

## วัตถุประสงค์ของ sheet
**Sheet การคำนวณหลัก** — คำนวณ incentive รายเดือนสำหรับ Salesman ระดับ Staff  
แต่ละแถว = 1 Salesman × 1 Product Group  
ผลลัพธ์ (col BN = Incentive) จะถูก SUMIFS โดย Sect/Dept/AD sheet และ For HR

## Input (รับข้อมูลจากไหน)
- **Target** (col D–O): กรอก manual หรือ import จาก Sales Target sheet (ต่อ product ต่อเดือน)
- **Actual** (col P–AA): SUMIFS จาก Actual+Mapping (ยอดขายจริงจาก BI)
- **Shortage** (col AC–AN): VLOOKUP จาก Shortage sheet (override achievement)
- **2) Table** sheet: XLOOKUP/VLOOKUP หา incentive amount ตาม GOAL bracket
- **Period** sheet: กำหนดว่าคอลัมน์เดือนใดที่ใช้ในการคำนวณ

## Output (ส่งข้อมูลไปไหน)
- **col BN (Incentive)**: ถูก SUMIFS โดย Sect, Dept, AD sheet และ 1) For HR

## สูตร/ตรรกะสำคัญ

### โครงสร้างคอลัมน์หลัก

| กลุ่มคอลัมน์ | ช่วง | ความหมาย |
|-------------|------|----------|
| DirectSupCode | A | รหัส supervisor ตรง (ใช้ SUMIFS cascade) |
| Product | B | รหัส product group |
| Team | C | Salesman Code (Team) |
| Target | D–O | เป้าหมายรายเดือน (Apr–Mar) |
| Actual | P–AA | ยอดขายจริงรายเดือน (Apr–Mar) |
| % Actual/Target (raw) | AB–AM | achievement (ไม่ round) |
| % Round | AN–AY | achievement (ROUND 4 ทศนิยม) + Shortage override |
| Incentive | AZ–BM | incentive amount ตาม GOAL bracket (ก่อนเลือกเดือน) |
| **col BN** | **BN** | **Incentive เดือนปัจจุบัน (ผลลัพธ์หลัก)** |
| Emp Code | BO | รหัสพนักงาน |
| Incentive (repeat) | BP | incentive เดือนปัจจุบัน (แสดงซ้ำ) |

### สูตรหลัก

| เซลล์ | สูตร | ความหมาย |
|-------|------|----------|
| AC4 (% round + shortage) | `=IFERROR(IF(VLOOKUP($B4,Shortage!$A:$M,AC$2,FALSE)="Shortage",1, IFERROR(ROUND(Q4/E4,4),0)),IFERROR(ROUND(Q4/E4,4),0))` | achievement ROUND 4 ทศนิยม; ถ้า Shortage = 1.0 |
| Incentive column | `=XLOOKUP(achievement, GOAL_thresholds, incentive_brackets, , 1, -1)` | Step-down lookup — ได้ incentive จาก Table ตาม achievement |
| BN (ผลลัพธ์) | อ้างอิงคอลัมน์เดือนปัจจุบันจาก Period | incentive เดือนที่กำหนดใน Period sheet |

### Logic การคำนวณ (ทีละขั้น)
```
1. Actual[เดือน] / Target[เดือน] = achievement (ROUND 4 ทศนิยม)
2. ถ้า Shortage flag → achievement = 1.0 (100%)
3. XLOOKUP(achievement, GOAL table, incentive table, mode=step-down) → incentive amount
4. เลือกเดือนจาก Period → col BN = incentive เดือนนั้น
```

## ข้อสังเกต / คำถามค้างคา
- ❓ Target ใน col D–O มาจากไหน? manual หรือ Sales Target sheet? (ยังไม่ชัด)
- col A (DirectSupCode) ใช้เป็น key ใน SUMIFS ระดับ Sect — **ต้องตรงกับ ASTBase**
- Salesman Code (col C = Team) อาจเป็น Salesman จาก ASTBase หรือ Manager code ก็ได้ (ขึ้นกับ row)
- ❓ หากพนักงานไม่มี target บาง product (target=0) — สูตร IFERROR จัดการอยู่แล้ว (return 0)
