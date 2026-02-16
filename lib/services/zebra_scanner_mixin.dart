import 'dart:async';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _scannerModeKey = 'scanner_mode_override';

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
  FocusNode scanFocusNode = FocusNode();
  Timer? _focusTimer;
  ScannerDeviceType _deviceType = ScannerDeviceType.other;
  ScannerDeviceType _realDeviceType = ScannerDeviceType.other;
  bool _forcedZebraMode = false;
  late void Function(String barcode) _onScan;

  // Zebra / Other - TextField approach
  TextEditingController scanController = TextEditingController();
  Timer? _debounceTimer;

  // Honeywell - KeyEvent buffer approach
  String _scanBuffer = '';
  Timer? _scanTimeout;

  ScannerDeviceType get deviceType => _deviceType;
  ScannerDeviceType get realDeviceType => _realDeviceType;
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
        _realDeviceType = ScannerDeviceType.zebra;
        _deviceType = ScannerDeviceType.zebra;
      } else if (manufacturer.contains('honeywell')) {
        _realDeviceType = ScannerDeviceType.honeywell;
        // تحقق من الخيار المحفوظ فقط لأجهزة Honeywell
        final prefs = await SharedPreferences.getInstance();
        final saved = prefs.getString(_scannerModeKey);
        if (saved == 'zebra') {
          _deviceType = ScannerDeviceType.zebra;
          _forcedZebraMode = true;
        } else {
          _deviceType = ScannerDeviceType.honeywell;
        }
      } else {
        _realDeviceType = ScannerDeviceType.other;
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
    print(event);
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;
print(key);
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

  /// تبديل إلى وضع Zebra (TextField) - مفيد إذا كان Honeywell لا يعمل بوضع KeyEvent
  void switchToZebraMode() {
    // إيقاف كل شيء قديم
    _focusTimer?.cancel();
    _focusTimer = null;
    _scanTimeout?.cancel();
    _debounceTimer?.cancel();
    _scanBuffer = '';

    // تحرير القديم
    scanFocusNode.dispose();
    scanController.dispose();

    // إنشاء جديد
    scanFocusNode = FocusNode();
    scanController = TextEditingController();

    _deviceType = ScannerDeviceType.zebra;
    _forcedZebraMode = true;
    scanController.addListener(_onTextChanged);
    SharedPreferences.getInstance().then((p) => p.setString(_scannerModeKey, 'zebra'));

    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
        _focusTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
          SystemChannels.textInput.invokeMethod('TextInput.hide');
          _requestFocus();
          SystemChannels.textInput.invokeMethod('TextInput.hide');
        });
      });
    }
  }

  /// تبديل إلى وضع Honeywell (Focus + KeyEvent)
  void switchToHoneywellMode() {
    _focusTimer?.cancel();
    _focusTimer = null;
    _debounceTimer?.cancel();
    _scanBuffer = '';

    scanFocusNode.dispose();
    scanController.dispose();

    scanFocusNode = FocusNode();
    scanController = TextEditingController();

    _deviceType = ScannerDeviceType.honeywell;
    _forcedZebraMode = false;
    SharedPreferences.getInstance().then((p) => p.setString(_scannerModeKey, 'honeywell'));

    if (mounted) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _requestFocus();
        SystemChannels.textInput.invokeMethod('TextInput.hide');
      });
    }
  }

  void pauseScanner() {
    _focusTimer?.cancel();
    _focusTimer = null;
  }

  void resumeScanner() {
    if (_deviceType == ScannerDeviceType.zebra && _focusTimer == null && !_forcedZebraMode) {
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
      left: 0,
      top: 0,
      child: Opacity(
        opacity: 0,
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
      ),
    );
  }
}
