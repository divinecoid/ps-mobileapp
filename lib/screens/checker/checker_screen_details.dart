part of '../checker_screen.dart';

class _DialogRow {
  const _DialogRow(this.label, this.value);
  final String label;
  final String value;
}

extension _CheckerScreenDialogsExtension on _CheckerScreenState {
  Future<void> _showOrderDetailsDialog(Map<String, dynamic> order) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      color: Colors.blue.shade700,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Order details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildDialogSection(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Order information',
                          rows: [
                            _DialogRow(
                              'Order SN',
                              order['order_sn']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'AWB Code',
                              order['awb_code']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'Store',
                              order['online_store']?['name']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'Marketplace',
                              order['marketplace']?['name']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'Item count',
                              (order['item_count'] ?? 0).toString(),
                            ),
                            _DialogRow(
                              'Unique items',
                              (order['unique_item_count'] ?? 0).toString(),
                            ),
                            _DialogRow(
                              'Total price',
                              formatIdrCurrency(order['total_price']),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildDialogSection(
                          icon: Icons.person_outline,
                          title: 'Customer information',
                          rows: [
                            _DialogRow(
                              'Customer',
                              order['customer_name']?.toString() ?? '-',
                            ),
                            _DialogRow(
                              'Phone',
                              order['customer_phone']?.toString() ?? '-',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _buildDialogSection(
                          icon: Icons.location_on_outlined,
                          title: 'Shipping address',
                          rows: [],
                          customChild: Text(
                            order['customer_address']?.toString() ?? '-',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDialogSection({
    required IconData icon,
    required String title,
    required List<_DialogRow> rows,
    Widget? customChild,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: Colors.blue.shade700),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (customChild != null) customChild,
          ...rows.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    r.value.trim().isEmpty ? '-' : r.value,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
