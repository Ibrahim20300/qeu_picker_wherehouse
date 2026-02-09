import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';

class MasterPickerProvider extends ChangeNotifier {
  ApiService? _apiService;
  List<dynamic> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> _exceptions = [];
  bool _exceptionsLoading = false;
  String? _exceptionsError;

  List<dynamic> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  List<dynamic> get exceptions => _exceptions;
  bool get exceptionsLoading => _exceptionsLoading;
  String? get exceptionsError => _exceptionsError;

  void init(ApiService apiService) {
    _apiService = apiService;
  }

  Future<void> fetchTasks({bool hideLoad=false}) async {
    if (_apiService == null) return;

    _isLoading = true;
    if(hideLoad){
      _isLoading=false;
    }
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService!.get(ApiEndpoints.masterPickingTasks);
      final data = _apiService!.handleResponse(response);

      if (data['tasks'] != null) {
        _tasks = data['tasks'] as List<dynamic>;
      } else if (data['data'] != null) {
        _tasks = data['data'] as List<dynamic>;
      } else {
        _tasks = [];
      }

      _isLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _isLoading = false;
      _errorMessage = e.message;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'فشل تحميل المهام';
      notifyListeners();
    }
  }

  Future<void> fetchPendingExceptions({bool hideLoad = false}) async {
    if (_apiService == null) return;

    _exceptionsLoading = !hideLoad;
    _exceptionsError = null;
    notifyListeners();

    try {
      final response = await _apiService!.get(ApiEndpoints.pendingExceptions);
      final data = _apiService!.handleResponse(response);

      if (data['exceptions'] != null) {
        _exceptions = data['exceptions'] as List<dynamic>;
      } else if (data['data'] != null) {
        _exceptions = data['data'] as List<dynamic>;
      } else {
        _exceptions = [];
      }

      _exceptionsLoading = false;
      notifyListeners();
    } on ApiException catch (e) {
      _exceptionsLoading = false;
      _exceptionsError = e.message;
      notifyListeners();
    } catch (e) {
      _exceptionsLoading = false;
      _exceptionsError = 'فشل تحميل الاستثناءات';
      notifyListeners();
    }
  }

  Future<bool> approveException(String exceptionId, {required bool approved}) async {
    if (_apiService == null) return false;

    try {
      final response = await _apiService!.post(
        ApiEndpoints.approveException(exceptionId),
        body: {'approved': approved},
      );
      _apiService!.handleResponse(response);
      _exceptions.removeWhere((e) => e is Map && e['exception_id']?.toString() == exceptionId);
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }
}
