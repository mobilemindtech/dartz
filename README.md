# Dart IO Monad Runtime

```dart

import 'package:dio/dio.dart';

final tasks = List.generate(10, (i) => i);

final computeTask = (int n) async {
    final duration = Duration(milliseconds: n != 5 ? 2000 : 10);
    await Future.delayed(duration);
    return n;
};

final result = await IO.race(tasks, computeTask).unsafeRun();

expect(true, result.nonEmpty);
expect(5, result.get());

```