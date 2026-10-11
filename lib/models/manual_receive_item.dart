/// Kind of goods received WITHOUT a QR code (entered by quantity).
/// `apiValue` is what POST /inbound expects in `manual_items[].category`.
enum ManualCategory {
  returnedGood(
    'returned_good',
    'Kembali baik (belum dijahit)',
    'Mengurangi sisa permintaan. Tidak masuk stok, tidak digaji.',
  ),
  returnedDefect(
    'returned_defect',
    'Kembali cacat (belum dijahit)',
    'Mengurangi sisa permintaan. Dicatat cacat, tidak masuk stok, tidak digaji.',
  ),
  extra(
    'extra',
    'Barang lebih (terjahit, tanpa QR)',
    'Masuk stok gudang besar dan ikut digaji.',
  );

  const ManualCategory(this.apiValue, this.label, this.hint);

  final String apiValue;
  final String label;
  final String hint;
}

/// A request line (serial · CMT · model · color · size) that can receive goods.
class InboundRequestLine {
  final String id;
  final String label;
  final int reqQty;
  final int recQty;
  final int recBsQty;
  final int outstandingQty;

  InboundRequestLine({
    required this.id,
    required this.label,
    required this.reqQty,
    required this.recQty,
    required this.recBsQty,
    required this.outstandingQty,
  });

  factory InboundRequestLine.fromJson(Map<String, dynamic> json) {
    int n(dynamic v) => (v as num?)?.toInt() ?? 0;
    return InboundRequestLine(
      id: json['id'] as String,
      label: (json['label'] as String?) ?? '-',
      reqQty: n(json['req_qty']),
      recQty: n(json['rec_qty']),
      recBsQty: n(json['rec_bs_qty']),
      outstandingQty: n(json['outstanding_qty']),
    );
  }
}

/// One queued "tanpa QR" entry, sent as `manual_items[]` on submit.
class ManualReceiveItem {
  final InboundRequestLine line;
  final ManualCategory category;
  final int qty;

  ManualReceiveItem({
    required this.line,
    required this.category,
    required this.qty,
  });

  Map<String, dynamic> toJson() => {
    'request_detail_id': line.id,
    'category': category.apiValue,
    'qty': qty,
  };
}
