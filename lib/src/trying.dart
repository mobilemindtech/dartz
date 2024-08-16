import 'result.dart';

import 'option.dart';

class Try {
  static Result<T> of<T>(T Function() f) {
    try {
      return Result.ok(f());
    } catch (err) {
      return Result.failure(err as Exception);
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
