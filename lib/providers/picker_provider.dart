import 'package:flutter/foundation.dart';
import '../models/product_model.dart';
import '../services/mock_data_service.dart';

class PickerProvider extends ChangeNotifier {
  final MockDataService _dataService = MockDataService();

  List<ProductModel> _products = [];
  List<ProductModel> _pickedProducts = [];
  List<ProductModel> _missingProducts = [];
  bool _isLoading = false;
  ProductModel? _verifiedProduct;
  String? _verificationMessage;
  bool _verificationSuccess = false;

  // Getters
  List<ProductModel> get products => _products;
  List<ProductModel> get pickedProducts => _pickedProducts;
  List<ProductModel> get missingProducts => _missingProducts;
  bool get isLoading => _isLoading;
  ProductModel? get verifiedProduct => _verifiedProduct;
  String? get verificationMessage => _verificationMessage;
  bool get verificationSuccess => _verificationSuccess;
  int get pickedCount => _pickedProducts.length;
  int get missingCount => _missingProducts.length;

  void loadProducts() {
    _isLoading = true;
    notifyListeners();

    _products = List.from(_dataService.products);

    _isLoading = false;
    notifyListeners();
  }

  // التحقق من المنتج عبر الباركود
  Future<bool> verifyProductByBarcode(String barcode) async {
    _isLoading = true;
    _verifiedProduct = null;
    _verificationMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    final product = _dataService.getProductByBarcode(barcode);

    if (product != null) {
      _verifiedProduct = product;
      _verificationSuccess = true;
      _verificationMessage = 'تم التحقق من المنتج: ${product.name}';
    } else {
      _verificationSuccess = false;
      _verificationMessage = 'لم يتم العثور على منتج بهذا الباركود';
    }

    _isLoading = false;
    notifyListeners();

    return product != null;
  }

  // تم جلب المنتج
  Future<void> markProductAsPicked(ProductModel product) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    // نقل المنتج من القائمة الرئيسية إلى الملتقطة
    _products.removeWhere((p) => p.id == product.id);
    _pickedProducts.add(product);

    _isLoading = false;
    notifyListeners();
  }

  // إلغاء جلب المنتج (إرجاعه للقائمة الرئيسية)
  Future<void> unmarkProductAsPicked(ProductModel product) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    _pickedProducts.removeWhere((p) => p.id == product.id);
    _products.add(product);

    _isLoading = false;
    notifyListeners();
  }

  // تسجيل المنتج كمفقود
  Future<void> markProductAsMissing(ProductModel product) async {
    _isLoading = true;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 300));

    _products.removeWhere((p) => p.id == product.id);
    _missingProducts.add(product);

    _isLoading = false;
    notifyListeners();
  }

  void clearVerification() {
    _verifiedProduct = null;
    _verificationMessage = null;
    _verificationSuccess = false;
    notifyListeners();
  }
}
