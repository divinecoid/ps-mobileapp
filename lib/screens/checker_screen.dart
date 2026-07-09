import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/checker_service.dart';
import '../components/app_drawer.dart';
import '../components/toast.dart';
import '../utils/currency_formatter.dart';
import '../utils/navigation_helper.dart';

import 'checker/widgets/checker_checking_widgets.dart';
import 'checker/widgets/checker_list_widgets.dart';

part 'checker/checker_screen_list_view.dart';
part 'checker/checker_screen_checking_view.dart';
part 'checker/checker_screen_details.dart';

class CheckerScreen extends StatefulWidget {
  const CheckerScreen({super.key});

  @override
  State<CheckerScreen> createState() => _CheckerScreenState();
}

class _CheckerScreenState extends State<CheckerScreen>
    with SingleTickerProviderStateMixin {
  final List<dynamic> _assignedOrders = [];
  List<dynamic> _orderItems = [];
  final List<Map<String, dynamic>> _scannedItems = [];
  final List<String> _scannedBarcodes = [];

  int _assignedCount = 0;
  int _pendingCount = 0;

  bool _isLoading = false;
  bool _isListLoading = false;
  bool _isSubmitting = false;
  bool _isProcessingScan = false;
  bool _torchEnabled = false;
  String _errorMessage = '';
  String? _lastDetected;

  String? _selectedOrderId;
  Map<String, dynamic>? _selectedOrder;

  int _currentPage = 1;
  int _totalPages = 1;
  static const int _perPage = 15;

  // In-memory pagination cache (per query+filter)
  final Map<String, Map<int, List<dynamic>>> _ordersPageCache = {};
  final Map<String, int> _ordersTotalPagesCache = {};

  // Marketplace filter
  String? _selectedMarketplaceId;
  List<Map<String, dynamic>> _availableMarketplaces = [];

  // Search filter
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  TabController? _tabController;
  MobileScannerController? _scannerController;

  @override
  void initState() {
    super.initState();
    _loadAssignedOrders();
    // Pre-allocate tab controller to prevent null crashes during async loading
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _scannerController?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _updateState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  bool get _isFilterActive {
    final hasSearch = _searchQuery.trim().isNotEmpty;
    final hasMarketplace = (_selectedMarketplaceId ?? '').trim().isNotEmpty;
    return hasSearch || hasMarketplace;
  }

  String _buildOrdersCacheKey({
    required String searchQuery,
    required String? marketplaceId,
    required int perPage,
  }) {
    final normalizedSearch = searchQuery.trim().toLowerCase();
    final normalizedMarketplaceId = (marketplaceId ?? '').trim();
    return 'q=$normalizedSearch|m=$normalizedMarketplaceId|pp=$perPage';
  }

  String _currentOrdersCacheKey() {
    return _buildOrdersCacheKey(
      searchQuery: _searchQuery,
      marketplaceId: _selectedMarketplaceId,
      perPage: _perPage,
    );
  }

  Future<void> _refreshOrdersForCurrentQuery() async {
    final key = _currentOrdersCacheKey();
    _ordersPageCache.remove(key);
    _ordersTotalPagesCache.remove(key);
    if (mounted) {
      setState(() {
        _currentPage = 1;
      });
    }
    await _loadOrdersPage(page: 1, forceRefresh: true);
  }

  Future<void> _loadOrdersPage({
    required int page,
    bool forceRefresh = false,
  }) async {
    if (!mounted) return;

    final key = _currentOrdersCacheKey();
    final cachedPagesForKey = _ordersPageCache[key];
    final cachedPage = (!forceRefresh && cachedPagesForKey != null)
        ? cachedPagesForKey[page]
        : null;
    final cachedTotalPages = (!forceRefresh)
        ? _ordersTotalPagesCache[key]
        : null;

    if (cachedPage != null) {
      setState(() {
        _currentPage = page;
        _assignedOrders
          ..clear()
          ..addAll(cachedPage);
        if (cachedTotalPages != null) {
          _totalPages = cachedTotalPages;
        }
        _errorMessage = '';
        _isListLoading = false;
      });
      _extractAvailableMarketplaces();
      return;
    }

    setState(() {
      _currentPage = page;
      _assignedOrders.clear();
      _isListLoading = true;
      _errorMessage = '';
    });

    try {
      final response = _isFilterActive
          ? await CheckerService.searchOrders(
              search: _searchQuery,
              marketplaceId: _selectedMarketplaceId,
              page: _currentPage,
              perPage: _perPage,
            )
          : await CheckerService.getAssignedOrders(
              page: _currentPage,
              perPage: _perPage,
            );

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        final items = List<dynamic>.from((data['data'] as List?) ?? const []);
        final totalPages = (data['last_page'] as num?)?.toInt() ?? 1;

        _ordersPageCache.putIfAbsent(key, () => {})[_currentPage] = items;
        _ordersTotalPagesCache[key] = totalPages;

        setState(() {
          _assignedOrders
            ..clear()
            ..addAll(items);
          _totalPages = totalPages;

          if (!_isFilterActive) {
            _assignedCount =
                (data['total'] as num?)?.toInt() ?? _assignedOrders.length;
            _pendingCount = (data['pending'] as num?)?.toInt() ?? 0;
          }

          _extractAvailableMarketplaces();
          _isListLoading = false;
        });
      } else {
        setState(() {
          _errorMessage =
              response['message'] ?? 'Failed to load checker orders';
          _isListLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $error';
        _isListLoading = false;
      });
    }
  }

  void _handleMenuSelection(String menu) {
    NavigationHelper.handleMenuSelection(
      context,
      menu,
      currentScreen: 'checker',
    );
  }

  Future<void> _loadAssignedOrders() async {
    await _loadOrdersPage(page: _currentPage);
  }

  void _extractAvailableMarketplaces() {
    final marketplaceMap = <String, Map<String, dynamic>>{};

    for (final order in _assignedOrders) {
      final marketplace = order['marketplace'] as Map<String, dynamic>?;
      if (marketplace != null) {
        final id = marketplace['id']?.toString() ?? '';
        final name = marketplace['name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          marketplaceMap[id] = {'id': id, 'name': name};
        }
      }
    }

    _availableMarketplaces = marketplaceMap.values.toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));
  }

  List<dynamic> _getFilteredOrders() {
    return _assignedOrders;
  }

  Future<void> _performSearch() async {
    if (!mounted) return;

    // If search is empty and no marketplace filter, load all assigned orders
    if (!_isFilterActive) {
      _currentPage = 1;
    }

    await _loadOrdersPage(page: _currentPage);
  }

  Future<void> _openOrderForChecking(Map<String, dynamic> order) async {
    if (!mounted) return;

    setState(() {
      _selectedOrder = order;
      _selectedOrderId = order['id']?.toString();
      _isLoading = true;
      _errorMessage = '';
      _orderItems = [];
      _scannedItems.clear();
      _scannedBarcodes.clear();
    });

    try {
      final response = await CheckerService.getOrderItems(_selectedOrderId!);

      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        final data = response['data'] as Map<String, dynamic>;
        setState(() {
          _orderItems = List<dynamic>.from(data['items'] ?? []);
          _isLoading = false;
        });
        // Default to the items list tab so the checker can immediately see
        // what's inside the order after selecting it.
        _tabController?.index = 1;
        _initializeScanner();
      } else {
        setState(() {
          _errorMessage = response['message'] ?? 'Failed to load order items';
          _isLoading = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $error';
        _isLoading = false;
      });
    }
  }

  Future<void> _scanSerialAndOpenOrder() async {
    final scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      cameraResolution: const Size(1920, 1080),
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.itf,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );

    var torchEnabled = false;
    var isProcessingScan = false;

    try {
      await scannerController.start();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) {
          return Dialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: double.infinity,
              height: 520,
              child: StatefulBuilder(
                builder: (ctx, setDialogState) {
                  Future<void> handleDetect(BarcodeCapture capture) async {
                    if (isProcessingScan) return;

                    final serial = capture.barcodes.firstOrNull?.rawValue
                        ?.trim();
                    if (serial == null || serial.isEmpty) return;

                    isProcessingScan = true;
                    try {
                      final response = await CheckerService.getOrderBySerial(
                        serial,
                      );

                      if (!mounted) return;

                      if (response['success'] == true &&
                          response['data'] != null) {
                        final order = Map<String, dynamic>.from(
                          response['data'] as Map,
                        );
                        if (Navigator.of(dialogContext).canPop()) {
                          Navigator.of(dialogContext).pop();
                        }
                        await _openOrderForChecking(order);
                        return;
                      }

                      Toast.show(
                        context,
                        response['message']?.toString() ??
                            'Serial number tidak ditemukan',
                        isError: true,
                      );
                    } catch (error) {
                      if (!mounted) return;
                      Toast.show(context, 'Error: $error', isError: true);
                    } finally {
                      isProcessingScan = false;
                    }
                  }

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: Colors.black,
                        child: MobileScanner(
                          controller: scannerController,
                          onDetect: handleDetect,
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                          child: IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Material(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(999),
                          child: IconButton(
                            onPressed: () {
                              scannerController.toggleTorch();
                              setDialogState(() {
                                torchEnabled = !torchEnabled;
                              });
                            },
                            icon: Icon(
                              torchEnabled ? Icons.flash_on : Icons.flash_off,
                              color: torchEnabled
                                  ? Colors.amberAccent
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.9),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        right: 20,
                        bottom: 22,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Scan order barcode',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Point the camera at the barcode to open the order automatically',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      );
    } finally {
      await scannerController.stop();
      scannerController.dispose();
    }
  }

  void _initializeScanner() {
    _scannerController?.dispose();

    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      cameraResolution: const Size(1920, 1080),
      formats: const [
        BarcodeFormat.code128,
        BarcodeFormat.code39,
        BarcodeFormat.code93,
        BarcodeFormat.codabar,
        BarcodeFormat.ean13,
        BarcodeFormat.ean8,
        BarcodeFormat.itf,
        BarcodeFormat.upcA,
        BarcodeFormat.upcE,
      ],
    );
  }

  void _toggleTorch() {
    _scannerController?.toggleTorch();
    setState(() => _torchEnabled = !_torchEnabled);
  }

  void _flipCamera() {
    _scannerController?.switchCamera();
  }

  String? _extractSequence(String barcode) {
    final parts = barcode.split('|');
    if (parts.length == 7) return '${parts[5]}-${parts[6]}';
    final regex = RegExp(r'[-_]?(\d{2,})$');
    final match = regex.firstMatch(barcode);
    return match?.group(1);
  }

  bool _isSequenceUnique(String sku, String sequence) {
    return !_scannedItems.any(
      (item) => item['sku'] == sku && item['sequence'] == sequence,
    );
  }

  int _requiredQtyForKey(String sku, String color, String size) {
    return _orderItems
        .where(
          (item) =>
              (item['sku']?.toString().toLowerCase() ?? '') ==
                  sku.toLowerCase() &&
              (item['color']?.toString().toLowerCase() ?? '') ==
                  color.toLowerCase() &&
              (item['size']?.toString().toLowerCase() ?? '') ==
                  size.toLowerCase(),
        )
        .length;
  }

  int _scannedQtyForKey(String sku, String color, String size) {
    return _scannedItems
        .where(
          (item) =>
              (item['sku']?.toString().toLowerCase() ?? '') ==
                  sku.toLowerCase() &&
              (item['color']?.toString().toLowerCase() ?? '') ==
                  color.toLowerCase() &&
              (item['size']?.toString().toLowerCase() ?? '') ==
                  size.toLowerCase(),
        )
        .length;
  }

  Future<void> _handleBarcodeDetect(BarcodeCapture capture) async {
  if (_isProcessingScan ||
      _tabController?.index != 0 ||
      _selectedOrderId == null)
    return;

  final code = capture.barcodes.firstOrNull?.rawValue;
  if (code == null || code.isEmpty) return;

  setState(() => _lastDetected = code); // NEW: shows what was actually decoded

  _isProcessingScan = true;

    try {
      final response = await CheckerService.validateProductBarcode(
        orderId: _selectedOrderId!,
        barcode: code,
      );

      if (!mounted) return;

      if (response['success'] != true || response['data'] == null) {
        Toast.show(
          context,
          response['message']?.toString() ?? 'Barcode tidak valid',
          isError: true,
        );
        return;
      }

      final data = Map<String, dynamic>.from(response['data']);
      final sequence = _extractSequence(code);
      if (sequence == null) {
        Toast.show(
          context,
          response['message']?.toString() ?? 'Barcode not found or invalid',
          isError: true,
        );
        return;
      }
      final sku = data['sku']?.toString() ?? '';
      final color = data['color']?.toString() ?? '';
      final size = data['size']?.toString() ?? '';
      final itemName = data['item_name']?.toString() ?? '-';

      if (!_isSequenceUnique(sku, sequence)) {
        Toast.show(
          context,
          'Sequence $sequence sudah pernah di-scan untuk $sku',
          isError: true,
        );
        return;
      }

      final requiredQty = _requiredQtyForKey(sku, color, size);
      final scannedQty = _scannedQtyForKey(sku, color, size);

      if (requiredQty == 0) {
        Toast.show(
          context,
          'Produk tidak ditemukan di order ini',
          isError: true,
        );
        return;
      }

      if (scannedQty >= requiredQty) {
        Toast.show(
          context,
          'Qty maksimum untuk $sku sudah tercapai ($requiredQty)',
          isError: true,
        );
        return;
      }

      setState(() {
        _scannedBarcodes.add(code);
        _scannedItems.add({
          'sku': sku,
          'color': color,
          'size': size,
          'item_name': itemName,
          'sequence': sequence,
          'barcode': code,
          'scanned_at': DateTime.now().toIso8601String(),
        });
      });

      Toast.show(context, '$itemName berhasil di-scan');
      _tabController?.animateTo(1);
    } finally {
      _isProcessingScan = false;
    }
  }

  Future<void> _approveOrder() async {
    if (_selectedOrderId == null) return;

    if (_orderItems.isEmpty) {
      Toast.show(
        context,
        'Order tidak memiliki item untuk dicek',
        isError: true,
      );
      return;
    }

    if (_scannedItems.length != _orderItems.length) {
      Toast.show(
        context,
        'Scan belum lengkap (${_scannedItems.length}/${_orderItems.length})',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });

    try {
      final response = await CheckerService.approveOrderWithScans(
        _selectedOrderId!,
        List<String>.from(_scannedBarcodes),
      );

      if (!mounted) return;

      if (response['success'] == true) {
        Toast.show(context, 'Order berhasil di-approve');
        _backToListAndRefresh();
      } else {
        setState(() {
          _errorMessage =
              response['message']?.toString() ?? 'Gagal approve order';
          _isSubmitting = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error: $error';
        _isSubmitting = false;
      });
    }
  }

  void _backToListAndRefresh() {
    _scannerController?.dispose();
    _scannerController = null;
    _tabController?.index = 0;

    setState(() {
      _selectedOrder = null;
      _selectedOrderId = null;
      _orderItems = [];
      _scannedItems.clear();
      _scannedBarcodes.clear();
      _isSubmitting = false;
      _torchEnabled = false;
    });

    _refreshOrdersForCurrentQuery();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        elevation: 0,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: const Text(
          'ORDER CHECKER',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      drawer: AppDrawer(onMenuSelected: _handleMenuSelection),
      body: SafeArea(
        bottom: true,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _selectedOrderId == null
            ? _buildOrderListView()
            : _buildCheckingView(),
      ),
    );
  }
}
