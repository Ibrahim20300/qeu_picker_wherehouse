import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/numeric_keypad.dart';

class ManualBarcodeScreen extends StatefulWidget {
  const ManualBarcodeScreen({super.key});

  @override
  State<ManualBarcodeScreen> createState() => _ManualBarcodeScreenState();
}

class _ManualBarcodeScreenState extends State<ManualBarcodeScreen> {
  String _barcode = '';
  int _quantity = 1;

  void _onNumberPressed(String number) {
    setState(() {
      _barcode += number;
    });
  }

  void _onBackspace() {
    setState(() {
      if (_barcode.isNotEmpty) {
        _barcode = _barcode.substring(0, _barcode.length - 1);
      }
    });
  }

  void _onClear() {
    setState(() {
      _barcode = '';
    });
  }

  void _incrementQuantity() {
    setState(() {
      _quantity++;
    });
  }

  void _decrementQuantity() {
    if (_quantity > 1) {
      setState(() {
        _quantity--;
      });
    }
  }

  void _onConfirm() {
    if (_barcode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أدخل رقم الباركود')),
      );
      return;
    }
    Navigator.pop(context, {'barcode': _barcode, 'quantity': _quantity});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('إدخال باركود يدوي'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // const SizedBox(height: 20),
          // const Text(
          //   'أدخل رقم الباركود',
          //   style: TextStyle(
          //     fontSize: 20,
          //     fontWeight: FontWeight.bold,
          //   ),
          // ),
          // const SizedBox(height: 16),
          _buildBarcodeDisplay(),
          const SizedBox(height: 16),
          _buildQuantityCounter(),
          const SizedBox(height: 16),
          NumericKeypad(
            onNumberPressed: _onNumberPressed,
            onClear: _onClear,
            onBackspace: _onBackspace,
          ),
          const Spacer(),
          _buildConfirmButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBarcodeDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.qr_code, size: 28, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _barcode.isEmpty ? '---' : _barcode,
              style: TextStyle(
                fontSize: _barcode.length > 13 ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: _barcode.isEmpty ? Colors.grey : AppColors.primary,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityCounter() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'الكمية',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          IconButton(
            onPressed: _decrementQuantity,
            icon: const Icon(Icons.remove_circle, size: 36),
            color: _quantity > 1 ? AppColors.error : Colors.grey,
          ),
          Container(
            width: 60,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.primaryWithOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$_quantity',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
          ),
          IconButton(
            onPressed: _incrementQuantity,
            icon: const Icon(Icons.add_circle, size: 36),
            color: AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _onConfirm,
          icon: const Icon(Icons.check_circle, size: 28),
          label: const Text(
            'تأكيد',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ),
    );
  }
}
