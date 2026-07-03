# AJT Incentive Calculation API — API Endpoint Reference

เอกสารนี้อธิบายรายละเอียดของทุก endpoint ใน `AjtIncentive.Api` แบบครบถ้วน
(method, path, role ที่ต้องมี, request body, response body) สำหรับใช้เป็น reference
ตอนเรียก API ตรงๆ (Postman, script, Swagger)

> วิธีเปิด Swagger UI และตั้งค่า API Key ดูได้ที่ [`README.md`](README.md)

---

## รูปแบบ Response มาตรฐาน (Envelope)

ทุก endpoint (ยกเว้น `GET /health`) คืนค่าใน envelope เดียวกัน:

```json
{
  "success": true,
  "message": null,
  "data": { }
}
```

- `success: false` เมื่อ validation ผิด/ไม่พบข้อมูล/ไม่มีสิทธิ์ — ดูสาเหตุใน `message`
- ทุก response แนบ header `X-Correlation-Id` เพื่อใช้ตามรอย log เสมอ

### HTTP Status ที่พบได้

| Status | ความหมาย |
|---|---|
| 200 OK | สำเร็จ |
| 400 BadRequest | validation ผิด (periodId ไม่ถูกต้อง, ช่วงวันที่ทับซ้อน ฯลฯ) |
| 401 Unauthorized | ไม่ได้ส่ง header `X-API-Key` หรือ key ผิด |
| 403 Forbidden | key ถูกต้องแต่ role ไม่มีสิทธิ์เข้าถึง endpoint |
| 404 NotFound | ไม่พบ resource (เช่น `calcRunId`, `formulaCode`) |
| 429 TooManyRequests | เกิน rate limit (60 requests/นาที ต่อ API key หรือต่อ IP) |
| 500 InternalServerError | unhandled exception (มี log พร้อม TraceId) |

### Authentication

ทุก request ต้องส่ง header:

```
X-API-Key: <your-api-key>
```

---

## 1. Health

### `GET /health`

ไม่ต้อง authentication เช็คว่า API ทำงานอยู่หรือไม่

**Response**

```json
{ "status": "ok" }
```

---

## 2. Calculation — `/api/v1/calculation`

Role ที่ต้องมี: **`CalcRunner`** หรือ **`Admin`**

### 2.1 `POST /api/v1/calculation/{channel}/run`

สั่งคำนวณ incentive สำหรับ channel ที่ระบุ (`MT`, `SI`, `TT`, `LAOS` หรือ channel ใหม่ที่สร้างผ่าน `/channels`)

**Path parameter**

| ชื่อ | ประเภท | คำอธิบาย |
|---|---|---|
| `channel` | string | รหัส channel เช่น `MT`, `SI`, `TT`, `LAOS`, หรือ channel code ที่สร้างใหม่ |

**Request body** (`RunCalculationRequest`)

```json
{
  "periodId": 1,
  "periodCode": null,
  "wsType": null,
  "engine": "StoredProcedure",
  "approvedBy": "your-name"
}
```

| ฟิลด์ | ประเภท | บังคับ | คำอธิบาย |
|---|---|---|---|
| `periodId` | int? | บังคับสำหรับ `MT`, `SI`, `LAOS` และ channel ใหม่ | ต้อง > 0 |
| `periodCode` | string? | บังคับสำหรับ `TT` | รหัส period เช่น `"2026-06"` |
| `wsType` | string? | บังคับสำหรับ `TT` | เช่น `"A"`, `"B"` ฯลฯ (ตาม worksheet type) |
| `engine` | string? | ไม่บังคับ | `StoredProcedure` \| `SqlFunction` \| `NCalc` — ถ้าไม่ระบุใช้ค่า default จาก `appsettings.json` (`CalculationEngine:{Channel}`) |
| `approvedBy` | string? | ไม่บังคับ | ค่า default = `"api"` ถ้าไม่ระบุ |

**Response** (`RunCalculationResponse`)

```json
{
  "success": true,
  "message": null,
  "data": {
    "channel": "MT",
    "calcRunId": 123,
    "status": "CALCULATED"
  }
}
```

**หมายเหตุ**: การรันซ้ำใน period เดิมเป็นการ **recalculate ทับของเดิม** (idempotent)

---

### 2.2 `GET /api/v1/calculation/runs/{calcRunId}`

ดูสถานะของการคำนวณตาม `calcRunId`

