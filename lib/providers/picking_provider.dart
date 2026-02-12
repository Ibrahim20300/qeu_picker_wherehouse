import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/pick_record.dart';
import '../models/task_details_model.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';

enum ScanResult { locationVerified, barcodeAccepted, itemComplete, orderComplete, wrongLocation, wrongBarcode, scanLocationFirst }

class PickingProvider extends ChangeNotifier {
  ApiService? _apiService;

  // Order & items state
  OrderModel? _currentOrder;
  List<OrderItem> _items = [];
  List<OrderItem> _missingItems = [];
  List<PickRecord> _pickRecords = [];

  // Task details state
  TaskDetailsModel? _taskDetails;
  bool _taskDetailsLoading = false;
  String? _taskDetailsError;

  // Navigation state
  int _currentItemIndex = 0;
  int _currentLocationIndex = 0;
  bool _locationVerified = false;

  // Retry queue for failed API scans
  final List<_PendingScan> _pendingScans = [];
  Timer? _retryTimer;
  static const int _maxRetries = 5;

  // --- Getters ---
  OrderModel? get currentOrder => _currentOrder;
  List<OrderItem> get items => _items;
  List<OrderItem> get missingItems => _missingItems;
  List<PickRecord> get pickRecords => _pickRecords;
  bool get locationVerified => _locationVerified;
  int get currentLocationIndex => _currentLocationIndex;
  TaskDetailsModel? get taskDetails => _taskDetails;
  bool get taskDetailsLoading => _taskDetailsLoading;
  String? get taskDetailsError => _taskDetailsError;

  List<OrderItem> get remainingItems => _items.where((item) =>
      !item.isPicked && !_missingItems.contains(item)).toList();

  List<OrderItem> get completedItems => _items.where((i) => i.isPicked).toList();

  OrderItem? get currentItem {
    final remaining = remainingItems;
    if (remaining.isEmpty) return null;
    if (_currentItemIndex >= remaining.length) {
      _currentItemIndex = 0;
    }
    return remaining[_currentItemIndex];
  }

  String get currentLocation {
    final item = currentItem;
    if (item == null || item.locations.isEmpty) return '';
    if (_currentLocationIndex >= item.locations.length) {
      _currentLocationIndex = 0;
    }
    return item.locations[_currentLocationIndex];
  }

  double get progress {
    if (_items.isEmpty) return 0;
    final done = _items.where((i) => i.isPicked).length + _missingItems.length;
    return done / _items.length;
  }

  // --- Setup ---
  void setApiService(ApiService apiService) {
    _apiService = apiService;
  }

  void startPicking(OrderModel order) {
    _currentOrder = order;
    _items = List.from(order.items);
    _missingItems = [];
    _pickRecords = [];
    _currentItemIndex = 0;
    _currentLocationIndex = 0;
    _locationVerified = false;
    notifyListeners();
  }

  void reset() {
    _currentOrder = null;
    _items = [];
    _missingItems = [];
    _pickRecords = [];
    _taskDetails = null;
    _taskDetailsLoading = false;
    _taskDetailsError = null;
    _currentItemIndex = 0;
    _currentLocationIndex = 0;
    _locationVerified = false;
    notifyListeners();
  }

  // --- Core Scan Logic ---

  /// Main entry point for scanning. Returns result type for UI feedback.
  ScanResult processScan(String scannedValue,String zoneId) {
  bool skipScan=true;
  // skipScan= zoneId=='Z09'||zoneId=='Z011';
    if (!_locationVerified &&skipScan==false) {
      return verifyLocation(scannedValue);
    } else {
      return scanBarcode(scannedValue);
    }
  }

  ScanResult verifyLocation(String scannedLocation) {
    final item = currentItem;
    if (item == null) return ScanResult.wrongLocation;

    // Check if user scanned product barcode instead of location
    final itemBarcodes = item.barcodes.isNotEmpty ? item.barcodes : [item.barcode];
    if (itemBarcodes.contains(scannedLocation)) {
      return ScanResult.scanLocationFirst;
    }

    if (scannedLocation.toUpperCase() == currentLocation.toUpperCase()) {
      _locationVerified = true;
      notifyListeners();
      return ScanResult.locationVerified;
    } else {
      return ScanResult.wrongLocation;
    }
  }

  ScanResult scanBarcode(String barcode) {
    final item = currentItem;
    if (item == null) return ScanResult.wrongBarcode;

    final allBarcodes = item.barcodes.isNotEmpty ? item.barcodes : [item.barcode];
    if (allBarcodes.contains(barcode)) {
      item.pickedQuantity++;

      // Record the pick
      _pickRecords.add(PickRecord(
        productId: item.productId,
        barcode: barcode,
        location: currentLocation,
        quantity: 1,
        timestamp: DateTime.now(),
      ));

      // Send scan to backend
      _sendScanToApi(barcode, 1);

      if (item.pickedQuantity >= item.requiredQuantity) {
        item.isPicked = true;
        notifyListeners();

        // Check if order is complete
        if (remainingItems.isEmpty) {
          return ScanResult.orderComplete;
        }
        return ScanResult.itemComplete;
      }

      notifyListeners();
      return ScanResult.barcodeAccepted;
    } else {
      return ScanResult.wrongBarcode;
    }
  }

  /// Send scan to backend with retry on failure
  void _sendScanToApi(String barcode, int quantity) {
    if (_apiService == null || _currentOrder == null) return;

    final taskId = _currentOrder!.id;
    _attemptScan(_PendingScan(taskId: taskId, barcode: barcode, quantity: quantity));
  }

