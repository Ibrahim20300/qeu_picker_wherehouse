import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// أنواع أجهزة السكان المدعومة
enum ScannerDeviceType { zebra, honeywell, other }

/// Mixin يوفر دعم السكان لأجهزة المستودعات (Zebra, Honeywell, ...).
///
/// - Zebra: يستخدم TextField مخفي + إخفاء الكيبورد
/// - Honeywell: يستخدم Focus + onKeyEvent + buffer
/// - Other: يستخدم TextField مخفي
///
/// يجب استدعاء:
/// - [initScanner] في initState أو addPostFrameCallback
/// - [disposeScanner] في dispose
/// - [buildScannerField] داخل Stack في build
mixin ZebraScannerMixin<T extends StatefulWidget> on State<T> {
  // مشترك
  final scanFocusNode = FocusNode();
  Timer? _focusTimer;
  ScannerDeviceType _deviceType = ScannerDeviceType.other;
  late void Function(String barcode) _onScan;

  // Zebra / Other - TextField approach
  final scanController = TextEditingController();
  Timer? _debounceTimer;

  // Honeywell - KeyEvent buffer approach
  String _scanBuffer = '';
  Timer? _scanTimeout;

  ScannerDeviceType get deviceType => _deviceType;
  bool get isHardwareScanner =>
      _deviceType == ScannerDeviceType.zebra ||
      _deviceType == ScannerDeviceType.honeywell;

  Future<void> initScanner({required void Function(String barcode) onScan}) async {
    _onScan = onScan;
    await _detectDevice();
    _startListening();
  }

  Future<void> _detectDevice() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final manufacturer = info.manufacturer.toLowerCase();
      if (manufacturer.contains('zebra')) {
        _deviceType = ScannerDeviceType.zebra;
      } else if (manufacturer.contains('honeywell')) {
        _deviceType = ScannerDeviceType.honeywell;
      } else {
        _deviceType = ScannerDeviceType.other;
      }
    } catch (_) {
      _deviceType = ScannerDeviceType.other;
    }
  }

  void _startListening() {
    if (_deviceType == ScannerDeviceType.honeywell) {
      // Honeywell: Focus + onKeyEvent + buffer
      scanFocusNode.requestFocus();
    } else {
      // Zebra / Other: TextField + debounce
      scanController.addListener(_onTextChanged);
    }

    if (_deviceType == ScannerDeviceType.zebra) {
      _focusTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      });
    } else {
      _requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.hide');
    }
  }

  // --- Zebra / Other: TextField debounce ---
  void _onTextChanged() {
    final input = scanController.text.trim();
    print(input);
    if (input.isEmpty) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted && scanController.text.isNotEmpty) {
        final barcode = scanController.text.trim();
        print('Scanned [$_deviceType]: $barcode');
        _onScan(barcode);
        scanController.clear();
      }
    });
  }

  // --- Honeywell: KeyEvent buffer ---
  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Enter = end of scan
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.numpadEnter) {
      _flushScanBuffer();
      return KeyEventResult.handled;
    }

    // Append printable character
    final char = event.character;
    if (char != null && char.isNotEmpty && char.codeUnitAt(0) >= 32) {
      _scanBuffer += char;
      _scanTimeout?.cancel();
      _scanTimeout = Timer(const Duration(milliseconds: 150), _flushScanBuffer);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _flushScanBuffer() {
    _scanTimeout?.cancel();
    final barcode = _scanBuffer.trim();
    _scanBuffer = '';
    if (barcode.isNotEmpty && mounted) {
      _onScan(barcode);
    }
  }

  void _requestFocus() {
    if (mounted && !scanFocusNode.hasFocus) {
      scanFocusNode.requestFocus();
    }
  }

  void requestScannerFocus() => _requestFocus();

  void pauseScanner() {
    _focusTimer?.cancel();
    _focusTimer = null;
  }

  void resumeScanner() {
    if (_deviceType == ScannerDeviceType.zebra && _focusTimer == null) {
      _focusTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      });
    }
    _requestFocus();
  }

  void disposeScanner() {
    _focusTimer?.cancel();
    _debounceTimer?.cancel();
    _scanTimeout?.cancel();
    scanController.dispose();
    scanFocusNode.dispose();
  }

  /// Widget مخفي يستقبل بيانات السكان - ضعه داخل Stack
  Widget buildScannerField() {
    if (_deviceType == ScannerDeviceType.honeywell) {
      // Honeywell: Focus widget يلتقط key events
      return Positioned(
        left: 0,
        right: 0,
        top: 0,
        bottom: 0,
        child: Focus(
          focusNode: scanFocusNode,
          autofocus: true,
          onKeyEvent: handleKeyEvent,
          child: const SizedBox.shrink(),
        ),
      );
    }

    // Zebra / Other: Hidden TextField
    return Positioned(
      left: -1000,
      child: SizedBox(
        width: 1,
        height: 1,
        child: TextField(
          controller: scanController,
          focusNode: scanFocusNode,
          autofocus: true,
          textDirection: TextDirection.ltr,
          enableInteractiveSelection: false,
          showCursor: false,
          decoration: const InputDecoration(border: InputBorder.none),
        ),
      ),
    );
  }
}
