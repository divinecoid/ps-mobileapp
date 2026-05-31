import 'package:flutter/material.dart';
import 'package:ps_mobileapp_main/components/loading.dart';
import 'package:ps_mobileapp_main/components/app_drawer.dart';
import 'package:ps_mobileapp_main/utils/navigation_helper.dart';
import 'package:ps_mobileapp_main/state/auth_provider.dart';
import 'package:provider/provider.dart';
import 'package:ps_mobileapp_main/components/toast.dart';
import 'package:ps_mobileapp_main/screens/login_screen.dart';
import 'package:fl_chart/fl_chart.dart';
import '../api/http_client.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreen();
}

class _DashboardScreen extends State<DashboardScreen> {
  bool _loading = false;
  String _selectedPeriod = 'Hari ini';
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();

  // Real data statistics
  final Map<String, dynamic> _stats = {
    'avgPreparationTime': 0.0,
    'totalPackages': 0,
    'totalItems': 0,
    'completedOrders': 0,
    'pendingOrders': 0,
    'todayPackages': 0,
    'todayItems': 0,
  };

  // Weekly data for charts
  final List<Map<String, dynamic>> _weeklyData = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchDashboardData();
    });
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agt', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateForApi(DateTime date) {
    return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _loading = true;
    });

    try {
      String periodParam = 'today';
      if (_selectedPeriod == 'Minggu ini') periodParam = 'this_week';
      if (_selectedPeriod == 'Bulan ini') periodParam = 'this_month';
      if (_selectedPeriod == 'Custom Tanggal') periodParam = 'custom';

      Map<String, dynamic> queryParams = {'period': periodParam};
      if (periodParam == 'custom' && _startDate != null && _endDate != null) {
        queryParams['start_date'] = _formatDateForApi(_startDate!);
        queryParams['end_date'] = _formatDateForApi(_endDate!);
      }

      final response = await ApiClient.dio.get(
        '/dashboard/stats',
        queryParameters: queryParams,
      );

      if (response.data != null && response.data['success'] == true) {
        final data = response.data['data'];
        setState(() {
          _stats['avgPreparationTime'] = data['avgPreparationTime'];
          _stats['totalPackages'] = data['totalPackages'];
          _stats['totalItems'] = data['totalItems'];
          _stats['completedOrders'] = data['completedOrders'];
          _stats['pendingOrders'] = data['pendingOrders'];
          _stats['todayPackages'] = data['todayPackages'];
          _stats['todayItems'] = data['todayItems'];

          if (data['weeklyData'] != null) {
            _weeklyData.clear();
            for (var item in data['weeklyData']) {
              _weeklyData.add({
                'day': item['day'],
                'packages': item['packages'],
                'items': item['items'],
              });
            }
          }
        });
      } else {
        if (mounted) Toast.show(context, "Gagal memuat data dashboard");
      }
    } catch (e) {
      print("Error fetching dashboard stats: $e");
      if (mounted) Toast.show(context, "Koneksi ke server gagal");
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _selectCustomDateRange() async {
    final initialRange = DateTimeRange(
      start: _startDate ?? DateTime.now(),
      end: _endDate ?? DateTime.now(),
    );

    final pickedRange = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'PILIH RENTANG TANGGAL',
      cancelText: 'BATAL',
      confirmText: 'PILIH',
      saveText: 'SIMPAN',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.grey.shade900,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade700,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
        _selectedPeriod = 'Custom Tanggal';
      });
      _fetchDashboardData();
    }
  }

  Future<void> _handleLogout() async {
    setState(() {
      _loading = true;
    });

    final auth = context.read<AuthProvider>();
    final success = await auth.logout();

    setState(() => _loading = false);

    if (success && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => LoginScreen()),
      );
    } else {
      if (mounted) Toast.show(context, "Logout gagal. Silakan coba lagi.");
    }
  }

  void _handleMenuSelection(String menu) {
    NavigationHelper.handleMenuSelection(context, menu, currentScreen: 'dashboard', usePush: true);
  }

  @override
  Widget build(BuildContext context) {
    return Loading(
      isLoading: _loading,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue.shade700,
          leading: Builder(
            builder: (context) => IconButton(
              icon: Icon(Icons.menu, color: Colors.white),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
          title: Text(
            'PREPARIST APP',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        drawer: AppDrawer(
          onMenuSelected: _handleMenuSelection,
        ),
        body: RefreshIndicator(
          onRefresh: _fetchDashboardData,
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Period Selector
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dashboard',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedPeriod,
                            underline: SizedBox(),
                            isDense: true,
                            items: ['Hari ini', 'Minggu ini', 'Bulan ini', 'Custom Tanggal']
                                .map((period) => DropdownMenuItem(
                                      value: period,
                                      child: Text(
                                        period,
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              if (value == 'Custom Tanggal') {
                                _selectCustomDateRange();
                              } else {
                                setState(() {
                                  _selectedPeriod = value!;
                                });
                                _fetchDashboardData();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    if (_selectedPeriod == 'Custom Tanggal' && _startDate != null && _endDate != null) ...[
                      SizedBox(height: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.date_range, size: 16, color: Colors.blue.shade700),
                            SizedBox(width: 6),
                            Text(
                              'Rentang: ${_formatDate(_startDate!)} - ${_formatDate(_endDate!)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 20),

                // Statistics Cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Rata-rata Waktu',
                        value: '${_stats['avgPreparationTime']}',
                        unit: 'menit',
                        icon: Icons.timer,
                        color: Colors.blue,
                        gradient: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Paket Disiapkan',
                        value: '${_stats['totalPackages']}',
                        unit: 'paket',
                        icon: Icons.inventory_2,
                        color: Colors.green,
                        gradient: [Colors.green.shade400, Colors.green.shade600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        title: 'Barang Disiapkan',
                        value: '${_stats['totalItems']}',
                        unit: 'barang',
                        icon: Icons.shopping_bag,
                        color: Colors.orange,
                        gradient: [Colors.orange.shade400, Colors.orange.shade600],
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildStatCard(
                        title: 'Order Selesai',
                        value: '${_stats['completedOrders']}',
                        unit: 'order',
                        icon: Icons.check_circle,
                        color: Colors.purple,
                        gradient: [Colors.purple.shade400, Colors.purple.shade600],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Today's Summary
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade50, Colors.blue.shade100],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTodayStat(
                        label: 'Paket Hari Ini',
                        value: '${_stats['todayPackages']}',
                        icon: Icons.local_shipping,
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: Colors.blue.shade300,
                      ),
                      _buildTodayStat(
                        label: 'Barang Hari Ini',
                        value: '${_stats['todayItems']}',
                        icon: Icons.inventory,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),

                // Charts Section
                Text(
                  'Statistik Mingguan',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                SizedBox(height: 12),

                // Line Chart - Packages Trend
                Container(
                  height: 200,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.trending_up, color: Colors.blue.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Trend Paket (7 Hari)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: LineChart(
                          LineChartData(
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < _weeklyData.length) {
                                      return Padding(
                                        padding: EdgeInsets.only(top: 8),
                                        child: Text(
                                          _weeklyData[value.toInt()]['day'],
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      );
                                    }
                                    return Text('');
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: _weeklyData.asMap().entries.map((entry) {
                                  return FlSpot(
                                    entry.key.toDouble(),
                                    entry.value['packages'].toDouble(),
                                  );
                                }).toList(),
                                isCurved: true,
                                color: Colors.blue.shade700,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                                belowBarData: BarAreaData(
                                  show: true,
                                  color: Colors.blue.shade50,
                                ),
                              ),
                            ],
                            minY: 0,
                            maxY: 35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Bar Chart - Items Comparison
                Container(
                  height: 200,
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.bar_chart, color: Colors.green.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Perbandingan Barang (7 Hari)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Expanded(
                        child: BarChart(
                          BarChartData(
                            gridData: FlGridData(show: false),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 40,
                                  getTitlesWidget: (value, meta) {
                                    return Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey[600],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              rightTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              topTitles: AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    if (value.toInt() >= 0 && value.toInt() < _weeklyData.length) {
                                      return Text(
                                        _weeklyData[value.toInt()]['day'],
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                      );
                                    }
                                    return Text('');
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            barGroups: _weeklyData.asMap().entries.map((entry) {
                              return BarChartGroupData(
                                x: entry.key,
                                barRods: [
                                  BarChartRodData(
                                    toY: entry.value['items'].toDouble(),
                                    color: Colors.green.shade400,
                                    width: 20,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                            maxY: 200,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16),

                // Order Status Card
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.assignment, color: Colors.orange.shade700, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Status Order',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusItem(
                              label: 'Selesai',
                              count: _stats['completedOrders'],
                              color: Colors.green,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusItem(
                              label: 'Pending',
                              count: _stats['pendingOrders'],
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
    required List<Color> gradient,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 24),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 4),
              Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTodayStat({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade900,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusItem({
    required String label,
    required int count,
    required MaterialColor color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color.shade700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
