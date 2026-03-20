import 'api_client.dart';

class AppFlowyApi {
  final ApiClient _client;
  static const _baseUrl = 'http://localhost/appflowy';

  AppFlowyApi({required ApiClient client}) : _client = client;

  // TODO: Add AppFlowy-Cloud endpoint methods
  Future<dynamic> getWorkspaces() async {
    final response = await _client.dio.get('$_baseUrl/api/workspace');
    return response.data;
  }
}
