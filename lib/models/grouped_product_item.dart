class GroupedProductItem {
  final String sku;
  final String color;
  final String size;
  final String displayName; // e.g., "LP - RED - 2XL"
  final int requiredQuantity;
  final List<String> scannedBarcodes;
  final List<String> orderItemIds; // Store backend IDs for each item in this group
  final bool isComplete;

  GroupedProductItem({
    required this.sku,
    required this.color,
    required this.size,
    required this.displayName,
    required this.requiredQuantity,
    required this.scannedBarcodes,
    required this.orderItemIds,
    required this.isComplete,
  });

  // Create a copy with updated values
  GroupedProductItem copyWith({
    String? sku,
    String? color,
    String? size,
    String? displayName,
    int? requiredQuantity,
    List<String>? scannedBarcodes,
    List<String>? orderItemIds,
    bool? isComplete,
  }) {
    return GroupedProductItem(
      sku: sku ?? this.sku,
      color: color ?? this.color,
      size: size ?? this.size,
      displayName: displayName ?? this.displayName,
      requiredQuantity: requiredQuantity ?? this.requiredQuantity,
      scannedBarcodes: scannedBarcodes ?? this.scannedBarcodes,
      orderItemIds: orderItemIds ?? this.orderItemIds,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  // Check if the group is complete
  bool get isGroupComplete => scannedBarcodes.length == requiredQuantity;

  // Get current scanned count
  int get scannedCount => scannedBarcodes.length;
}
