import 'package:flutter/foundation.dart';
import '../models/order_model.dart';
import '../models/product_model.dart';
import '../services/mock_data_service.dart';

/// نتيجة عملية الالتقاط
class PickResult {
  final bool success;
  final String message;
  final OrderItem? item;
  final int remaining;
  final bool isComplete;
  final bool alreadyComplete;

  PickResult({
    required this.success,
    required this.message,
    this.item,
    this.remaining = 0,
    this.isComplete = false,
    this.alreadyComplete = false,
  });

  factory PickResult.fromMap(Map<String, dynamic> map) {
    return PickResult(
      success: map['success'] ?? false,
      message: map['message'] ?? '',
      item: map['item'],
      remaining: map['remaining'] ?? 0,
      isComplete: map['isComplete'] ?? false,
      alreadyComplete: map['alreadyComplete'] ?? false,
    );
  }

  factory PickResult.notFound(String barcode) {
    return PickResult(
      success: false,
      message: 'الباركود $barcode غير موجود في هذا الطلب',
    );
  }

  factory PickResult.error(String message) {
    return PickResult(
      success: false,
      message: message,
    );
  }
}

class OrdersProvider extends ChangeNotifier {
  final MockDataService _dataService = MockDataService();

  // الحالة
  List<OrderModel> _orders = [];
  OrderModel? _currentOrder;
  bool _isLoading = false;
  String? _scanMessage;
  bool _scanSuccess = false;
  PickResult? _lastPickResult;
  OrderItem? _lastPickedItem;
  List<OrderItem> _missingItems = [];

  // Getters
  List<OrderModel> get orders => _orders;
  List<OrderModel> get pendingOrders =>
      _orders.where((o) => o.status == OrderStatus.pending).toList();
  List<OrderModel> get inProgressOrders =>
      _orders.where((o) => o.status == OrderStatus.inProgress).toList();
  List<OrderModel> get completedOrders =>
      _orders.where((o) => o.status == OrderStatus.completed).toList();
  OrderModel? get currentOrder => _currentOrder;
  bool get isLoading => _isLoading;
  String? get scanMessage => _scanMessage;
  bool get scanSuccess => _scanSuccess;
  PickResult? get lastPickResult => _lastPickResult;
  OrderItem? get lastPickedItem => _lastPickedItem;
  List<OrderItem> get missingItems => _missingItems;

  // العناصر المتبقية (غير مكتملة وغير مفقودة)
  List<OrderItem> get remainingItems {
    if (_currentOrder == null) return [];
    return _currentOrder!.items
        .where((item) => !item.isPicked && !_missingItems.contains(item))
        .toList();
  }

  // العناصر المكتملة
  List<OrderItem> get completedItems {
    if (_currentOrder == null) return [];
    return _currentOrder!.items.where((item) => item.isPicked).toList();
  }

  // عدد المنتجات المفقودة
  int get missingCount => _missingItems.length;

  // هل الطلب الحالي مكتمل؟
  bool get isCurrentOrderComplete {
    if (_currentOrder == null) return false;
    return _currentOrder!.items.every((item) => item.isPicked || _missingItems.contains(item));
  }

  // نسبة اكتمال الطلب الحالي
  double get currentOrderProgress {
    if (_currentOrder == null) return 0;
    final total = _currentOrder!.items.length;
    if (total == 0) return 0;
    final completed = completedItems.length + _missingItems.length;
    return completed / total;
  }

  // عدد العناصر المكتملة
  int get pickedItemsCount {
    if (_currentOrder == null) return 0;
    return completedItems.length;
  }

  // إجمالي العناصر
  int get totalItemsCount {
    if (_currentOrder == null) return 0;
    return _currentOrder!.totalItems;
  }

  /// تحميل الطلبات
  void loadOrders() {
    _isLoading = true;
    notifyListeners();

    _orders = _dataService.getAllOrders();

    _isLoading = false;
    notifyListeners();
  }

  /// تحديد طلب للعمل عليه
  void selectOrder(String orderId) {
    _currentOrder = _orders.firstWhere(
      (o) => o.id == orderId,
      orElse: () => _dataService.getOrderById(orderId)!,
    );
    _lastPickResult = null;
    _missingItems.clear();
    notifyListeners();
  }

  /// الحصول على طلب بالمعرف
  OrderModel? getOrderById(String orderId) {
    return _dataService.getOrderById(orderId);
  }

  /// بدء الطلب
  void startOrder(String orderId) {
    _dataService.startOrder(orderId);
    _refreshCurrentOrder(orderId);
    loadOrders();
  }

