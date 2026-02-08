import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/api_endpoints.dart';

class MasterPickerProvider extends ChangeNotifier {
  ApiService? _apiService;
  List<dynamic> _tasks = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<dynamic> get tasks => _tasks;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void init(ApiService apiService) {
    _apiService = apiService;
  }

  Future<void> fetchTasks() async {
    if (_apiService == null) return;

    _isLoading = true;
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
}
