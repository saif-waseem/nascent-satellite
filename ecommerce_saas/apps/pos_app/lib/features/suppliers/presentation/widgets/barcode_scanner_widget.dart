import 'package:flutter/material.dart';

class BarcodeScannerWidget extends StatefulWidget {
  final Function(String) onDetect;

  const BarcodeScannerWidget({super.key, required this.onDetect});

  @override
  State<BarcodeScannerWidget> createState() => _BarcodeScannerWidgetState();
}

class _BarcodeScannerWidgetState extends State<BarcodeScannerWidget> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _usbFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _usbFocusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _usbFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'استخدم جهاز مسح الباركود (USB/Bluetooth):', 
            style: TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            focusNode: _usbFocusNode,
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
                _usbFocusNode.requestFocus();
              }
            },
          ),
        ],
      ),
    );
  }
}