  /// التقاط عنصر بالباركود
  PickResult pickItemByBarcode(String barcode) {
    if (_currentOrder == null) {
      _lastPickResult = PickResult.error('لا يوجد طلب محدد');
      _lastPickedItem = null;
      notifyListeners();
      return _lastPickResult!;
    }

    // التحقق من أن الطلب قيد التنفيذ
    if (_currentOrder!.status != OrderStatus.inProgress) {
      _lastPickResult = PickResult.error('يجب بدء التحضير أولاً');
      _lastPickedItem = null;
      notifyListeners();
      return _lastPickResult!;
    }

    // التحقق من وجود الباركود في الطلب
    final matchingItem = _currentOrder!.items.where(
      (item) => item.barcode == barcode,
    ).firstOrNull;

    if (matchingItem == null) {
      _lastPickResult = PickResult.notFound(barcode);
      _lastPickedItem = null;
      notifyListeners();
      return _lastPickResult!;
    }

    // التحقق إذا كان المنتج مفقود
    if (_missingItems.contains(matchingItem)) {
      _lastPickResult = PickResult.error('هذا المنتج محدد كمفقود');
      _lastPickedItem = matchingItem;
      notifyListeners();
      return _lastPickResult!;
    }

    // تنفيذ الالتقاط
    final result = _dataService.pickItemByBarcode(_currentOrder!.id, barcode);

    if (result == null) {
      _lastPickResult = PickResult.error('حدث خطأ أثناء التقاط المنتج');
      _lastPickedItem = null;
      notifyListeners();
      return _lastPickResult!;
    }

    _lastPickResult = PickResult.fromMap(result);
    _lastPickedItem = result['item'] as OrderItem?;
    _refreshCurrentOrder(_currentOrder!.id);
    notifyListeners();

    return _lastPickResult!;
  }

  /// مسح نتيجة الالتقاط الأخيرة
  void clearLastPickResult() {
    _lastPickResult = null;
    notifyListeners();
  }

  /// تحديد منتج كمفقود
  void markItemAsMissing(OrderItem item) {
    if (!_missingItems.contains(item)) {
      _missingItems.add(item);
      notifyListeners();
    }
  }

  /// إلغاء تحديد منتج كمفقود
  void unmarkItemAsMissing(OrderItem item) {
    _missingItems.remove(item);
    notifyListeners();
  }

  /// مسح قائمة المنتجات المفقودة
  void clearMissingItems() {
    _missingItems.clear();
    notifyListeners();
  }

  /// مسح المنتج وخصم الكمية من المخزون
  Future<bool> scanAndDeductProduct(String barcode, int quantity) async {
    _isLoading = true;
    _scanMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final product = _dataService.getProductByBarcode(barcode);

    if (product == null) {
      _scanSuccess = false;
      _scanMessage = 'لم يتم العثور على منتج بهذا الباركود';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (product.quantity < quantity) {
      _scanSuccess = false;
      _scanMessage = 'الكمية المطلوبة ($quantity) أكبر من المتوفر (${product.quantity})';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final success = _dataService.deductFromStock(product.id, quantity);

    if (success) {
      _scanSuccess = true;
      _scanMessage = 'تم خصم $quantity من ${product.name}';

      if (_currentOrder != null) {
        _dataService.updateOrderItem(_currentOrder!.id, product.id, quantity);
        _refreshCurrentOrder(_currentOrder!.id);
      }
    } else {
      _scanSuccess = false;
      _scanMessage = 'فشل في خصم الكمية';
    }

    _isLoading = false;
    notifyListeners();
    return success;
  }

  /// إكمال الطلب
  Future<void> completeOrder(String orderId) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    _dataService.completeOrder(orderId);
    loadOrders();
    _currentOrder = null;
    _lastPickResult = null;

    _isLoading = false;
    notifyListeners();
  }

  /// مسح رسالة المسح
  void clearScanMessage() {
    _scanMessage = null;
    _scanSuccess = false;
    notifyListeners();
  }

  /// الحصول على منتج بالباركود
  ProductModel? getProductByBarcode(String barcode) {
    return _dataService.getProductByBarcode(barcode);
  }

  /// تحديث الطلب الحالي من قاعدة البيانات
  void _refreshCurrentOrder(String orderId) {
    _currentOrder = _dataService.getOrderById(orderId);
  }

  /// إلغاء تحديد الطلب الحالي
  void clearCurrentOrder() {
    _currentOrder = null;
    _lastPickResult = null;
    notifyListeners();
  }
}
