# Inbound Receiving System

## Overview

The Inbound Receiving System memproses penerimaan barang dari CMT (Cut Make Trim) berdasarkan scanning barcode. System ini secara otomatis mengelompokkan item yang di-scan berdasarkan request asalnya dan mengupdate quantity yang telah diterima.

## Database Schema

### Tables

#### `trx_receivedlogs`
Header table untuk setiap penerimaan barang.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `request_id` | UUID | Foreign key ke `trx_requests` |
| `warehouse_id` | UUID | Foreign key ke `mdx_warehouses` |
| `user_id` | UUID | User yang melakukan receiving |
| `received_date` | TIMESTAMP | Tanggal penerimaan |
| `notes` | TEXT | Catatan tambahan (optional) |

#### `trx_receivedlog_details`
Detail items yang diterima.

| Column | Type | Description |
|--------|------|-------------|
| `id` | UUID | Primary key |
| `receivedlog_id` | UUID | Foreign key ke `trx_receivedlogs` |
| `request_detail_id` | UUID | Foreign key ke `trx_request_details` |
| `model_id` | UUID | Foreign key ke `mdx_product_models` |
| `color_id` | UUID | Foreign key ke `mdx_colors` |
| `size_id` | UUID | Foreign key ke `mdx_sizes` |
| `qty` | INTEGER | Quantity dalam pieces (12 untuk DOZEN, 1 untuk PIECE) |
| `barcode` | STRING | Barcode yang di-scan |

#### `trx_request_details` (Updated)
Setelah konsolidasi qty columns, tabel ini menggunakan:
- `req_qty` - Total requested quantity dalam pieces
- `rec_qty` - Total received quantity dalam pieces (diupdate saat inbound)

## Barcode Format

Barcode menggunakan format 7 segmen yang dipisahkan dengan pipe (`|`):

```
CMT_CODE|REQUEST_DATE|MODEL_SKU|COLOR_CODE|SIZE_CODE|TYPE|SEQUENCE
```

### Contoh Barcode

```
CMT01|20260108162535|LC|RED|L|DOZEN|1
CMT01|20260108162535|LC|RED|M|PIECE|2
```

### Segmen Barcode

1. **CMT_CODE**: Kode CMT (contoh: `CMT01`)
2. **REQUEST_DATE**: Tanggal request dalam format `YmdHis` (contoh: `20260108162535`)
3. **MODEL_SKU**: SKU model produk (contoh: `LC`)
4. **COLOR_CODE**: Kode warna (contoh: `RED`)
5. **SIZE_CODE**: Kode ukuran (contoh: `L`, `M`, `XL`)
6. **TYPE**: Tipe quantity - `DOZEN` atau `PIECE`
   - `DOZEN` = 12 pieces
   - `PIECE` = 1 piece
7. **SEQUENCE**: Nomor urut barcode

## API Endpoint

### Process Inbound Receiving

**POST** `/api/inbound`

#### Authentication
Requires JWT token dengan middleware `checkrole`.

#### Request Body

```json
{
  "barcodes": [
    "CMT01|20260108162535|LC|RED|L|DOZEN|1",
    "CMT01|20260108162535|LC|RED|M|PIECE|2",
    "CMT01|20260108162535|LC|BLUE|XL|DOZEN|3"
  ],
  "warehouse_id": "uuid-warehouse-id",
  "notes": "Received in good condition"
}
```

#### Request Validation

| Field | Type | Required | Rules |
|-------|------|----------|-------|
| `barcodes` | array | ✅ | Minimal 1 barcode |
| `barcodes.*` | string | ✅ | Format: 7 segments dengan separator `\|` |
| `warehouse_id` | UUID | ✅ | Must exist in `mdx_warehouses` |
| `notes` | string | ❌ | Max 1000 characters |

#### Success Response (200)

