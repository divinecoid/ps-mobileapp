import 'dart:convert';
import 'dart:typed_data';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  final BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;

  Future<List<BluetoothDevice>> getDevices() async {
    try {
      return await bluetooth.getBondedDevices();
    } catch (e) {
      print('Error getting bluetooth devices: $e');
      return [];
    }
  }

  Future<bool> connect(BluetoothDevice device) async {
    try {
      bool? isConnected = await bluetooth.isConnected;
      if (isConnected == true) return true;
      
      await bluetooth.connect(device);
      return true;
    } catch (e) {
      print('Error connecting to printer: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await bluetooth.disconnect();
    } catch (e) {
      print('Error disconnecting: $e');
    }
  }

  Future<bool> isConnected() async {
    try {
      bool? connected = await bluetooth.isConnected;
      return connected ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> printBarcode(String barcodeString, {String? model, String? color, String? size}) async {
    if (!(await isConnected())) return;

    try {
      final profile = await CapabilityProfile.load();
      final generator = Generator(PaperSize.mm58, profile);
      List<int> bytes = [];

      // Header
      bytes += generator.feed(1);
      bytes += generator.text("PS KO ACI", 
          styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
      
      // Product Details
      if (model != null) {
        bytes += generator.text(model, styles: const PosStyles(align: PosAlign.center));
      }
      
      String variant = "";
      if (color != null) variant += color;
      if (size != null) variant += (variant.isNotEmpty ? " - " : "") + size;
      
      if (variant.isNotEmpty) {
        bytes += generator.text(variant, styles: const PosStyles(align: PosAlign.center));
      }
      
      bytes += generator.feed(1);
      
      // Print Barcode (CODE 128)
      // Use utf8.encode to convert String to List<int>
      // width: 2 is normally the standard/low width for many printers
      bytes += generator.barcode(Barcode.code128(utf8.encode(barcodeString)), height: 80, width: 2);
      
      // Print Barcode Text below
      bytes += generator.text(barcodeString, styles: const PosStyles(align: PosAlign.center));
      
      // Footer/Spacing
      bytes += generator.feed(3);
      bytes += generator.cut();

      await bluetooth.writeBytes(Uint8List.fromList(bytes));
    } catch (e) {
      print('Error printing barcode: $e');
    }
  }

  Future<void> printBatch(List<Map<String, String>> items) async {
    if (!(await isConnected())) return;
    
    for (var item in items) {
      await printBarcode(
        item['barcode'] ?? '',
        model: item['model'],
        color: item['color'],
        size: item['size'],
      );
      // Short delay between prints to avoid buffer overflow if needed
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }
}
