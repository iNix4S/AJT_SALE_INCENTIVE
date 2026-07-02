# SI Regression Toolkit

โฟลเดอร์นี้ใช้เก็บสคริปต์และ runner สำหรับ regression parity test ของ SI channel

## Contents

1. create_baseline_snapshot.sql
   - รัน StoredProcedure baseline แล้วบันทึก snapshot ลงตารางชั่วคราว
   - ตารางที่ใช้: dbo.tmp_si_baseline_detail, dbo.tmp_si_baseline_hr

2. compare_with_baseline_snapshot.sql
   - เปรียบเทียบ run ปัจจุบันกับ baseline snapshot
   - ใช้ EXCEPT สองทิศทางสำหรับ detail และ HR

3. runner/
   - Console app สำหรับเรียก SI engine โดยตรง
   - รองรับ: StoredProcedure, SqlFunction, NCalc

## Quick usage

1. สร้าง baseline snapshot
   - sqlcmd -S <server> -d AJT_SALE_INCENTIVE -U <user> -P <password> -i test-scenarios/regression-toolkit/si/create_baseline_snapshot.sql

2. รัน engine ที่ต้องการ (ตัวอย่าง SqlFunction)
   - dotnet run --project test-scenarios/regression-toolkit/si/runner/SiEngineRunner.csproj -- SqlFunction 1 "<connection-string>"

3. เทียบผลกับ baseline
   - sqlcmd -S <server> -d AJT_SALE_INCENTIVE -U <user> -P <password> -i test-scenarios/regression-toolkit/si/compare_with_baseline_snapshot.sql
