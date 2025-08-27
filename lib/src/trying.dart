import 'dart:async';

import 'result.dart';

import 'option.dart';

class Try {

  static Result<T> of<T>(T Function() f) {
    try {
      return Result.ok(f());
    } on Exception catch (err, _) {
      return Result.failure(err);
    } on Object catch (err, _) {
      return Result.failure(Exception("$err"));
    }
  }

  static Future<Result<T>> ofAsync<T>(FutureOr<T> Function() f) async {
    try {
      return Result.ok(await f());
    } on Exception catch (err, _) {
      return Result.failure(err);
    } on Object catch (err, _) {
      return Result.failure(Exception("$err"));
    }
  }

  static Option<T> option<T>(T? Function() f) {
    try {
      return Option.of(f());
    } catch (err) {
      return None();
    }
  }
}
