class ApiEndpoints {
  static bool isProduction = true;

  static const String _productionUrl = 'https://api.qeu.info/v1';
  static const String _devUrl = 'https://api.qeu.app/v1';

  static String get baseUrl => isProduction ? _productionUrl : _devUrl;

  // ==================== Auth ====================
  static const String pickerLogin = '/picker/login';
  static const String refreshToken = '/picker/refresh-token';
  static const String pickerMe = '/picker/me';

  // ==================== Picking Tasks ====================
  static const String pickingTasks = '/picker/tasks';
  static String startPickingTask(String id) => '/picker/tasks/$id/start';
  static String taskDetails(String id) => '/picker/tasks/$id';
  static String scanTask(String id) => '/picker/tasks/$id/scan';
  static String completeTask(String id) => '/picker/tasks/$id/complete';
  static String itemException(String taskId, String itemId) => '/picker/tasks/$taskId/items/$itemId/exception';

  // ==================== Orders ====================
  static const String orders = '/picker/orders';
  static const String orderDetails = '/picker/orders'; // + /{id}
  static const String startOrder = '/picker/orders'; // + /{id}/start
  static const String completeOrder = '/picker/orders'; // + /{id}/complete

  // ==================== Products ====================
  static const String products = '/picker/products';
  static const String scanProduct = '/picker/products/scan';

  // ==================== Master Picker ====================
  static const String masterPickingTasks = '/picking/tasks';
  static const String pendingExceptions = '/picker/exceptions/pending';
  static const String pickerZoneStats = '/picker/zone/stats';
  static String approveException(String exceptionId) => '/picker/exceptions/$exceptionId/approve';

  // ==================== QC ====================
  static const String qcQueue = '/qc/queue';
  static const String qcChecks = '/qc/checks';
  static String qcCheckDetails(String checkId) => '/qc/checks/$checkId';
  static String qcOrderDetails(String orderId) => '/qc/orders/$orderId';
  static String qcStart(String checkId) => '/qc/checks/$checkId/start';
  static String qcVerify(String checkId) => '/qc/checks/$checkId/verify';

  // ==================== Picker ====================
  static const String pickerProfile = '/picker/profile';
  static const String pickerStats = '/picker/stats';
  static const String changePassword = '/picker/change-password';
  static const String pickerStatus = '/picker/status';

  // Helper methods
  static String orderById(String id) => '$orders/$id';
  static String startOrderById(String id) => '$orders/$id/start';
  static String completeOrderById(String id) => '$orders/$id/complete';
  static String productById(String id) => '$products/$id';

  static Uri uri(String endpoint) => Uri.parse('$baseUrl$endpoint');
}