**Path parameter**: `calcRunId` (int)

**Response** (`CalcRunStatusDto`)

```json
{
  "success": true,
  "message": null,
  "data": {
    "calcRunId": 123,
    "periodId": 1,
    "channelId": 2,
    "channelCode": "MT",
    "runStatus": "CALCULATED",
    "calculatedAt": "2026-07-01T10:00:00",
    "approvedAt": null,
    "approvedBy": "api",
    "createdAt": "2026-07-01T10:00:00",
    "updatedAt": null,
    "detailRows": 150,
    "hrRows": 120
  }
}
```

ถ้าไม่พบ `calcRunId` → `404 NotFound`

---

### 2.3 `GET /api/v1/calculation/{channel}/results?periodId={id}`

ดูผลลัพธ์ For-HR ของ channel + period ที่ระบุ

**Path parameter**: `channel` (string)
**Query parameter**: `periodId` (int, บังคับ, ต้อง > 0)

**Response**

```json
{
  "success": true,
  "message": null,
  "data": [
    {
      "employeeId": 100,
      "employeeCode": "E001",
      "incentiveAmount": 5000.00
      // ... ฟิลด์อื่นตาม IncentiveResult entity
    }
  ]
}
```

ถ้า channel ไม่พบใน `mst_channel` → `400 BadRequest` (`"Unsupported channel"`)

---

## 3. Formulas — `/api/v1/formulas`

Role ที่ต้องมี: **`FormulaEditor`** หรือ **`Admin`**

### 3.1 `GET /api/v1/formulas?channel={code}&step={step}&activeOnly={bool}`

ดูรายการสูตรทั้งหมด (filter ได้)

**Query parameters** (ทั้งหมดไม่บังคับ)

| ชื่อ | ประเภท | คำอธิบาย |
|---|---|---|
| `channel` | string? | filter ตาม channel code |
| `step` | string? | filter ตามขั้นตอนการคำนวณ (`formula_step`) |
| `activeOnly` | bool | ถ้า `true` แสดงเฉพาะสูตรที่ `is_active = 1` |

### 3.2 `GET /api/v1/formulas/{formulaCode}`

ดูสูตรตาม `formulaCode` — ถ้าไม่พบ → `404 NotFound`

### 3.3 `POST /api/v1/formulas`

สร้างสูตรใหม่

**Request body** (`FormulaUpsertRequest`)

```json
{
  "formulaCode": "MT_INCENTIVE_L1",
  "formulaName": "MT Incentive Level 1",
  "formulaStep": "CALCULATE_INCENTIVE",
  "channelId": 1,
  "positionLevelId": null,
  "wsType": null,
  "formulaExpr": "ROUND([base_rate] * [weight_pct] * [goal_mult], 0)",
  "variablesJson": "[\"base_rate\",\"weight_pct\",\"goal_mult\"]",
  "description": "คำนวณ incentive ระดับ 1 ของ MT",
  "sortOrder": 1,
  "effectiveFrom": "2026-01-01",
  "effectiveTo": null,
  "isActive": true
}
```

**Response**

```json
{ "success": true, "message": null, "data": { "formulaId": 45 } }
```

Validate ช่วงวันที่ทับซ้อน (`effective_from`/`effective_to`) และ FK อัตโนมัติ — ถ้าไม่ผ่านได้ `400 BadRequest` พร้อมข้อความอธิบาย

### 3.4 `PUT /api/v1/formulas/{formulaCode}`

แก้ไขสูตรที่มีอยู่ — request body รูปแบบเดียวกับ `POST /formulas`

### 3.5 `POST /api/v1/formulas/{formulaCode}/activate`

เปิดใช้งานสูตร (`is_active = 1`)

**Response**: `{ "success": true, "data": { "updatedRows": 1 } }`

### 3.6 `POST /api/v1/formulas/{formulaCode}/deactivate`

ปิดใช้งานสูตร (`is_active = 0`)

### 3.7 `POST /api/v1/formulas/validate`

ตรวจสอบว่าสูตร valid หรือไม่ พร้อมค่าตัวอย่างที่คำนวณได้ (ไม่ต้อง auth เพิ่มเติมนอกจาก `FormulaEditor`)

**Request body** (`FormulaValidationRequest`)

```json
{
  "formulaExpr": "ROUND([base_rate] * [weight_pct] * [goal_mult], 0)",
  "sampleVariables": {
    "base_rate": 1000,
    "weight_pct": 0.5,
    "goal_mult": 1.2
  }
}
```

