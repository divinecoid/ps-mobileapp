# Inbound API Documentation

Dokumentasi API untuk modul **Inbound Receiving** yang digunakan untuk proses penerimaan barang dari CMT.

---

## Base URL

```
/api/inbound
```

## Authentication

Semua endpoint memerlukan authentication header:

```
Authorization: Bearer {token}
```

---

## Endpoints

### 1. Get All Inbound (List)

Mengambil daftar semua data penerimaan barang.

**Endpoint:**
```
GET /api/inbound
```

**Response Success (200):**
```json
{
  "success": true,
  "data": [
    {
      "id": "uuid",
      "warehouse_id": "uuid",
      "warehouse": {
        "name": "Gudang Utama"
      },
      "user": {
        "name": "John Doe"
      },
      "received_date": "2026-01-24T10:30:00.000000Z",
      "notes": "Barang diterima dengan baik",
      "request": {
        "cmt": {
          "code": "CMT01",
          "name": "CMT Bandung",
          "contact_person": "Budi",
          "phone": "081234567890",
          "address": "Jl. Cihampelas No. 1"
        }
      },
      "details": [
        {
          "barcode": "CMT01|20260116172102|LP|RED|XS|1"
        }
      ]
    }
  ]
}
```

---

### 2. Get Inbound by ID

Mengambil detail penerimaan barang berdasarkan ID.

**Endpoint:**
```
GET /api/inbound/{id}
```

**Parameters:**
| Parameter | Type   | Required | Description                |
|-----------|--------|----------|----------------------------|
| id        | string | Yes      | UUID dari receivedlog      |

**Response Success (200):**
```json
{
  "success": true,
  "data": {
    "id": "uuid",
    "warehouse_id": "uuid",
    "warehouse": {
      "name": "Gudang Utama"
    },
    "user": {
      "name": "John Doe"
    },
    "received_date": "2026-01-24T10:30:00.000000Z",
    "notes": "Barang diterima dengan baik",
    "request": {
      "cmt": {
        "code": "CMT01",
        "name": "CMT Bandung",
        "contact_person": "Budi",
        "phone": "081234567890",
        "address": "Jl. Cihampelas No. 1"
      }
    },
    "details": [
      {
        "barcode": "CMT01|20260116172102|LP|RED|XS|1"
      }
    ]
  }
}
```

---

### 3. Validate Barcode

Memvalidasi barcode sebelum proses scan. Gunakan endpoint ini untuk mengecek apakah barcode valid sebelum menambahkan ke daftar scan.

**Endpoint:**
```
POST /api/inbound/validate
```

**Request Body:**
```json
{
  "barcode": "CMT01|20260116172102|LP|RED|XS|1|5"
}
```

**Request Parameters:**
| Field   | Type   | Required | Description           |
|---------|--------|----------|-----------------------|
| barcode | string | Yes      | Barcode yang akan divalidasi |

**Barcode Format:**
```
{CMT_CODE}|{TIMESTAMP}|{MODEL_SKU}|{COLOR_CODE}|{SIZE_CODE}|{GROUP}|{SEQUENCE}
```

| Segment      | Description                                          |
|--------------|------------------------------------------------------|
| CMT_CODE     | Kode CMT (misal: CMT01)                             |
| TIMESTAMP    | Timestamp pembuatan (format: YYYYMMDDHHmmss)        |
| MODEL_SKU    | SKU Model produk (misal: LP)                        |
| COLOR_CODE   | Kode warna (misal: RED)                             |
| SIZE_CODE    | Kode ukuran (misal: XS)                             |
| GROUP        | Nomor group (untuk dozen) atau kosong (untuk piece) |
| SEQUENCE     | Nomor urut dalam group (1-12 untuk dozen, 1-n untuk piece) |

**Contoh Barcode:**
- **Dozen:** `CMT01|20260116172102|LP|RED|XS|1|5` → Group 1, Sequence 5
- **Piece:** `CMT01|20260116172102|LP|RED|XS||3` → Piece ke-3 (tanpa group)

