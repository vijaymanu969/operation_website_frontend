import 'api_client.dart';

class CustomApi {
  final ApiClient _client;
  static const _baseUrl = 'http://localhost/api';

  CustomApi({required ApiClient client}) : _client = client;

  // TODO: Add custom Node.js endpoint methods
  Future<dynamic> getHealthCheck() async {
    final response = await _client.dio.get('$_baseUrl/health');
    return response.data;
  }
}