```json
{
  "success": true,
  "message": "Successfully processed 3 items from 1 request(s)",
  "data": {
    "summary": {
      "total_scanned": 3,
      "total_processed": 3,
      "total_failed": 0,
      "total_receivedlogs": 1
    },
    "receivedlogs": [
      {
        "id": "uuid-receivedlog-id",
        "request_id": "uuid-request-id",
        "cmt": "CMT01",
        "warehouse": "Main Warehouse",
        "received_date": "2026-01-16T04:33:16.000000Z",
        "items_count": 3,
        "items": [
          {
            "id": "uuid-detail-id",
            "model": "LC",
            "color": "RED",
            "size": "L",
            "type": "DOZEN",
            "qty": 12,
            "sequence": "1"
          },
          {
            "id": "uuid-detail-id-2",
            "model": "LC",
            "color": "RED",
            "size": "M",
            "type": "PIECE",
            "qty": 1,
            "sequence": "2"
          },
          {
            "id": "uuid-detail-id-3",
            "model": "LC",
            "color": "BLUE",
            "size": "XL",
            "type": "DOZEN",
            "qty": 12,
            "sequence": "3"
          }
        ]
      }
    ]
  },
  "errors": []
}
```

#### Partial Success Response (200)

Jika beberapa barcode berhasil dan beberapa gagal:

```json
{
  "success": true,
  "message": "Successfully processed 2 items from 1 request(s)",
  "data": {
    "summary": {
      "total_scanned": 3,
      "total_processed": 2,
      "total_failed": 1,
      "total_receivedlogs": 1
    },
    "receivedlogs": [...]
  },
  "errors": [
    {
      "barcode": "CMT01|20260108162535|INVALID|RED|L|DOZEN|1",
      "error": "Request detail not found for Model: INVALID, Color: RED, Size: L"
    }
  ]
}
```

#### Error Responses

##### Validation Error (422)
```json
{
  "success": false,
  "message": "Validation failed",
  "errors": {
    "barcodes": ["The barcodes field is required."],
    "warehouse_id": ["The selected warehouse id is invalid."]
  }
}
```

##### All Barcodes Failed (400)
```json
{
  "success": false,
  "message": "All barcodes failed to parse",
  "errors": [
    {
      "barcode": "INVALID_BARCODE",
      "index": 0,
      "error": "Invalid barcode format. Expected 7 parts separated by '|', got 1"
    }
  ]
}
```

##### Server Error (500)
```json
{
  "success": false,
  "message": "Failed to process inbound receiving",
  "error": "Database connection error"
}
```

## Processing Flow

### 1. Validation
- Validasi input request (barcodes, warehouse_id, notes)
- Parse setiap barcode ke dalam komponen

### 2. Grouping
Items di-scan dikelompokkan berdasarkan **CMT Code** dan **Request Date**:
```
CMT01|20260108 -> Group 1
CMT01|20260109 -> Group 2
CMT02|20260108 -> Group 3
```

### 3. Request Matching
Untuk setiap group:
- Cari CMT berdasarkan code
- Cari Request dengan kriteria:
  - `cmt_id` = CMT yang ditemukan
  - `created_at` (date) = Request date dari barcode
  - `status` = `OPEN`

### 4. Detail Processing
Untuk setiap barcode dalam group:
- Cari Request Detail yang match:
  - Model (berdasarkan SKU)
  - Color (berdasarkan code)
  - Size (berdasarkan code)
- Convert TYPE ke quantity:
  - `DOZEN` → 12 pieces
  - `PIECE` → 1 piece

### 5. Database Transaction
Dalam satu transaction:
- Create `trx_receivedlogs` header
- Create `trx_receivedlog_details` untuk setiap item
- Update `rec_qty` di `trx_request_details` dengan increment quantity

### 6. Response
Kembalikan summary dengan:
- Total scanned items
- Total successfully processed
- Total failed
- Detail receivedlogs yang dibuat
- List errors (jika ada)

## Error Handling

### Barcode Parse Errors
- Invalid format (bukan 7 segments)
- Missing segments
- Empty values

### Request Not Found
- CMT code tidak ditemukan
- Tidak ada request dengan date yang match
- Request sudah `CLOSED`

