class ApiEndpoints {
  static const String baseUrl = 'https://api.qeu.app/v1';

  // ==================== Auth ====================
  static const String pickerLogin = '/picker/login';
  static const String pickerMe = '/picker/me';

  // ==================== Picking Tasks ====================
  static const String pickingTasks = '/picker/tasks';
  static String startPickingTask(String id) => '/picker/tasks/$id/start';
  static String taskDetails(String id) => '/picker/tasks/$id';

  // ==================== Orders ====================
  static const String orders = '/picker/orders';
  static const String orderDetails = '/picker/orders'; // + /{id}
  static const String startOrder = '/picker/orders'; // + /{id}/start
  static const String completeOrder = '/picker/orders'; // + /{id}/complete

  // ==================== Products ====================
  static const String products = '/picker/products';
  static const String scanProduct = '/picker/products/scan';

  // ==================== Picker ====================
  static const String pickerProfile = '/picker/profile';
  static const String pickerStats = '/picker/stats';

  // Helper methods
  static String orderById(String id) => '$orders/$id';
  static String startOrderById(String id) => '$orders/$id/start';
  static String completeOrderById(String id) => '$orders/$id/complete';
  static String productById(String id) => '$products/$id';

  static Uri uri(String endpoint) => Uri.parse('$baseUrl$endpoint');
}
