import 'dart:io';

import 'package:dart_frog/dart_frog.dart';
import 'package:todo_advanced_backend/repositories/todo_repository.dart';

/// Reset endpoint for testing.
///
/// POST /reset - Clears all data from the repository.
/// Only available in development/testing environments.
Response onRequest(RequestContext context) {
  if (context.request.method != HttpMethod.post) {
    return Response(statusCode: HttpStatus.methodNotAllowed);
  }

  context.read<TodoRepository>().clear();
  return Response.json(body: {'status': 'cleared'});
}