**Response** (`FormulaValidationResponse`)

```json
{
  "success": true,
  "data": {
    "isValid": true,
    "errorMessage": null,
    "sampleResult": 600,
    "variables": ["base_rate", "weight_pct", "goal_mult"]
  }
}
```

---

## 4. Master Data — `/api/v1/masters/{table}`

Role ที่ต้องมี: **`MasterEditor`** หรือ **`Admin`**

### 4.1 `GET /api/v1/masters/{table}?take={n}`

ดูรายการ master data ของตาราง `{table}` ที่ระบุ

**Query parameter**: `take` (int, ไม่บังคับ, default = 200 ถ้า `<= 0` หรือไม่ระบุ)

### 4.2 `POST /api/v1/masters/{table}`

เพิ่มแถวใหม่ในตาราง master

**Request body** (`MasterRowWriteRequest`) — เป็น JSON object แบบ dynamic ตาม schema ของแต่ละตาราง

```json
{
  "values": {
    "channel_id": 1,
    "product_code": "P001",
    "weight_pct": 0.5,
    "effective_from": "2026-01-01"
  }
}
```

**Response**: `{ "success": true, "data": { "id": 501 } }`

### 4.3 `PUT /api/v1/masters/{table}/{id}`

แก้ไขแถวตาม `id`

**Path parameter**: `id` (long)
**Request body**: รูปแบบเดียวกับ `POST` (`MasterRowWriteRequest`)

**Response**: `{ "success": true, "data": { "updatedRows": 1 } }`

### 4.4 `DELETE /api/v1/masters/{table}/{id}`

Deactivate แถว (soft delete — ตั้ง `is_active = 0` ไม่ได้ลบจริง)

**Response**: `{ "success": true, "data": { "updatedRows": 1 } }`

---

## 5. Channels — `/api/v1/channels`

Role ที่ต้องมี: **`ChannelAdmin`** หรือ **`Admin`**

### 5.1 `POST /api/v1/channels`

สร้าง channel ใหม่

**Request body** (`ChannelCreateRequest`)

```json
{
  "channelCode": "CH5",
  "channelNameTh": "ช่องทางที่ 5",
  "channelNameEn": "Channel 5",
  "calcType": "CASCADE_4_LEVEL"
}
```

`calcType` default = `"CASCADE_4_LEVEL"` ถ้าไม่ระบุ

**Response**: `{ "success": true, "data": { "channelId": 6 } }`

### 5.2 `POST /api/v1/channels/{channel}/formulas/clone-from/{sourceChannel}?setInactive={bool}`

Clone สูตรทั้งหมดจาก `{sourceChannel}` มาที่ `{channel}`

**Query parameter**: `setInactive` (bool, ไม่บังคับ) — ถ้า `true` สูตรที่ clone มาจะถูกตั้งเป็น inactive

**Response**: `{ "success": true, "data": { "clonedRows": 12 } }`

### 5.3 `POST /api/v1/channels/{channel}/masters/clone-from/{sourceChannel}`

Clone master data ทั้งหมดจาก `{sourceChannel}` มาที่ `{channel}`

**Response**: `{ "success": true, "data": { "clonedRows": 30 } }`

---

## 6. Sandbox — `/api/v1/calculation/sandbox`

Role ที่ต้องมี: **`SandboxRunner`** หรือ **`Admin`**

ใช้สำหรับทดลองคำนวณ (trial run) โดย**ไม่กระทบข้อมูล production**

### 6.1 `POST /api/v1/calculation/sandbox/run`

**Request body** (`SandboxRunRequest`)

```json
{
  "targetChannel": "CH5",
  "sourceTransactionChannel": "MT",
  "periodId": 1,
  "engine": "NCalc",
  "formulaSetRef": "draft",
  "persist": false,
  "wsType": null,
  "approvedBy": "your-name"
}
```

