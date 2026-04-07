import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final Function(String) onDetect;

  const BarcodeScannerWidget({super.key, required this.onDetect});

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _isCameraActive = false; // Start with camera off to save resources / avoid ugly prompts initially
  MobileScannerController? _scannerController;
  final TextEditingController _usbController = TextEditingController();
  final FocusNode _usbFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _usbFocusNode.requestFocus();
    // Do not initialize camera instantly to keep it lightweight. User can toggle it on.
    _scannerController = MobileScannerController(
      formats: const [BarcodeFormat.all],
    );
  }

  void _initScanner() {
    if (_isCameraActive) {
      _scannerController = MobileScannerController(
        formats: const [BarcodeFormat.all],
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scannerController?.dispose();
    _usbController.dispose();
    _usbFocusNode.dispose();
    super.dispose();
  }

  void _toggleCamera() {
    setState(() {
      _isCameraActive = !_isCameraActive;
      if (_isCameraActive) {
        _initScanner();
      } else {
        _scannerController?.dispose();
        _scannerController = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Configuration row for camera toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.camera_alt_outlined, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Text('تشغيل الكاميرا', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
                ],
              ),
              Switch(
                value: _isCameraActive,
                onChanged: (_) => _toggleCamera(),
                activeColor: Colors.blue.shade600,
              ),
            ],
          ),
        ),
        
        // Camera Preview window (Collapsible)
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: _isCameraActive ? 220 : 0,
          margin: EdgeInsets.only(top: _isCameraActive ? 12 : 0),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          clipBehavior: Clip.antiAlias,
          child: _isCameraActive
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      key: ValueKey(_scannerController.hashCode),
                      controller: _scannerController!,
                      onDetect: (capture) {
                        final List<Barcode> barcodes = capture.barcodes;
                        for (final barcode in barcodes) {
                          if (barcode.rawValue != null) {
                            widget.onDetect(barcode.rawValue!);
                            // Prevent multiple triggers by briefly pausing or let the parent handle pop
                            break;
                          }
                        }
                      },
                    ),
                    Center(
                      child: Container(
                        width: 150,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.green.withOpacity(0.5), width: 2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                )
              : null,
        ),

        const SizedBox(height: 20),
        
        // Always-on text field for USB hardware scanners
        const Text(
          'أو استخدم جهاز مسح الباركود الخارجي (USB):', 
          style: TextStyle(fontSize: 12, color: Colors.blueGrey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          autofocus: true,
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            labelText: 'رقم أو كود الباركود',
            hintText: 'وجّه جهاز الليزر هنا واضغط لقراءة المنتج',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
            ),
            prefixIcon: const Icon(Icons.qr_code_scanner),
          ),
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              widget.onDetect(value.trim());
              _controller.clear();
            }
          },
        ),
      ],
      ),
    );
  }
}
