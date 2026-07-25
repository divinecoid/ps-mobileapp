/// Mengurai SKU teks menjadi daftar item individual.
///
/// Format: `[PAKET{N}-][LOGO{n}*]<SKU>[+<SKU_extra>]`
///
/// Contoh:
///   PAKET3-LOGO48*PANJANGPOLOS+OBLONGHITAM  → 3× PANJANGPOLOS (pakai logo) + 1× OBLONGHITAM
///   LOGO48*PANJANGPOLOS                     → 1× PANJANGPOLOS (pakai logo)
///   PAKET3-PANJANGPOLOS                     → 3× PANJANGPOLOS
class ParsedSku {
  final String sku;
  final String? logo;
  final String? warna;
  final String? ukuran;

  ParsedSku({
    required this.sku,
    this.logo,
    this.warna,
    this.ukuran,
  });
}

class SkuParser {
  /// Mengurai SKU teks menjadi daftar item individual.
  /// 
  /// [skuText]     - Teks SKU dari order
  /// [warnaString] - Warna dipisah "|" atau "=" (e.g. "Merah|Biru|Hitam"), urut sesuai jumlah paket
  /// [ukuran]      - Ukuran item (e.g. "M", "L", "XL")
  static List<ParsedSku> parseSku(
    String skuText, {
    String warnaString = '',
    String? ukuran,
  }) {
    final regex = RegExp(r'^(?:(PAKET(\d+))-)?(?:(.+?)\*)?([^+]+)(?:\+(.+))?$');
    final match = regex.firstMatch(skuText);

    if (match == null) return [];

    final jumlahStr = match.group(2);
    final jumlah = jumlahStr != null ? int.tryParse(jumlahStr) ?? 1 : 1;
    final logo = match.group(3);
    final sku = match.group(4) ?? '';
    final extra = match.group(5);

    final List<String> warna = warnaString.isNotEmpty
        ? warnaString.split(RegExp(r'[|=]'))
        : [];

    final List<ParsedSku> result = [];

    for (int i = 0; i < jumlah; i++) {
      String? itemWarna;
      if (i < warna.length) {
        itemWarna = warna[i];
      } else {
        itemWarna = 'Hitam';
      }
      result.add(ParsedSku(
        sku: sku,
        logo: logo,
        warna: itemWarna,
        ukuran: ukuran,
      ));
    }

    if (extra != null) {
      result.add(ParsedSku(
        sku: extra,
        logo: null,
        warna: null,
        ukuran: ukuran,
      ));
    }

    return result;
  }
}
