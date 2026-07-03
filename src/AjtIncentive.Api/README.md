# AJT Incentive Calculation API — คู่มือใช้งาน Swagger UI

เอกสารนี้อธิบายวิธีเปิดใช้งานและทดสอบ REST API ผ่านหน้า Swagger UI
(`http://localhost:5000/swagger/index.html`) ของโปรเจกต์ `AjtIncentive.Api`

---

## 1. วิธีรัน API

```powershell
dotnet run --project src/AjtIncentive.Api/AjtIncentive.Api.csproj
```

ค่า default (ไม่มี `launchSettings.json`):

- URL: `http://localhost:5000`
- Environment: `Production`

ถ้าต้องการกำหนดพอร์ต/environment เอง:

```powershell
$env:ASPNETCORE_URLS = 'http://localhost:5100'
$env:ASPNETCORE_ENVIRONMENT = 'Development'
dotnet run --project src/AjtIncentive.Api/AjtIncentive.Api.csproj
```

เมื่อรันสำเร็จ เปิดเบราว์เซอร์ไปที่:

```
http://localhost:5000/swagger/index.html
```

หน้า Swagger UI จะแสดงรายการ endpoint ทั้งหมดของ API พร้อมให้ทดสอบเรียกได้ทันที (ไม่ต้องใช้ Postman)

---

## 2. ตั้งค่า API Key ก่อนใช้งาน (สำคัญ)

Endpoint เกือบทั้งหมด (ยกเว้น `GET /health`) ต้องส่ง header **`X-API-Key`** มาด้วยทุกครั้ง

### 2.1 ตั้งค่า Key ฝั่งเซิร์ฟเวอร์

แก้ไข `src/AjtIncentive.Api/appsettings.json` หรือใช้ user-secrets/env var แทนค่า
`__SET_IN_USER_SECRETS__`:

```json
"ApiSecurity": {
  "ApiKey": "your-dev-key-here"
}
```

หรือกำหนดผ่าน environment variable ชั่วคราวตอนรัน (ไม่ต้องแก้ไฟล์):

```powershell
$env:ApiSecurity__ApiKey = "your-dev-key-here"
```

> ระบบยังรองรับ multi-client + role-based ผ่าน `ApiSecurity:Clients[]` (ดูตัวอย่างใน
> `appsettings.json`) แต่ละ client มี API key และ role ของตัวเอง เช่น
> `CalcRunner`, `FormulaEditor`, `MasterEditor`, `SandboxRunner`, `ChannelAdmin`, `Admin`

### 2.2 ใส่ Key ในหน้า Swagger UI

1. เปิด `http://localhost:5000/swagger/index.html`
2. คลิกปุ่ม **Authorize** (มุมขวาบน มีไอคอนกุญแจ 🔒)
3. ในช่อง `ApiKey` ให้พิมพ์ค่า API key (พิมพ์ค่าตรงๆ **ไม่ต้อง** ใส่คำว่า `Bearer`)
4. กด **Authorize** แล้วกด **Close**
5. ทุก request ที่ลองยิงจาก Swagger จากนี้จะแนบ header `X-API-Key` ให้อัตโนมัติ

ถ้าลืม Authorize หรือ key ไม่ตรง จะได้ผลลัพธ์ `401 Unauthorized`
ถ้า key ถูกต้องแต่ role ไม่มีสิทธิ์เข้าถึง endpoint นั้น จะได้ `403 Forbidden`

---

## 3. ทดสอบเรียก endpoint ผ่าน Swagger UI

ขั้นตอนทั่วไปสำหรับทุก endpoint:

1. คลิกที่ endpoint ที่ต้องการ (เช่น `POST /api/v1/calculation/{channel}/run`) เพื่อขยายรายละเอียด
2. กด **Try it out**
3. กรอกค่า path parameter (เช่น `channel = MT`) และแก้ไข request body (JSON) ตามต้องการ
4. กด **Execute**
5. ดูผลลัพธ์ที่ส่วน **Response body** และ **Response headers** (มี `X-Correlation-Id` ติดมาด้วยทุกครั้ง เพื่อใช้ตามรอย log)

รูปแบบ response มาตรฐานของทุก endpoint (envelope):

```json
{
  "success": true,
  "message": null,
  "data": { }
}
```

ถ้า error จะได้ `success: false` พร้อม `message` อธิบายสาเหตุ (เช่น validation ผิด, ไม่มีสิทธิ์, ไม่พบข้อมูล)

---

## 4. กลุ่ม Endpoint ที่มีให้ทดสอบ

