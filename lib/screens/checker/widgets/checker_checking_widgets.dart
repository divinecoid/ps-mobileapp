import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class CheckerCheckingHeader extends StatelessWidget {
  const CheckerCheckingHeader({
    super.key,
    required this.orderSn,
    required this.customerAndMarketplace,
    required this.onBack,
    required this.onDetails,
    required this.isComplete,
    required this.scannedCount,
    required this.totalCount,
    required this.remaining,
    required this.progress,
  });

  final String orderSn;
  final String customerAndMarketplace;
  final VoidCallback onBack;
  final VoidCallback onDetails;

  final bool isComplete;
  final int scannedCount;
  final int totalCount;
  final int remaining;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0FB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.receipt_long_outlined,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      orderSn,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      customerAndMarketplace,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onBack,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                ),
                child: const Text('Back', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: onDetails,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  side: BorderSide(color: Colors.blue.shade200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text('Details', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isComplete
                  ? const Color(0xFFE8F5E9)
                  : const Color(0xFFF1F8E9),
              borderRadius: BorderRadius.circular(10),
            ),
            child: isComplete
                ? Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'All items scanned — $scannedCount / $totalCount',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2E7D32),
                            ),
                          ),
                          const SizedBox(height: 1),
                          const Text(
                            'Ready to approve',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF558B2F),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Scanned items',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          Text(
                            '$scannedCount / $totalCount',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(100),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 7,
                          backgroundColor: const Color(0xFFDCEDC8),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF558B2F),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$remaining more item${remaining == 1 ? '' : 's'} to scan',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF558B2F),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class CheckerApproveBar extends StatelessWidget {
  const CheckerApproveBar({
    super.key,
    required this.isSubmitting,
    required this.isFullScanMet,
    required this.scannedCount,
    required this.totalCount,
    required this.onApprove,
  });

  final bool isSubmitting;
  final bool isFullScanMet;
  final int scannedCount;
  final int totalCount;
  final VoidCallback onApprove;

  @override
  Widget build(BuildContext context) {
    final canApprove = !isSubmitting && isFullScanMet;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      child: SizedBox(
        width: double.infinity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: ElevatedButton(
            onPressed: canApprove ? onApprove : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canApprove
                  ? const Color(0xFF2E7D32)
                  : Colors.grey.shade200,
              foregroundColor: canApprove ? Colors.white : Colors.grey.shade400,
              disabledBackgroundColor: Colors.grey.shade200,
              disabledForegroundColor: Colors.grey.shade400,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (canApprove) ...[
                        const Icon(Icons.check_circle_outline, size: 18),
                        const SizedBox(width: 8),
                        const Text(
                          'Approve order',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Approve order — $scannedCount of $totalCount scanned',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class CheckerCheckingTabBar extends StatelessWidget {
  const CheckerCheckingTabBar({
    super.key,
    required this.controller,
    required this.scannedCount,
    required this.totalCount,
  });

  final TabController? controller;
  final int scannedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    return TabBar(
      controller: controller,
      labelColor: Colors.blue.shade700,
      unselectedLabelColor: Colors.grey.shade500,
      indicatorColor: Colors.blue.shade700,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      unselectedLabelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      tabs: [
        const Tab(icon: Icon(Icons.qr_code_scanner, size: 18), text: 'Scan'),
        Tab(
          icon: const Icon(Icons.list_alt, size: 18),
          text: 'Items ($scannedCount/$totalCount)',
        ),
      ],
    );
  }
}

class CheckerScanTab extends StatefulWidget {
  const CheckerScanTab({
    super.key,
    required this.controller,
    required this.onDetect,
    required this.torchEnabled,
    required this.onToggleTorch,
    required this.onFlipCamera,
    required this.onManualSubmit,
    this.lastDetected,
  });

  final MobileScannerController? controller;
  final void Function(BarcodeCapture capture) onDetect;
  final bool torchEnabled;
  final VoidCallback onToggleTorch;
  final VoidCallback onFlipCamera;
  final void Function(String barcode) onManualSubmit;
  final String? lastDetected;

  @override
  State<CheckerScanTab> createState() => _CheckerScanTabState();
}

class _CheckerScanTabState extends State<CheckerScanTab> {
  final TextEditingController _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _submitManual() {
    final code = _textController.text.trim();
    if (code.isNotEmpty) {
      widget.onManualSubmit(code);
      _textController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Square box sized for QR codes instead of a wide 1D barcode frame.
        final boxWidth = constraints.maxWidth * 0.72;
        final boxHeight = boxWidth;
        final left = (constraints.maxWidth - boxWidth) / 2;
        final top = (constraints.maxHeight - boxHeight) / 2 - 40; // shift up slightly to make room for text input
        final scanWindow = Rect.fromLTWH(left, top, boxWidth, boxHeight);

        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: MobileScanner(
                controller: widget.controller,
                onDetect: widget.onDetect,
                scanWindow: scanWindow,
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
                child: IconButton(
                  onPressed: widget.onToggleTorch,
                  icon: Icon(
                    widget.torchEnabled ? Icons.flash_on : Icons.flash_off,
                    color: widget.torchEnabled ? Colors.amberAccent : Colors.white,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(999),
                child: IconButton(
                  onPressed: widget.onFlipCamera,
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white),
                ),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: Container(
                width: boxWidth,
                height: boxHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.9),
                    width: 2,
                  ),
                ),
              ),
            ),
            // Floating Overlay Card at the bottom containing the input field
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.78),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 0.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.qr_code_2,
                          color: Color(0xFF1565C0),
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'QR Code Produk',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: TextField(
                        controller: _textController,
                        onSubmitted: (_) => _submitManual(),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Masukkan atau scan QR code produk',
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 13,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          border: InputBorder.none,
                          suffixIcon: IconButton(
                            icon: const Icon(
                              Icons.send,
                              color: Color(0xFF1565C0),
                              size: 18,
                            ),
                            onPressed: _submitManual,
                          ),
                        ),
                      ),
                    ),
                    if (widget.lastDetected != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Last read: ${widget.lastDetected}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class CheckerOrderItemsTab extends StatelessWidget {
  const CheckerOrderItemsTab({
    super.key,
    required this.orderItems,
    required this.scannedItems,
  });

  final List<dynamic> orderItems;
  final List<Map<String, dynamic>> scannedItems;

  int _scannedQtyForKey(String sku, String color, String size) {
    final normalizedColor = _normalizeColor(color);
    final count = scannedItems
        .where(
          (item) {
            final itemSku = item['sku']?.toString().toLowerCase() ?? '';
            final itemColor = _normalizeColor(item['color']?.toString() ?? '');
            final itemSize = item['size']?.toString().toLowerCase() ?? '';
            
            final matches = itemSku == sku.toLowerCase() &&
                itemColor == normalizedColor &&
                itemSize == size.toLowerCase();
            
            if (sku.toLowerCase() == 'polospendek') {
              print('DEBUG Widget: Checking scanned item: itemSku=$itemSku, itemColor=$itemColor (normalized from ${item['color']}), itemSize=$itemSize');
              print('DEBUG Widget: Against: sku=${sku.toLowerCase()}, color=$normalizedColor (normalized from $color), size=${size.toLowerCase()}');
              print('DEBUG Widget: Match result: $matches');
            }
            
            return matches;
          },
        )
        .length;
    
    if (sku.toLowerCase() == 'polospendek') {
      print('DEBUG Widget: Final scannedQty for POLOSPENDEK = $count');
    }
    
    return count;
  }

  /// Normalize color to handle both English and Indonesian names
  String _normalizeColor(String color) {
    final lowerColor = color.toLowerCase().trim();
    
    // Map both English and Indonesian to a common normalized form
    const colorMap = {
      'black': 'hitam',
      'hitam': 'hitam',
      'white': 'putih',
      'putih': 'putih',
      'red': 'merah',
      'merah': 'merah',
      'blue': 'biru',
      'biru': 'biru',
      'green': 'hijau',
      'hijau': 'hijau',
      'yellow': 'kuning',
      'kuning': 'kuning',
      'gray': 'abu-abu',
      'grey': 'abu-abu',
      'abu-abu': 'abu-abu',
      'brown': 'coklat',
      'coklat': 'coklat',
      'orange': 'oranye',
      'oranye': 'oranye',
      'purple': 'ungu',
      'ungu': 'ungu',
      'pink': 'pink',
    };
    
    return colorMap[lowerColor] ?? lowerColor;
  }

  List<_CheckerOrderItemSummary> _buildOrderItemSummaries() {
    final Map<String, _CheckerOrderItemSummary> groups = {};

    for (final raw in orderItems) {
      final item = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      final sku = item['sku']?.toString() ?? '';
      final color = item['color']?.toString() ?? '';
      final size = item['size']?.toString() ?? '';
      final itemName =
          item['item_name']?.toString() ?? item['name']?.toString() ?? '-';

      final key =
          '${sku.toLowerCase()}|${color.toLowerCase()}|${size.toLowerCase()}';
      final existing = groups[key];
      if (existing == null) {
        groups[key] = _CheckerOrderItemSummary(
          sku: sku,
          color: color,
          size: size,
          itemName: itemName,
          requiredQty: 1,
        );
      } else {
        groups[key] = existing.copyWith(requiredQty: existing.requiredQty + 1);
      }
    }

    final list = groups.values.toList();
    list.sort((a, b) {
      final byName = a.itemName.toLowerCase().compareTo(
        b.itemName.toLowerCase(),
      );
      if (byName != 0) return byName;
      return a.sku.toLowerCase().compareTo(b.sku.toLowerCase());
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    if (orderItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(
              'No items found for this order',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
            ),
          ],
        ),
      );
    }

    final summaries = _buildOrderItemSummaries();

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: summaries.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: Colors.grey.shade100),
      itemBuilder: (context, index) {
        final summary = summaries[index];
        final scannedQty = _scannedQtyForKey(
          summary.sku,
          summary.color,
          summary.size,
        );
        final isComplete = scannedQty >= summary.requiredQty;

        final chipBg = isComplete
            ? const Color(0xFFEAF3DE)
            : const Color(0xFFE6F1FB);
        final chipFg = isComplete
            ? const Color(0xFF3B6D11)
            : const Color(0xFF185FA5);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isComplete
                      ? const Color(0xFFEAF3DE)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isComplete ? Icons.check : Icons.inventory_2_outlined,
                  color: isComplete
                      ? const Color(0xFF3B6D11)
                      : Colors.grey.shade600,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.itemName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.sku} · ${summary.color} · ${summary.size}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$scannedQty/${summary.requiredQty}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: chipFg,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CheckerOrderItemSummary {
  const _CheckerOrderItemSummary({
    required this.sku,
    required this.color,
    required this.size,
    required this.itemName,
    required this.requiredQty,
  });

  final String sku;
  final String color;
  final String size;
  final String itemName;
  final int requiredQty;

  _CheckerOrderItemSummary copyWith({
    String? sku,
    String? color,
    String? size,
    String? itemName,
    int? requiredQty,
  }) {
    return _CheckerOrderItemSummary(
      sku: sku ?? this.sku,
      color: color ?? this.color,
      size: size ?? this.size,
      itemName: itemName ?? this.itemName,
      requiredQty: requiredQty ?? this.requiredQty,
    );
  }
}
