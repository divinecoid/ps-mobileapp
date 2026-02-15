# Dokumentasi Update Fitur Order (Assignment)

Update ini menambahkan kemampuan bagi *preparist* untuk mengambil (*assign*) orderan ke diri sendiri dan melihat daftar orderan yang telah di-*assign*.

## 1. Assign Order to Me

Endpoint ini digunakan oleh user untuk mengambil tanggung jawab pemrosesan suatu order. Saat di-*assign*, `preparist_user_id` akan diisi ID user yang login, `read_at` akan diupdate, dan status order berubah menjadi `READ`.

- **URL**: `/api/outbound/assign-order`
- **Method**: `POST`
- **Auth**: Required (`checkrole`)

### Request Body

| Field      | Type | Required | Description |
|------------|------|----------|-------------|
| `order_id` | UUID | Yes      | ID Order (UUID) yang akan diambil. |

**Contoh Request:**
```json
{
    "order_id": "019b85c4-c21d-73b1-8e11-3521675892c6"
}
```

### Response

#### Sukses (`200 OK`)
```json
{
    "success": true,
    "message": "Order berhasil di-assign ke Anda",
    "data": {
        "id": "...",
        "awb_code": "...",
        "status": "read",
        "preparist_user_id": "..."
    }
}
```

#### Error (`400 Bad Request`)
Jika order sudah di-assign ke user lain.
```json
{
    "success": false,
    "message": "Order sudah di-assign ke user lain",
    "data": null
}
```

---

## 2. Daftar Order Saya (Assigned Orders)

Endpoint ini menampilkan daftar order yang telah di-*assign* ke user yang sedang login.

- **URL**: `/api/outbound/assigned-orders`
- **Method**: `GET`
- **Auth**: Required (`checkrole`)

### Query Parameters
Mendukung parameter yang sama dengan index order (pagination, filtering by marketplace, awb, dsb).

### Response

#### Sukses (`200 OK`)
```json
{
    "success": true,
    "message": "Success",
    "data": [
        {
            "id": "...",
            "awb_code": "...",
            "status": "read",
            "preparist_user_id": "..."
        }
    ],
    "meta": { ... pagination ... }
}
```

---

## 3. Unassign Order (Lempar Orderan)

Endpoint ini digunakan oleh user untuk melepas tanggung jawab suatu order yang sebelumnya telah di-*assign*. Saat di-unassign, `preparist_user_id` akan dikosongkan (`null`), `read_at` akan dikosongkan (`null`), dan status order kembali menjadi `PENDING`.

- **URL**: `/api/outbound/unassign-order`
- **Method**: `POST`
- **Auth**: Required (`checkrole`)

### Request Body

| Field      | Type | Required | Description |
|------------|------|----------|-------------|
| `order_id` | UUID | Yes      | ID Order (UUID) yang akan dilepas. |

### Response

#### Sukses (`200 OK`)
```json
{
    "success": true,
    "message": "Order berhasil dilepas",
    "data": {
        "id": "...",
        "status": "pending",
        "preparist_user_id": null
    }
}
```
