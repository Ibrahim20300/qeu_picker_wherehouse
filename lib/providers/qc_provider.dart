import 'package:flutter/foundation.dart';
import '../models/qc_check_model.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';

class QCProvider extends ChangeNotifier {
  ApiService? _apiService;

  // QC check details state
  QCCheckModel? _checkDetails;
  bool _checkDetailsLoading = false;
  String? _checkDetailsError;

  // QC checks list state
  List<QCCheckModel> _checks = [];
  bool _checksLoading = false;
  String? _checksError;

  // Getters
  QCCheckModel? get checkDetails => _checkDetails;
  bool get checkDetailsLoading => _checkDetailsLoading;
  String? get checkDetailsError => _checkDetailsError;

  List<QCCheckModel> get checks => _checks;
  bool get checksLoading => _checksLoading;
  String? get checksError => _checksError;

  ApiService? get apiService => _apiService;

  void init(ApiService apiService) {
    _apiService = apiService;
  }

  /// Load QC checks list
  Future<void> loadChecks() async {
    if (_apiService == null) return;

    _checksLoading = true;
    _checksError = null;
    notifyListeners();

    try {
      final response = await _apiService!.get(ApiEndpoints.qcQueue);
      final body = _apiService!.handleResponse(response);

      final list = body['checks'] as List<dynamic>?
          ?? body['data'] as List<dynamic>?
          ?? [];

      _checks = list
          .map((item) => QCCheckModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on ApiException catch (e) {
      _checksError = e.message;
    } catch (e) {
      debugPrint('Error loading QC checks: $e');
      _checksError = 'فشل جلب فحوصات الجودة';
    } finally {
      _checksLoading = false;
      notifyListeners();
    }
  }

  /// Load QC check details by ID
  Future<void> loadCheckDetails(String checkId) async {
    if (_apiService == null) return;

    _checkDetailsLoading = true;
    _checkDetailsError = null;
    notifyListeners();

    try {
      final response = await _apiService!.get(ApiEndpoints.qcCheckDetails(checkId));
      final body = _apiService!.handleResponse(response);

      final data = body['check'] as Map<String, dynamic>?
          ?? body['data'] as Map<String, dynamic>?
          ?? body;

      debugPrint('QC check details response keys: ${body.keys}');
      _checkDetails = QCCheckModel.fromJson(data);
    } on ApiException catch (e) {
      _checkDetailsError = e.message;
    } catch (e) {
      debugPrint('Error loading QC check details: $e');
      _checkDetailsError = 'فشل جلب تفاصيل الفحص';
    } finally {
      _checkDetailsLoading = false;
      notifyListeners();
    }
  }

  // Start state
  bool _startLoading = false;
  String? _startError;

  bool get startLoading => _startLoading;
  String? get startError => _startError;

  /// Start a QC check
  Future<bool> startCheck(String checkId) async {
    if (_apiService == null) return false;

    _startLoading = true;
    _startError = null;
    notifyListeners();

    try {
      final response = await _apiService!.post(ApiEndpoints.qcStart(checkId));
      _apiService!.handleResponse(response);
      return true;
    } on ApiException catch (e) {
      _startError = e.message;
      return false;
    } catch (e) {
      debugPrint('Error starting QC check: $e');
      _startError = 'فشل بدء الفحص';
      return false;
    } finally {
      _startLoading = false;
      notifyListeners();
    }
  }

  // Verify state
  bool _verifyLoading = false;
  String? _verifyError;

  bool get verifyLoading => _verifyLoading;
  String? get verifyError => _verifyError;

  /// Verify (approve) a QC check
  Future<bool> approveCheck(String checkId) async {
    if (_apiService == null) return false;

    _verifyLoading = true;
    _verifyError = null;
    notifyListeners();

    try {
      final response = await _apiService!.post(
        ApiEndpoints.qcVerify(checkId),
        body: {
          'approved': true,
        },
      );
      _apiService!.handleResponse(response);
      return true;
    } on ApiException catch (e) {
      _verifyError = e.message;
      return false;
    } catch (e) {
      debugPrint('Error approving QC check: $e');
      _verifyError = 'فشل اعتماد الفحص';
      return false;
    } finally {
      _verifyLoading = false;
      notifyListeners();
    }
  }

  /// Reject a QC check with rejected zones
  Future<bool> rejectCheck(String checkId, {required String rejectionReason, required List<Map<String, String>> rejectedZones}) async {
    if (_apiService == null) return false;

    _verifyLoading = true;
    _verifyError = null;
    notifyListeners();

    try {
      final response = await _apiService!.post(
        ApiEndpoints.qcVerify(checkId),
        body: {
          'approved': false,
          'rejection_reason': rejectionReason,
          'rejected_zones': rejectedZones,
        },
      );
      _apiService!.handleResponse(response);
      return true;
    } on ApiException catch (e) {
      _verifyError = e.message;
      return false;
    } catch (e) {
      debugPrint('Error rejecting QC check: $e');
      _verifyError = 'فشل رفض الفحص';
      return false;
    } finally {
      _verifyLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _checkDetails = null;
    _checkDetailsLoading = false;
    _checkDetailsError = null;
    _checks = [];
    _checksLoading = false;
    _checksError = null;
    _verifyLoading = false;
    _verifyError = null;
    notifyListeners();
  }
}
