import 'package:http/http.dart' as http;

/// HTTP client that attaches the Auth0 access token to every request.
class ApiClient {
  final String _baseUrl;
  final String? Function() _getToken;

  const ApiClient({required String baseUrl, required String? Function() getToken})
      : _baseUrl = baseUrl,
        _getToken = getToken;

  Map<String, String> _headers() {
    final token = _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Sends a GET request to [path].
  Future<http.Response> get(String path) =>
      http.get(Uri.parse('$_baseUrl$path'), headers: _headers());

  /// Sends a POST request to [path] with [body].
  Future<http.Response> post(String path, String body) =>
      http.post(Uri.parse('$_baseUrl$path'), headers: _headers(), body: body);

  /// Sends a PUT request to [path] with [body].
  Future<http.Response> put(String path, String body) =>
      http.put(Uri.parse('$_baseUrl$path'), headers: _headers(), body: body);

  /// Sends a DELETE request to [path].
  Future<http.Response> delete(String path) =>
      http.delete(Uri.parse('$_baseUrl$path'), headers: _headers());
}