**Response Success (200):**
```json
{
  "success": true,
  "data": {
    "cmt": {
      "id": "uuid",
      "code": "CMT01",
      "name": "CMT Bandung"
    },
    "model": {
      "id": "uuid",
      "sku": "LP",
      "name": "Long Pants"
    },
    "color": {
      "id": "uuid",
      "code": "RED",
      "name": "Red"
    },
    "size": {
      "id": "uuid",
      "code": "XS",
      "name": "Extra Small"
    },
    "is_dozen": true
  }
}
```

**Response Error (422):**
```json
{
  "success": false,
  "message": "Barcode tidak valid"
}
```

**Possible Error Messages:**
| Message                                    | Description                                    |
|--------------------------------------------|------------------------------------------------|
| Barcode tidak valid                        | Barcode tidak ditemukan di database            |
| Nomor urut barcode piece diluar jangkauan  | Sequence piece melebihi sisa qty yang diminta  |
| Nomor urut barcode dozen diluar jangkauan  | Group/sequence dozen melebihi qty yang diminta |
| Barcode sudah discan                       | Barcode sudah pernah di-scan sebelumnya        |

---

### 4. Store Inbound (Submit Scan Results)

Menyimpan hasil scan barcode untuk penerimaan barang.

**Endpoint:**
```
POST /api/inbound
```

**Request Body:**
```json
{
  "warehouse_id": "019b85c4-c21c-7215-b374-47b05605d1b3",
  "barcodes_dozen": [
    "CMT01|20260116172102|LP|RED|XS|1|1",
    "CMT01|20260116172102|LP|RED|XS|1|2",
    "CMT01|20260116172102|LP|RED|XS|2|1"
  ],
  "barcodes_piece": [
    {
      "barcode": "CMT01|20260116172102|LP|RED|XS||1",
      "rack_id": "019b85c4-c219-71f9-a7f8-0a5add1c5446"
    },
    {
      "barcode": "CMT01|20260116172102|LP|RED|XS||2",
      "rack_id": "019b85c4-c219-71f9-a7f8-0a5add1c5446"
    }
  ],
  "notes": "Barang diterima dalam kondisi baik"
}
```

**Request Parameters:**
| Field                      | Type     | Required                          | Description                                  |
|----------------------------|----------|-----------------------------------|----------------------------------------------|
| warehouse_id               | string   | Required jika ada barcodes_dozen  | UUID gudang tujuan                           |
| barcodes_dozen             | array    | Required tanpa barcodes_piece     | Array barcode untuk penerimaan dozen         |
| barcodes_dozen.*           | string   | Yes                               | Barcode dalam format string                  |
| barcodes_piece             | array    | Required tanpa barcodes_dozen     | Array object untuk penerimaan piece          |
| barcodes_piece.*.barcode   | string   | Yes                               | Barcode piece                                |
| barcodes_piece.*.rack_id   | string   | Yes                               | UUID rak tempat menyimpan piece              |
| notes                      | string   | No                                | Catatan penerimaan (max 1000 karakter)       |

> **Note:** Minimal salah satu dari `barcodes_dozen` atau `barcodes_piece` harus diisi.

**Response Success (200):**
```json
{
  "success": true,
  "message": "Successfully processed 5 items",
  "data": {
    "total_scanned": 5
  }
}
```

**Response Error (422) - Invalid Barcodes:**
```json
{
  "success": false,
  "message": "3 barcode tidak valid",
  "data": {
    "invalid": {
      "barcodes_dozen": [
        "CMT01|20260116172102|LP|RED|XS|99|1"
      ],
      "barcodes_piece": [
        "CMT01|20260116172102|LP|RED|XS||99"
      ]
    },
    "scanned": {
      "barcodes_dozen": [
        "CMT01|20260116172102|LP|RED|XS|1|1"
      ],
      "barcode_piece": []
    }
  }
}
```

