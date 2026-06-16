// Copyright (C) 2026 David Hobley
//
// This file is part of Shedbooks.
//
// Shedbooks is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Shedbooks is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Shedbooks. If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// HTTP client that attaches the Auth0 access token to every request.
class ApiClient {
  final String _baseUrl;
  final String? Function() _getToken;
  final VoidCallback? _onUnauthorized;

  const ApiClient({
    required String baseUrl,
    required String? Function() getToken,
    VoidCallback? onUnauthorized,
  })  : _baseUrl = baseUrl,
        _getToken = getToken,
        _onUnauthorized = onUnauthorized;

  Map<String, String> _headers() {
    final token = _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  http.Response _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      _onUnauthorized?.call();
    }
    return response;
  }

  /// Sends a GET request to [path].
  Future<http.Response> get(String path) async {
    final response =
        await http.get(Uri.parse('$_baseUrl$path'), headers: _headers());
    return _handleResponse(response);
  }

  /// Sends a POST request to [path] with [body].
  Future<http.Response> post(String path, String body) async {
    final response = await http.post(Uri.parse('$_baseUrl$path'),
        headers: _headers(), body: body);
    return _handleResponse(response);
  }

  /// Sends a PUT request to [path] with [body].
  Future<http.Response> put(String path, String body) async {
    final response = await http.put(Uri.parse('$_baseUrl$path'),
        headers: _headers(), body: body);
    return _handleResponse(response);
  }

  /// Sends a DELETE request to [path].
  Future<http.Response> delete(String path) async {
    final response =
        await http.delete(Uri.parse('$_baseUrl$path'), headers: _headers());
    return _handleResponse(response);
  }

  /// Sends a POST request to [path] with raw [bytes] as the body.
  Future<http.Response> postBytes(String path, List<int> bytes,
      {Map<String, String>? headers}) async {
    final token = _getToken();
    final response = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: {
        'Content-Type': 'application/octet-stream',
        if (token != null) 'Authorization': 'Bearer $token',
        ...?headers,
      },
      body: bytes,
    );
    return _handleResponse(response);
  }
}
