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