| ฟิลด์ | ประเภท | คำอธิบาย |
|---|---|---|
| `targetChannel` | string | channel ที่จะใช้สูตร/master ในการคำนวณ |
| `sourceTransactionChannel` | string | channel ที่ดึงข้อมูล transaction ต้นทางมาใช้ |
| `periodId` | int | ต้อง > 0 |
| `engine` | string | default = `"NCalc"` |
| `formulaSetRef` | string | default = `"draft"` — ใช้ระบุชุดสูตรที่ทดลอง |
| `persist` | bool | `false` = คำนวณแล้วคืนผลทันที ไม่บันทึกลง DB / `true` = บันทึกผลลง `sbx_calc_run`, `sbx_incentive_detail` (แยกจาก production เด็ดขาด) |
| `wsType` | string? | ใช้เมื่อ channel ต้นทางเป็น TT |
| `approvedBy` | string? | ผู้สั่งรัน sandbox |

**Response** (`SandboxRunResponse`)

```json
{
  "success": true,
  "data": {
    "sandboxRunId": 789,
    "rowCount": 45,
    "totalIncentive": 125000.50,
    "persisted": false
  }
}
```

### 6.2 `GET /api/v1/calculation/sandbox/{sandboxRunId}`

ดูรายละเอียดผลลัพธ์ของ sandbox run ตาม `sandboxRunId` (long) — ใช้ได้เฉพาะกรณีที่ `persist: true` ตอนรัน

### 6.3 `POST /api/v1/calculation/sandbox/compare`

เปรียบเทียบผลลัพธ์ sandbox กับผลลัพธ์จริง (baseline)

**Request body** (`SandboxCompareRequest`)

```json
{
  "sandboxRunId": 789,
  "baselineCalcRunId": 123
}
```

**Response** (`SandboxCompareResponse`)

```json
{
  "success": true,
  "data": {
    "sandboxTotal": 125000.50,
    "baselineTotal": 120000.00,
    "delta": 5000.50,
    "sandboxRows": 45,
    "baselineRows": 44
  }
}
```

---

## 7. สรุปตาราง Endpoint ทั้งหมด

| Method | Path | Role |
|---|---|---|
| GET | `/health` | ไม่ต้อง auth |
| POST | `/api/v1/calculation/{channel}/run` | CalcRunner, Admin |
| GET | `/api/v1/calculation/runs/{calcRunId}` | CalcRunner, Admin |
| GET | `/api/v1/calculation/{channel}/results` | CalcRunner, Admin |
| GET | `/api/v1/formulas` | FormulaEditor, Admin |
| GET | `/api/v1/formulas/{formulaCode}` | FormulaEditor, Admin |
| POST | `/api/v1/formulas` | FormulaEditor, Admin |
| PUT | `/api/v1/formulas/{formulaCode}` | FormulaEditor, Admin |
| POST | `/api/v1/formulas/{formulaCode}/activate` | FormulaEditor, Admin |
| POST | `/api/v1/formulas/{formulaCode}/deactivate` | FormulaEditor, Admin |
| POST | `/api/v1/formulas/validate` | FormulaEditor, Admin |
| GET | `/api/v1/masters/{table}` | MasterEditor, Admin |
| POST | `/api/v1/masters/{table}` | MasterEditor, Admin |
| PUT | `/api/v1/masters/{table}/{id}` | MasterEditor, Admin |
| DELETE | `/api/v1/masters/{table}/{id}` | MasterEditor, Admin |
| POST | `/api/v1/channels` | ChannelAdmin, Admin |
| POST | `/api/v1/channels/{channel}/formulas/clone-from/{sourceChannel}` | ChannelAdmin, Admin |
| POST | `/api/v1/channels/{channel}/masters/clone-from/{sourceChannel}` | ChannelAdmin, Admin |
| POST | `/api/v1/calculation/sandbox/run` | SandboxRunner, Admin |
| GET | `/api/v1/calculation/sandbox/{sandboxRunId}` | SandboxRunner, Admin |
| POST | `/api/v1/calculation/sandbox/compare` | SandboxRunner, Admin |

---

## ไฟล์ที่เกี่ยวข้อง

- Swagger UI usage guide: [`README.md`](README.md)
- Endpoint definitions ทั้งหมด: [`Program.cs`](Program.cs)
- Request/Response DTOs: [`Contracts/`](Contracts/)
- Authentication handler: [`Security/ApiKeyAuthenticationHandler.cs`](Security/ApiKeyAuthenticationHandler.cs)
- ชุดทดสอบอัตโนมัติ: [`../AjtIncentive.Api.Tests/README.md`](../AjtIncentive.Api.Tests/README.md)
- สคริปต์ regression ยิง API จริง: [`../../test-scenarios/regression-toolkit/api/README.md`](../../test-scenarios/regression-toolkit/api/README.md)
