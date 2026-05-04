import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:shelf/shelf.dart';

final _log = Logger('ErrorHandler');

/// Catches unhandled exceptions and returns a 500 JSON response.
Middleware errorHandlerMiddleware() {
  return (Handler inner) {
    return (Request request) async {
      try {
        return await inner(request);
      } catch (error, stackTrace) {
        _log.severe('Unhandled error on ${request.method} ${request.url}', error, stackTrace);
        return Response.internalServerError(
          body: jsonEncode({'error': 'An unexpected error occurred'}),
          headers: {'content-type': 'application/json'},
        );
      }
    };
  };
}
