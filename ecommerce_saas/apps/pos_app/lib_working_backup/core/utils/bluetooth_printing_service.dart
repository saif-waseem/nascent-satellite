import 'dart:typed_data';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

class BluetoothPrinterService {
  Future<bool> connect(String macAddress) async {
    return await PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<bool> disconnect() async {
    return await PrintBluetoothThermal.disconnect;
  }

  Future<List<BluetoothInfo>> getPairedDevices() async {
    return await PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> isConnected() async {
    return await PrintBluetoothThermal.connectionStatus;
  }

  Future<bool> printCustomImage(Uint8List imageBytes, {PaperSize paperSize = PaperSize.mm80}) async {
    try {
      if (!await isConnected()) return false;
      
      final profile = await CapabilityProfile.load();
      final generator = Generator(paperSize, profile);
      List<int> bytes = [];

      // We use the pdf bytes converted to raster image from printing_service, 
      // but here we just need to decode it to an image.
      // Alternatively, the simplest way is to send raw bytes to PrintBluetoothThermal
      // if it's already generated.
      
      // For now, assume PrintBluetoothThermal can print raw ESC/POS bytes.
      return await PrintBluetoothThermal.writeBytes(imageBytes);
    } catch (e) {
      print("Bluetooth print error: $e");
      return false;
    }
  }
}

final bluetoothPrinterProvider = BluetoothPrinterService();
