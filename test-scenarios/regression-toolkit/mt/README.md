# MT Regression Toolkit

โฟลเดอร์นี้ใช้เก็บสคริปต์และ runner สำหรับ regression parity test ของ MT channel

## Contents

1. create_baseline_snapshot.sql
   - รัน StoredProcedure baseline แล้วบันทึก snapshot ลงตารางชั่วคราวใน DB
   - ตารางที่ใช้: dbo.tmp_mt_baseline_detail, dbo.tmp_mt_baseline_hr

2. compare_with_baseline_snapshot.sql
   - เปรียบเทียบ run ปัจจุบันกับ baseline snapshot
   - ใช้ EXCEPT สองทิศทางสำหรับ detail และ HR

3. baseline_vs_sqlfunction.sql
   - รัน baseline และ SqlFunction ต่อเนื่องในสคริปต์เดียว แล้วรายงาน diff

4. runner/
   - Console app สำหรับเรียก MT engine โดยตรง
   - รองรับ: StoredProcedure, SqlFunction, NCalc

## Quick usage

1. สร้าง baseline snapshot
   - sqlcmd -S <server> -d AJT_SALE_INCENTIVE -U <user> -P <password> -i test-scenarios/regression-toolkit/mt/create_baseline_snapshot.sql

2. รัน engine ที่ต้องการ (ตัวอย่าง NCalc)
   - dotnet run --project test-scenarios/regression-toolkit/mt/runner/MtEngineRunner.csproj -- NCalc 1 "<connection-string>"

3. เทียบผลกับ baseline
   - sqlcmd -S <server> -d AJT_SALE_INCENTIVE -U <user> -P <password> -i test-scenarios/regression-toolkit/mt/compare_with_baseline_snapshot.sql
