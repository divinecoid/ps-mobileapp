# Dokumentasi Mutasi

Modul ini menangani proses mutasi barang di gudang, termasuk validasi *barcode* dan penyimpanan data mutasi.

## 1. Validasi Barcode (Scan)

Endpoint ini digunakan untuk memvalidasi *barcode* saat barang discan sebelum diproses lebih lanjut.

- **URL**: `/api/mutation/validate`
- **Method**: `POST`
- **Auth**: Required (`checkrole`)

### Request Body

| Field     | Type   | Required | Description                                      |
|-----------|--------|----------|--------------------------------------------------|
| `barcode` | String | Yes      | String *barcode* lengkap yang discan dari label. |

**Contoh Request:**
```json
{
    "barcode": "CMT01|20260214150001|LP|RED|XS|PIECE|6"
}
```

### Response

#### Sukses (`200 OK`)

```json
{
    "success": true,
    "message": "Success",
    "data": {
        "cmt": {
            "code": "CMT-001",
            "name": "Nama CMT",
            "contact_person": "Budi",
            "phone": "08123456789",
            "address": "Jl. Contoh No. 1"
        },
        "model": {
            "sku": "MODEL-123",
            "name": "Kemeja Lengan Panjang"
        },
        "color": {
            "code": "RED",
            "name": "Merah"
        },
        "size": {
            "code": "XS",
            "name": "Extra Small"
        }
    }
}
```

#### Error (`422 Unprocessable Entity`)

**Kemungkinan Pesan Error:**
- `"Barcode tidak valid"`
- `"Barcode bukan merupakan barcode piece"`
- `"Nomor urut barcode piece diluar jangkauan"`
- `"Barcode sudah discan"`

```json
{
    "success": false,
    "message": "Barcode sudah discan",
    "data": null
}
```

---

## 2. Simpan Mutasi (Submit)

Endpoint ini digunakan untuk menyimpan data mutasi setelah semua barang discan dan diletakkan di rak (*rack*).

- **URL**: `/api/mutation`
- **Method**: `POST`
- **Auth**: Required (`checkrole`)

### Request Body

Struktur data dikirim dalam bentuk *array of objects* di dalam properti `items`. Setiap objek mewakili satu rak dan daftar *barcode* yang diletakkan di rak tersebut.

| Field                | Type   | Required | Description                                                         |
|----------------------|--------|----------|---------------------------------------------------------------------|
| `items`              | Array  | Yes      | Daftar item mutasi per rak. Minimal 1 item.                         |
| `items[].rack_id`    | UUID   | Yes      | ID Rack tujuan penyimpanan. Harus valid dan unik dalam request.     |
| `items[].barcodes`   | Array  | Yes      | Daftar string *barcode* yang disimpan di rak tersebut. Minimal 1.   |
| `items[].barcodes[]` | String | Yes      | String *barcode*.                                                   |
| `notes`              | String | No       | Catatan tambahan (maks 1000 karakter).                              |

**Contoh Request:**
```json
{
    "items": [
        {
            "rack_id": "019b85c4-c219-71f9-a7f8-0a5add1c5446",
            "barcodes": [
                "CMT01|20260214150001|LP|RED|XS|PIECE|6",
                "CMT01|20260214150001|LP|RED|XS|PIECE|7",
                "CMT01|20260214150001|LP|RED|XS|PIECE|8"
            ]
        },
        {
            "rack_id": "019b85c4-c21d-73b1-8e11-3521675892c6",
            "barcodes": [
                "CMT01|20260214150001|LP|RED|XS|PIECE|9",
                "CMT01|20260214150001|LP|RED|XS|PIECE|10"
            ]
        }
    ]
}
```

### Response

#### Sukses (`200 OK`)

```json
{
    "success": true,
    "message": "Successfully processed 2 items",
    "data": {
        "total_scanned": 2
    }
}
```

#### Error (`422 Unprocessable Entity`)

Response akan menyertakan daftar *barcode* yang `invalid` (tidak ditemukan/salah format) dan `scanned` (sudah pernah discan sebelumnya).

**Contoh 1 (Sudah discan):**
```json
{
    "success": false,
    "message": "5 barcode tidak valid",
    "data": {
        "invalid": [],
        "scanned": [
            "CMT01|20260214150001|LP|RED|XS|PIECE|6",
            "CMT01|20260214150001|LP|RED|XS|PIECE|7",
            "CMT01|20260214150001|LP|RED|XS|PIECE|8",
            "CMT01|20260214150001|LP|RED|XS|PIECE|9",
            "CMT01|20260214150001|LP|RED|XS|PIECE|10"
        ]
    }
}
```

**Contoh 2 (Campuran):**
```json
{
    "success": false,
    "message": "3 barcode tidak valid",
    "data": {
        "invalid": [
            "CMT01|20260214150001|LP|RED|XS|PIECE|14",
            "CMT01|20260214150001|LP|RED|XS|PIECE|15"
        ],
        "scanned": [
            "CMT01|20260214150001|LP|RED|XS|PIECE|13"
        ]
    }
}
```
