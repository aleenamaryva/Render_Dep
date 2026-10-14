import '../models/disaster_response.dart';
import 'api_service.dart';

abstract class ResponseService {
  Future<void> saveResponse(DisasterResponse response);
  List<DisasterResponse> getAllResponses();
  DisasterResponse? getLatestResponse();
  void clearResponseHistory();
  Future<void> saveLocalNoResponse({required String userId, required String disasterId});
  SafetyStatus get currentStatus;
  Future<List<DisasterResponse>> syncResponses({required ApiService api});
}

class LocalResponseService implements ResponseService {
  SafetyStatus _currentStatus = SafetyStatus.noResponse;
  final List<DisasterResponse> _responses = [];

  @override
  Future<void> saveResponse(DisasterResponse response) async {
    _responses.add(response);
    _currentStatus = response.status;
  }

  @override
  List<DisasterResponse> getAllResponses() {
    final responses = List<DisasterResponse>.from(_responses);
    responses.sort((first, second) => second.timestamp.compareTo(first.timestamp));
    return List<DisasterResponse>.unmodifiable(responses);
  }

  @override
  DisasterResponse? getLatestResponse() {
    final responses = getAllResponses();
    return responses.isEmpty ? null : responses.first;
  }

  @override
  void clearResponseHistory() {
    _responses.clear();
    _currentStatus = SafetyStatus.noResponse;
  }

  @override
  Future<void> saveLocalNoResponse({required String userId, required String disasterId}) async {
    _currentStatus = SafetyStatus.noResponse;
  }

  @override
  SafetyStatus get currentStatus => _currentStatus;

  @override
  Future<List<DisasterResponse>> syncResponses({required ApiService api}) async {
    try {
      final data = await api.get('/responses/my');
      final items = data['items'];
      if (items is List) {
        _responses.clear();
        for (final item in items) {
          if (item is Map<String, dynamic>) {
            _responses.add(DisasterResponse.fromJson(item));
          }
        }
        _responses.sort((first, second) => second.timestamp.compareTo(first.timestamp));
        if (_responses.isNotEmpty) {
          _currentStatus = _responses.first.status;
        } else {
          _currentStatus = SafetyStatus.noResponse;
        }
      }
    } catch (_) {
      // Keep existing memory responses if offline or unauthenticated
    }
    return getAllResponses();
  }
}