### Request Detail Not Found
- Model SKU tidak ditemukan
- Color code tidak match
- Size code tidak match
- Kombinasi model-color-size tidak ada di request

### Database Errors
- Rollback semua changes jika terjadi error
- Return 500 dengan error message

## Usage Examples

### cURL

```bash
curl -X POST http://localhost:8000/api/inbound \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{
    "barcodes": [
      "CMT01|20260108162535|LC|RED|L|DOZEN|1",
      "CMT01|20260108162535|LC|RED|M|PIECE|2"
    ],
    "warehouse_id": "9d7e1234-5678-90ab-cdef-1234567890ab",
    "notes": "Received in good condition"
  }'
```

### JavaScript (Fetch)

```javascript
const response = await fetch('http://localhost:8000/api/inbound', {
  method: 'POST',
  headers: {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${token}`
  },
  body: JSON.stringify({
    barcodes: [
      'CMT01|20260108162535|LC|RED|L|DOZEN|1',
      'CMT01|20260108162535|LC|RED|M|PIECE|2'
    ],
    warehouse_id: '9d7e1234-5678-90ab-cdef-1234567890ab',
    notes: 'Received in good condition'
  })
});

const data = await response.json();
console.log(data);
```

### PHP (Laravel HTTP Client)

```php
use Illuminate\Support\Facades\Http;

$response = Http::withToken($token)
    ->post('http://localhost:8000/api/inbound', [
        'barcodes' => [
            'CMT01|20260108162535|LC|RED|L|DOZEN|1',
            'CMT01|20260108162535|LC|RED|M|PIECE|2'
        ],
        'warehouse_id' => '9d7e1234-5678-90ab-cdef-1234567890ab',
        'notes' => 'Received in good condition'
    ]);

$data = $response->json();
```

## Business Rules

### 1. Request Status
- Hanya request dengan status `OPEN` yang bisa menerima inbound
- Request `CLOSED` akan di-skip dengan error

### 2. Quantity Calculation
- DOZEN = 12 pieces
- PIECE = 1 piece
- `rec_qty` di-increment untuk setiap item yang diterima

### 3. Duplicate Barcodes
- System tidak mencegah scanning barcode yang sama multiple kali
- Setiap scan akan menambah `rec_qty`
- **Recommendation**: Implement duplicate checking di frontend/scanner

### 4. Over-Receiving
- System tidak mencegah receiving lebih dari requested quantity
- `rec_qty` bisa melebihi `req_qty`
- **Recommendation**: Implement warning di frontend jika `rec_qty > req_qty`

## Integration Notes

### Frontend Integration
1. Scanner app harus generate barcode dengan format yang benar
2. Batch scanning: kumpulkan semua barcodes sebelum submit
3. Show progress untuk setiap scan
4. Display errors untuk barcode yang gagal
5. Allow retry untuk failed barcodes

### Inventory Update
- Saat ini system hanya mencatat receiving
- **Future**: Auto-update inventory levels saat receiving
- **Future**: Create stock movement records

### Notification
- **Future**: Notify CMT saat receiving complete
- **Future**: Alert jika ada discrepancy (over/under receiving)

## Related Endpoints

### Get Request Details
```
GET /api/request/{id}
```
Untuk cek request details sebelum/sesudah receiving.

### Get Request Barcode
```
GET /api/request/barcode/{id}
```
Untuk mendapatkan barcode details dari request.

## Troubleshooting

### Issue: "Request not found"
**Cause**: CMT code atau request date tidak match
**Solution**: 
- Verify barcode format
- Check if request exists dengan date yang benar
- Pastikan request status = `OPEN`

### Issue: "Request detail not found"
**Cause**: Model/Color/Size combination tidak ada di request
**Solution**:
- Verify master data (model SKU, color code, size code)
- Check if combination exists dalam request

### Issue: "Invalid barcode format"
**Cause**: Barcode tidak memiliki 7 segments
**Solution**:
- Check barcode generation logic
- Ensure all segments terisi dengan benar

## Version History

- **v1.0** (2026-01-14): Initial implementation dengan barcode scanning dan auto-grouping
