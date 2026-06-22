# 03. Calculation Logic

รวบรวมตรรกะการคำนวณ Sales Incentive ที่ถอดได้จากไฟล์ .xlsx ทั้ง MT และ TT
เป้าหมายคือเปลี่ยนสูตรใน Excel ให้เป็นกฎเชิงธุรกิจ (business rules) ที่นำไปพัฒนาระบบได้

## หัวข้อที่ต้องสรุป
- โครงสร้างกลุ่มสินค้า: Aji Plus / RDQ / RDM / RDNS
- การกำหนด **Target** (ราย Staff / Section / Dept / AD)
- การเก็บ **Actual** และการคำนวณ **% Achievement**
- ตารางอัตรา/ขั้นบันได payout ("2) หลักการคำนวน Table")
- เงื่อนไข Shortage และค่าตอบแทนในอัตราคงที่
- ความต่างของกฎระหว่างช่องทาง **MT** กับ **TT**

> อ้างอิงสูตรดิบได้จาก `01.Raw-Extracts/<MT|TT>/*.formulas.csv`