**Validation Rules:**
| Rule                            | Description                                                              |
|---------------------------------|--------------------------------------------------------------------------|
| Barcode must exist in database  | Barcode prefix harus terdaftar di request_details                        |
| Same request only               | Semua barcode harus berasal dari request yang sama                       |
| Dozen: group * 12 <= req_qty    | Total item dalam group tidak boleh melebihi qty yang diminta             |
| Dozen: sequence 1-12            | Sequence dalam group harus antara 1-12                                   |
| Piece: no group                 | Barcode piece tidak boleh memiliki group                                 |
| Piece: sequence <= remainder    | Sequence piece tidak boleh melebihi sisa dari pembagian req_qty / 12     |
| Not already scanned             | Barcode tidak boleh sudah pernah di-scan                                 |

---

## Flow Penggunaan (Mobile App)

### Alur Scan Barcode:

```
1. User membuka halaman scan inbound
   ↓
2. User scan barcode menggunakan kamera
   ↓
3. [VALIDASI 1] Hit API POST /api/inbound/validate dengan barcode
   → Validasi format barcode
   → Cek barcode terdaftar di database
   → Cek barcode belum pernah di-scan
   ↓
4. Jika valid → Tampilkan info produk (CMT, Model, Color, Size)
              → Tambahkan ke daftar scan lokal
   Jika error → Tampilkan pesan error, barcode tidak ditambahkan
   ↓
5. Untuk barcode piece → User pilih rak penyimpanan
   ↓
6. User lanjutkan scan barcode lainnya (ulangi step 2-5)
   ↓
7. Setelah selesai scan → User klik Submit
   ↓
8. [VALIDASI 2] Hit API POST /api/inbound dengan semua barcode
   → Validasi ulang semua barcode
   → Cek semua barcode dari request yang sama
   → Cek tidak ada yang sudah di-scan oleh user lain
   ↓
9. Jika success → Tampilkan pesan sukses, reset halaman
   Jika error → Tampilkan detail barcode yang invalid/sudah pernah scan
```

> **Catatan:** Validasi dilakukan 2 kali:
> - **Validasi 1 (Per Scan):** Untuk memberikan feedback langsung ke user setelah scan
> - **Validasi 2 (Submit):** Untuk memastikan konsistensi data dan mencegah race condition (misal: barcode yang sama di-scan oleh 2 user berbeda secara bersamaan)

### Perbedaan Dozen vs Piece:

| Aspect         | Dozen                                   | Piece                               |
|----------------|----------------------------------------|-------------------------------------|
| Barcode format | `...|{group}|{sequence}`               | `...||{sequence}` (group kosong)    |
| Qty per scan   | 12 pieces                              | 1 piece                             |
| Rack required  | No (disimpan di warehouse)             | Yes (harus pilih rak)               |
| Storage        | Tidak langsung jadi product            | Langsung dibuat record product      |

---

## Error Codes

| HTTP Code | Description                                          |
|-----------|------------------------------------------------------|
| 200       | Success                                              |
| 401       | Unauthorized - Token tidak valid atau expired        |
| 403       | Forbidden - Tidak memiliki akses                     |
| 404       | Not Found - Data tidak ditemukan                     |
| 422       | Unprocessable Entity - Validasi gagal                |
| 500       | Internal Server Error                                |

---

## Tips Implementasi Mobile

1. **Caching:** Cache hasil validasi barcode untuk menghindari hit API berulang untuk barcode yang sama.

2. **Offline Mode:** Simpan barcode yang sudah di-scan di local storage, validasi ulang saat online.

3. **Batch Validation:** Jika memungkinkan, kumpulkan beberapa barcode dan validasi sekaligus.

4. **Error Handling:** Selalu tampilkan pesan error yang jelas ke user, terutama untuk barcode yang sudah pernah di-scan.

5. **Rak Selection:** Untuk piece, siapkan dropdown/picker rak setelah barcode tervalidasi.