| กลุ่ม | Path หลัก | Role ที่ต้องมี | คำอธิบาย |
|---|---|---|---|
| Health | `GET /health` | ไม่ต้อง auth | เช็คว่า API ทำงานอยู่ |
| Calculation | `/api/v1/calculation/*` | `CalcRunner` หรือ `Admin` | สั่งคำนวณ, เช็คสถานะ, ดูผลลัพธ์ ต่อ channel (MT/SI/TT/LAOS หรือ channel ใหม่) |
| Formula | `/api/v1/formulas/*` | `FormulaEditor` หรือ `Admin` | จัดการสูตรคำนวณ (CRUD, activate/deactivate, validate) |
| Master Data | `/api/v1/masters/{table}` | `MasterEditor` หรือ `Admin` | จัดการ master ที่เกี่ยวกับการคำนวณ (product weight, incentive rate ฯลฯ) |
| Channel | `/api/v1/channels/*` | `ChannelAdmin` หรือ `Admin` | สร้าง channel ใหม่ + clone สูตร/master จาก channel เดิม |
| Sandbox | `/api/v1/calculation/sandbox/*` | `SandboxRunner` หรือ `Admin` | ทดลองคำนวณ (trial run) แบบไม่กระทบ production |

### 4.1 ตัวอย่าง: สั่งคำนวณ MT

`POST /api/v1/calculation/MT/run`

```json
{
  "periodId": 1,
  "engine": "StoredProcedure",
  "approvedBy": "your-name"
}
```

- `engine` เลือกได้ `StoredProcedure` | `SqlFunction` | `NCalc` (ถ้าไม่ระบุ จะใช้ค่า default จาก `appsettings.json` → `CalculationEngine:MT`)
- TT ต้องใช้ `periodCode` + `wsType` แทน `periodId`

### 4.2 ตัวอย่าง: ตรวจสอบสูตรก่อนใช้งานจริง

`POST /api/v1/formulas/validate`

```json
{
  "formulaExpr": "ROUND([base_rate] * [weight_pct] * [goal_mult], 0)"
}
```

จะได้ผลลัพธ์บอกว่าสูตร valid หรือไม่ พร้อมค่าตัวอย่างที่คำนวณได้ (`sampleResult`)

### 4.3 ตัวอย่าง: ทดลองคำนวณแบบ sandbox (ไม่กระทบ production)

`POST /api/v1/calculation/sandbox/run`

```json
{
  "targetChannel": "CH5",
  "sourceTransactionChannel": "MT",
  "periodId": 1,
  "engine": "NCalc",
  "persist": false
}
```

`persist: false` = คำนวณแล้วคืนผลทันที ไม่บันทึกลง DB
`persist: true` = บันทึกผลลง sandbox tables (`sbx_calc_run`, `sbx_incentive_detail`) แยกจาก production เด็ดขาด

---

## 5. ข้อควรระวัง

1. **Rate limit**: จำกัด 60 requests/นาที ต่อ API key (หรือต่อ IP ถ้าไม่ส่ง key) ถ้าเกินจะได้ `429 Too Many Requests`
2. **ห้ามใช้ API key จริง (production) ทดสอบบนเครื่อง local** — ใช้ key แยกสำหรับ dev/test เท่านั้น
3. Endpoint ที่แก้ไขข้อมูล (`POST`/`PUT`/`DELETE` ของ master/formula) จะ validate ช่วงวันที่ทับซ้อน (`effective_from`/`effective_to`) และ FK ให้อัตโนมัติ ถ้าไม่ผ่านจะได้ `400 BadRequest` พร้อมข้อความอธิบาย ไม่ใช่ error 500
4. การรัน `calculation/{channel}/run` ซ้ำในช่วงเวลา/period เดิม จะเป็นการ **recalculate ทับของเดิม** (idempotent) ไม่ใช่การสร้างข้อมูลซ้ำซ้อน

---

## 6. ไฟล์ที่เกี่ยวข้อง

- **รายละเอียด endpoint ครบทุกตัว (request/response body):** [`API_REFERENCE.md`](API_REFERENCE.md)
- Endpoint ทั้งหมด: [`Program.cs`](Program.cs)
- Authentication/Authorization: [`Security/ApiKeyAuthenticationHandler.cs`](Security/ApiKeyAuthenticationHandler.cs)
- ตัวอย่าง config: [`appsettings.json`](appsettings.json)
- ชุดทดสอบอัตโนมัติ (รวม DB integration tests): [`../AjtIncentive.Api.Tests/README.md`](../AjtIncentive.Api.Tests/README.md)
- สคริปต์ regression ยิง API จริง: [`../../test-scenarios/regression-toolkit/api/README.md`](../../test-scenarios/regression-toolkit/api/README.md)
