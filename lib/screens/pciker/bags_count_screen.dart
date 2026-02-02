import 'package:flutter/material.dart';
import '../../helpers/snackbar_helper.dart';

class BagsCountScreen extends StatefulWidget {
  final String orderNumber;

  const BagsCountScreen({super.key, required this.orderNumber});

  @override
  State<BagsCountScreen> createState() => _BagsCountScreenState();
}

class _BagsCountScreenState extends State<BagsCountScreen> {
  String _value = '0';

  void _onNumberPressed(String number) {
    setState(() {
      if (_value == '0') {
        _value = number;
      } else {
        _value = _value + number;
      }
    });
  }

  void _onBackspace() {
    setState(() {
      if (_value.length > 1) {
        _value = _value.substring(0, _value.length - 1);
      } else {
        _value = '0';
      }
    });
  }

  void _onClear() {
    setState(() {
      _value = '0';
    });
  }

  void _onConfirm() {
    final count = int.tryParse(_value) ?? 0;
    if (count == 0) {
      SnackbarHelper.error(context, 'يجب إدخال عدد الأكياس');
      return;
    }
    Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('الطلب ${widget.orderNumber}'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 10),
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: _buildDisplay(),
          ),
          _buildKeypad(),
          const Spacer(),
          _buildConfirmButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Container(
        //   padding: const EdgeInsets.all(20),
        //   decoration: BoxDecoration(
        //     color: Colors.blue.withValues(alpha: 0.1),
        //     shape: BoxShape.circle,
        //   ),
        //   child: const Icon(
        //     Icons.shopping_bag,
        //     size: 10,
        //     color: Colors.blue,
        //   ),
        // ),
        const SizedBox(height: 16),
        const Text(
          'أدخل عدد الأكياس المستخدمة',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDisplay() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 32),
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
          const Icon(Icons.shopping_bag_outlined, size: 32, color: Colors.blue),
          const SizedBox(width: 16),
          Text(
            _value,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          const SizedBox(width: 16),
          const Text(
            'كيس',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              _buildKeypadButton('1'),
              _buildKeypadButton('2'),
              _buildKeypadButton('3'),
            ],
          ),
          Row(
            children: [
              _buildKeypadButton('4'),
              _buildKeypadButton('5'),
              _buildKeypadButton('6'),
            ],
          ),
          Row(
            children: [
              _buildKeypadButton('7'),
              _buildKeypadButton('8'),
              _buildKeypadButton('9'),
            ],
          ),
          Row(
            children: [
              _buildKeypadButton('C', isAction: true, onTap: _onClear),
              _buildKeypadButton('0'),
              _buildKeypadButton('⌫', isAction: true, onTap: _onBackspace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeypadButton(String label, {bool isAction = false, VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: isAction ? Colors.grey[300] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          child: InkWell(
            onTap: onTap ?? () => _onNumberPressed(label),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 70,
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: isAction ? 24 : 32,
                  fontWeight: FontWeight.bold,
                  color: isAction ? Colors.grey[700] : Colors.black87,
                ),
              ),
            ),
          ),
        ),
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
            'إكمال الطلب',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
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
