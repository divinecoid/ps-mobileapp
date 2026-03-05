import 'package:flutter/material.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import '../utils/printer_service.dart';
import '../components/app_drawer.dart';
import '../utils/navigation_helper.dart';

class BluetoothPairingScreen extends StatefulWidget {
  const BluetoothPairingScreen({super.key});

  @override
  State<BluetoothPairingScreen> createState() => _BluetoothPairingScreenState();
}

class _BluetoothPairingScreenState extends State<BluetoothPairingScreen> {
  final PrinterService _printerService = PrinterService();
  List<BluetoothDevice> _devices = [];
  BluetoothDevice? _selectedDevice;
  bool _isConnected = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initBluetooth();
  }

  Future<void> _initBluetooth() async {
    setState(() => _isLoading = true);
    final isConnected = await _printerService.isConnected();
    final devices = await _printerService.getDevices();
    
    setState(() {
      _devices = devices;
      _isConnected = isConnected;
      _isLoading = false;
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    setState(() => _isLoading = true);
    final success = await _printerService.connect(device);
    
    if (success) {
      setState(() {
        _selectedDevice = device;
        _isConnected = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Terhubung ke ${device.name}')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal terhubung ke printer'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _disconnect() async {
    setState(() => _isLoading = true);
    await _printerService.disconnect();
    setState(() {
      _isConnected = false;
      _selectedDevice = null;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Printer diputuskan')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pairing Printer Bluetooth'),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initBluetooth,
          ),
        ],
      ),
      drawer: AppDrawer(
        onMenuSelected: (menu) => NavigationHelper.handleMenuSelection(
          context,
          menu,
          currentScreen: 'bluetooth_printer',
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: _isConnected ? Colors.green.shade50 : Colors.orange.shade50,
                  child: Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.check_circle : Icons.warning,
                        color: _isConnected ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isConnected ? 'Status: Terhubung' : 'Status: Terputus',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if (_selectedDevice != null)
                              Text('Printer: ${_selectedDevice?.name}'),
                          ],
                        ),
                      ),
                      if (_isConnected)
                        ElevatedButton(
                          onPressed: _disconnect,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Putuskan'),
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Daftar Perangkat Terpasang (Bonded):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Expanded(
                  child: _devices.isEmpty
                      ? const Center(
                          child: Text('Tidak ada perangkat Bluetooth terpasang.\nSilakan pasangkan (pair) printer di Pengaturan Bluetooth HP Anda.'),
                        )
                      : ListView.builder(
                          itemCount: _devices.length,
                          itemBuilder: (context, index) {
                            final device = _devices[index];
                            return ListTile(
                              leading: const Icon(Icons.print),
                              title: Text(device.name ?? 'Unknown Device'),
                              subtitle: Text(device.address ?? ''),
                              trailing: ElevatedButton(
                                onPressed: _isConnected ? null : () => _connect(device),
                                child: const Text('Connect'),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
