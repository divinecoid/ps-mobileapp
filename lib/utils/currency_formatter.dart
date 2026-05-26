String formatIdrCurrency(dynamic amount) {
  final numeric = amount is num
      ? amount.toDouble()
      : double.tryParse(amount?.toString() ?? '0') ?? 0;
  final formatted = numeric.round().toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (m) => '.',
  );
  return 'Rp $formatted';
}
