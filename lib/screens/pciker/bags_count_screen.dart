import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../constants/app_colors.dart';
import '../../helpers/snackbar_helper.dart';
import '../../widgets/numeric_keypad.dart';

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
      SnackbarHelper.error(context, S.mustEnterBagCount);
      return;
    }
    Navigator.pop(context, count);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(S.orderNum(widget.orderNumber)),
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
        //     color: AppColors.primary,
        //   ),
        // ),
        const SizedBox(height: 16),
        Text(
          S.enterBagCount,
          style: const TextStyle(
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
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 32),
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
          const Icon(Icons.shopping_bag_outlined, size: 32, color: AppColors.primary),
          const SizedBox(width: 16),
          Text(
            _value,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Text(
            S.bag,
            style: const TextStyle(
              fontSize: 20,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return NumericKeypad(
      onNumberPressed: _onNumberPressed,
      onClear: _onClear,
      onBackspace: _onBackspace,
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
          label: Text(
            S.completeOrder,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
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