  void _attemptScan(_PendingScan scan) {
    _apiService!.post(
      ApiEndpoints.scanTask(scan.taskId),
      body: {'barcode': scan.barcode, 'quantity': scan.quantity},
    ).then((response) {
      _apiService!.handleResponse(response);
    }).catchError((e) {
      debugPrint('Scan failed (attempt ${scan.retries + 1}): $e');
      scan.retries++;
      if (scan.retries < _maxRetries) {
        _pendingScans.add(scan);
        _scheduleRetry();
      } else {
        debugPrint('Scan dropped after $_maxRetries retries: ${scan.barcode}');
      }
    });
  }

  void _scheduleRetry() {
    if (_retryTimer?.isActive == true) return;
    _retryTimer = Timer(Duration(seconds: 3), _retryPendingScans);
  }

  void _retryPendingScans() {
    if (_apiService == null || _pendingScans.isEmpty) return;

    final scans = List<_PendingScan>.from(_pendingScans);
    _pendingScans.clear();

    for (final scan in scans) {
      _attemptScan(scan);
    }
  }

  // --- Navigation ---

  void moveToNextItem() {
    _currentItemIndex = 0;
    _currentLocationIndex = 0;
    _locationVerified = false;
    notifyListeners();
  }

  void skipToNextItem() {
    final remaining = remainingItems;
    if (remaining.length <= 1) return;

    _currentItemIndex = (_currentItemIndex + 1) % remaining.length;
    _currentLocationIndex = 0;
    _locationVerified = false;
    notifyListeners();
  }

  /// Returns true if moved to next location, false if all locations exhausted.
  bool tryNextLocation() {
    final item = currentItem;
    if (item == null) return false;

    if (_currentLocationIndex < item.locations.length - 1) {
      _currentLocationIndex++;
      _locationVerified = false;
      notifyListeners();
      return true;
    }
    return false;
  }

  void markAsMissing() {
    final item = currentItem;
    if (item == null) return;

    _missingItems.add(item);

    // Record as missing
    _pickRecords.add(PickRecord(
      productId: item.productId,
      barcode: item.barcode,
      location: currentLocation,
      quantity: 0, // 0 = missing
      timestamp: DateTime.now(),
    ));

    moveToNextItem();
  }

  // --- API Methods ---

  Future<List<dynamic>> getPickingTasks() async {
    if (_apiService == null) return [];

    final response = await _apiService!.get(ApiEndpoints.pickingTasks);
    final data = _apiService!.handleResponse(response);

    if (data['tasks'] != null) {
      return data['tasks'] as List<dynamic>;
    } else if (data['data'] != null) {
      return data['data'] as List<dynamic>;
    }
    return [];
  }

  Future<void> startPickingTask(String taskId) async {
    if (_apiService == null) return;

    final response = await _apiService!.post(
      ApiEndpoints.startPickingTask(taskId),
      body: {},
    );
    _apiService!.handleResponse(response);
  }

  Future<void> loadTaskDetails(String taskId) async {
    if (_apiService == null) throw Exception('ApiService not initialized');

    _taskDetailsLoading = true;
    _taskDetailsError = null;
    notifyListeners();

    try {
      final response = await _apiService!.get(ApiEndpoints.taskDetails(taskId));
      final body = _apiService!.handleResponse(response);

      // API may wrap task data in "task" or "data" key
      final data = body['task'] as Map<String, dynamic>?
          ?? body['data'] as Map<String, dynamic>?
          ?? body;

      debugPrint('Task details response keys: ${body.keys}');
      _taskDetails = TaskDetailsModel.fromJson(data);
    } on ApiException catch (e) {
      _taskDetailsError = e.message;
    } catch (e) {
      debugPrint('Error loading task details: $e');
      _taskDetailsError = 'فشل جلب تفاصيل المهمة';
    } finally {
      _taskDetailsLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> reportItemException(
    String taskId,
    String itemId, {
    required String exceptionType,
    required int quantity,
    String? note,
  }) async {
    if (_apiService == null) return {};

    final response = await _apiService!.post(
      ApiEndpoints.itemException(taskId, itemId),
      body: {
        'exceptionType': exceptionType,
        'quantity': quantity,
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return _apiService!.handleResponse(response);
  }

  /// Get all pick data ready for backend submission
  Map<String, dynamic> getSubmissionData() {
    return {
      'task_id': _currentOrder?.id,
      'order_number': _currentOrder?.orderNumber,
      'picks': _pickRecords.map((r) => r.toJson()).toList(),
      'missing_items': _missingItems.map((item) => {
        'product_id': item.productId,
        'barcode': item.barcode,
        'location': item.primaryLocation,
      }).toList(),
      'completed_at': DateTime.now().toIso8601String(),
    };
  }

  Future<void> completeTaskById(String taskId, int packageCount) async {
    if (_apiService == null) return;

    final response = await _apiService!.post(
      ApiEndpoints.completeTask(taskId),
      body: {'package_count': packageCount},
    );
    _apiService!.handleResponse(response);
  }

  Future<bool> completeTask(int packageCount) async {
    if (_apiService == null || _currentOrder == null) return false;

    // Retry any pending scans before completing
    _retryPendingScans();

    try {
      final response = await _apiService!.post(
        ApiEndpoints.completeTask(_currentOrder!.id),
        body: {'package_count': packageCount},
      );
      _apiService!.handleResponse(response);
      return true;
    } catch (e) {
      debugPrint('Error completing task: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    super.dispose();
  }
}

class _PendingScan {
  final String taskId;
  final String barcode;
  final int quantity;
  int retries;

  _PendingScan({
    required this.taskId,
    required this.barcode,
    required this.quantity,
    this.retries = 0,
  });
}
