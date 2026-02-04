import 'package:flutter/material.dart';

class NumericKeypad extends StatelessWidget {
  final Function(String number) onNumberPressed;
  final VoidCallback onClear;
  final VoidCallback onBackspace;

  const NumericKeypad({
    super.key,
    required this.onNumberPressed,
    required this.onClear,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            children: [
              _buildButton('1'),
              _buildButton('2'),
              _buildButton('3'),
            ],
          ),
          Row(
            children: [
              _buildButton('4'),
              _buildButton('5'),
              _buildButton('6'),
            ],
          ),
          Row(
            children: [
              _buildButton('7'),
              _buildButton('8'),
              _buildButton('9'),
            ],
          ),
          Row(
            children: [
              _buildButton('C', isAction: true, onTap: onClear),
              _buildButton('0'),
              _buildButton('⌫', isAction: true, onTap: onBackspace),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildButton(String label, {bool isAction = false, VoidCallback? onTap}) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Material(
          color: isAction ? Colors.grey[300] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          elevation: 2,
          child: InkWell(
            onTap: onTap ?? () => onNumberPressed(label),
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
}
