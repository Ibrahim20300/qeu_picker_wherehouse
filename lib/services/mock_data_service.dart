import '../models/user_model.dart';
import '../models/product_model.dart';
import '../models/order_model.dart';

class MockDataService {
  static final MockDataService _instance = MockDataService._internal();
  factory MockDataService() => _instance;
  MockDataService._internal() {
    _initializeData();
  }

  List<UserModel> _users = [];
  List<ProductModel> _products = [];
  List<OrderModel> _orders = [];

  UserModel? _currentUser;

  // Getters
  List<UserModel> get users => _users;
  List<ProductModel> get products => _products;
  List<OrderModel> get orders => _orders;
  UserModel? get currentUser => _currentUser;

  void _initializeData() {
    // Initialize Users - فقط supervisor و picker
    _users = [
      UserModel(
        id: '1',
        name: 'المشرف',
        teamName: 'supervisor',
        password: '123456',
        role: UserRole.supervisor,
      ),
      UserModel(
        id: '2',
        name: 'البيكر',
        teamName: 'picker',
        password: '123456',
        role: UserRole.picker,
        zone: '12',
      ),
    ];

    // Initialize Products
    _products = [
      ProductModel(
        id: 'p1',
        barcode: '6286008230576',
        name: 'حليب المراعي 1 لتر',
        location: 'A-01-02',
        quantity: 50,
      ),
      ProductModel(
        id: 'p2',
        barcode: '1234567890124',
        name: 'عصير تروبيكانا برتقال',
        location: 'A-02-01',
        quantity: 30,
      ),
      ProductModel(
        id: 'p3',
        barcode: '1234567890125',
        name: 'أرز بسمتي 5 كيلو',
        location: 'B-01-03',
        quantity: 15,
      ),
      ProductModel(
        id: 'p4',
        barcode: '1234567890126',
        name: 'زيت عافية 1.5 لتر',
        location: 'B-02-02',
        quantity: 25,
      ),
      ProductModel(
        id: 'p5',
        barcode: '1234567890127',
        name: 'سكر أبيض 2 كيلو',
        location: 'C-01-01',
        quantity: 20,
      ),
      ProductModel(
        id: 'p6',
        barcode: '1234567890128',
        name: 'شاي ليبتون 100 كيس',
        location: 'C-02-03',
        quantity: 40,
      ),
    ];

    // Initialize Orders
    _orders = [
      OrderModel(
        id: 'o1',
        orderNumber: 'ORD-001',
        items: [
          OrderItem(
            productId: 'p1',
            productName: 'حليب المراعي 1 لتر',
            barcode: '1234567890123',
            locations: ['A-01-02', 'A-01-03', 'B-02-01'],
            requiredQuantity: 5,
          ),
          OrderItem(
            productId: 'p2',
            productName: 'عصير تروبيكانا برتقال',
            barcode: '1234567890124',
            locations: ['A-02-01'],
            requiredQuantity: 3,
          ),
        ],
        status: OrderStatus.pending,
      ),
      OrderModel(
        id: 'o2',
        orderNumber: 'ORD-002',
        items: [
          OrderItem(
            productId: 'p3',
            productName: 'أرز بسمتي 5 كيلو',
            barcode: '1234567890125',
            locations: ['B-01-03', 'B-01-04'],
            requiredQuantity: 2,
          ),
          OrderItem(
            productId: 'p4',
            productName: 'زيت عافية 1.5 لتر',
            barcode: '1234567890126',
            locations: ['B-02-02', 'C-01-01', 'C-01-02'],
            requiredQuantity: 4,
          ),
        ],
        status: OrderStatus.pending,
      ),
    ];
  }

  // Authentication
  UserModel? login(String teamName, String password) {
    try {
      final user = _users.firstWhere(
        (u) => u.teamName == teamName && u.password == password && u.isActive,
      );
      _currentUser = user;
      return user;
    } catch (e) {
      return null;
    }
  }

  void logout() {
    _currentUser = null;
  }

  // User Management
  List<UserModel> getPickers() {
    return _users.where((u) => u.role == UserRole.picker).toList();
  }

  void addUser(UserModel user) {
    _users.add(user);
  }

  void updateUser(UserModel user) {
    final index = _users.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _users[index] = user;
    }
  }

  void deleteUser(String userId) {
    _users.removeWhere((u) => u.id == userId);
  }

  String generateUserId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  // Products Management
  ProductModel? getProductByBarcode(String barcode) {
    try {
      return _products.firstWhere((p) => p.barcode == barcode);
    } catch (e) {
      return null;
    }
  }

  // خصم الكمية من المخزون
  bool deductFromStock(String productId, int quantity) {
    final index = _products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final product = _products[index];
      if (product.quantity >= quantity) {
        _products[index] = product.copyWith(
          quantity: product.quantity - quantity,
        );
        return true;
      }
    }
    return false;
  }

  // Orders Management
  List<OrderModel> getAllOrders() {
    return _orders;
  }

  List<OrderModel> getPendingOrders() {
    return _orders.where((o) => o.status == OrderStatus.pending).toList();
  }

  List<OrderModel> getInProgressOrders() {
    return _orders.where((o) => o.status == OrderStatus.inProgress).toList();
  }

  List<OrderModel> getCompletedOrders() {
    return _orders.where((o) => o.status == OrderStatus.completed).toList();
  }

  void startOrder(String orderId) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        status: OrderStatus.inProgress,
      );
    }
  }

  void updateOrderItem(String orderId, String productId, int pickedQuantity) {
    final orderIndex = _orders.indexWhere((o) => o.id == orderId);
    if (orderIndex != -1) {
      final order = _orders[orderIndex];
      final itemIndex = order.items.indexWhere((i) => i.productId == productId);
      if (itemIndex != -1) {
        order.items[itemIndex].pickedQuantity = pickedQuantity;
        order.items[itemIndex].isPicked =
            pickedQuantity >= order.items[itemIndex].requiredQuantity;
      }
    }
  }

  // التقاط عنصر واحد من الطلب بناءً على الباركود
  Map<String, dynamic>? pickItemByBarcode(String orderId, String barcode) {
    final orderIndex = _orders.indexWhere((o) => o.id == orderId);
    if (orderIndex == -1) return null;

    final order = _orders[orderIndex];
    final itemIndex = order.items.indexWhere((i) => i.barcode == barcode);
    if (itemIndex == -1) return null;

    final item = order.items[itemIndex];

    // التحقق إذا كان العنصر مكتمل بالفعل
    if (item.isPicked) {
      return {
        'success': false,
        'message': 'تم التقاط هذا المنتج بالكامل مسبقاً',
        'item': item,
        'alreadyComplete': true,
      };
    }

    // زيادة الكمية الملتقطة
    item.pickedQuantity += 1;

    // التحقق إذا اكتمل
    if (item.pickedQuantity >= item.requiredQuantity) {
      item.isPicked = true;
    }

    return {
      'success': true,
      'message': 'تم التقاط 1 من ${item.productName}',
      'item': item,
      'remaining': item.requiredQuantity - item.pickedQuantity,
      'isComplete': item.isPicked,
    };
  }

  void completeOrder(String orderId, {int bagsCount = 0}) {
    final index = _orders.indexWhere((o) => o.id == orderId);
    if (index != -1) {
      _orders[index] = _orders[index].copyWith(
        status: OrderStatus.completed,
        completedAt: DateTime.now(),
        bagsCount: bagsCount,
      );
    }
  }

  OrderModel? getOrderById(String orderId) {
    try {
      return _orders.firstWhere((o) => o.id == orderId);
    } catch (e) {
      return null;
    }
  }
}
