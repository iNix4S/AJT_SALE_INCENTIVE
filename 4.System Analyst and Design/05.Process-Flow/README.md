# 05. Process Flow

แผนภาพและคำอธิบายลำดับการไหลของข้อมูล/การคำนวณข้าม sheet
ตั้งแต่การนำเข้า Target & Actual จนถึงผลลัพธ์ Incentive ที่ส่งให้ HR

## สิ่งที่ควรมี
- Data Flow ภาพรวม: แหล่งข้อมูล → คำนวณ → output (1) For HR)
- ลำดับการคำนวณข้าม sheet (dependency chain)
- จุดเชื่อมต่อกับไฟล์ภายนอก (externalLinks ที่พบในไฟล์ต้นฉบับ)
- ความต่างของ flow ระหว่าง MT และ TT

> แนะนำเขียน diagram ด้วย Mermaid เพื่อให้แก้ไข/รีวิวง่าย เช่น:
>
> ```mermaid
> flowchart LR
>   Target --> Cal
>   Actual --> Cal
>   Cal --> ForHR[1) For HR]
> ```
