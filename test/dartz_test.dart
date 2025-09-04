import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:test/test.dart';

void main() {
  group('Test IOApp', () {

    setUp(() {
      // Additional setup goes here.
    });

    test('Test parMap', () async {
      final tasks = List.generate(100, (i) => i);

      final computeTask = (int n) => IO.attempt(() async {
        // Simular trabalho de duração variada
        final duration = Duration(milliseconds: (n % 20) * 10);
        await Future.delayed(duration);
        return n * n;
      });

      final taskIO = IO.traverseM(tasks, computeTask);

      print('Iniciando execução com work stealing...');
      final stopwatch = Stopwatch()..start();


      await taskIO.unsafeRun()
          .then((result) {
              if(result.empty) {
                fail("result is empty");
              } else {
                expect(result
                    .get()
                    .length, 100);
                stopwatch.stop();
                print('Tarefas completadas: ${result.get().length}');
                print('Tempo total: ${stopwatch.elapsedMilliseconds}ms');
              }
          })
          .catchError((err, stacktrace){
            print("StackTrace: $stacktrace");
            fail("$err");
          });
    });

    test('Test parallelCompute', () async {
      final tasks = List.generate(100, (i) => i);

      final computeTask = (int n) async {
        // Simular trabalho de duração variada
        final duration = Duration(milliseconds: (n % 20) * 10);
        await Future.delayed(duration);
        return n * n;
      };

      final taskIO = IO.traverse(tasks, computeTask);

      print('Iniciando execução com work stealing...');
      final stopwatch = Stopwatch()..start();


      await taskIO.unsafeRun()
          .then((result) {
        if(result.empty) {
          fail("result is empty");
        } else {
          expect(result
              .get()
              .length, 100);
          stopwatch.stop();
          print('Tarefas completadas: ${result.get().length}');
          print('Tempo total: ${stopwatch.elapsedMilliseconds}ms');
        }
      })
          .catchError((err, stacktrace){
        print("StackTrace: $stacktrace");
        fail("$err");
      });
    });

    test('test simple map', () async {
        var result = await IO.pure(10)
            .map((x) => x * 2)
            .unsafeRun();
        expect(true, result.nonEmpty);
        expect(20, result.get());
    });

    test('test simple flatmap', () async {
      var result = await IO.pure(10)
          .flatMap((x) => IO.pure( x * 2))
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(20, result.get());
    });

    test('test filter found', () async {
      var result = await IO.pure(20)
          .filter((x) => x > 10)
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(20, result.get());
    });

    test('test filter NOT found', () async {
      var result = await IO.pure(20)
          .filter((x) => x > 20)
          .unsafeRun();
      expect(true, result.empty);
    });

    test('test andThan', () async {
      var result = await IO.pure(20)
          .andThan(() => IO.pure(30))
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(30, result.get());
    });

    test('test filter NOT found or', () async {
      var result = await IO.pure(20)
          .filter((x) => x > 20)
          .or(10)
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(10, result.get());
    });

    test('test filter found or', () async {
      var result = await IO.pure(20)
          .filter((x) => x >= 20)
          .or(10)
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(20, result.get());
    });

    test('test filter NOT found orElse', () async {
      var result = await IO.pure(20)
          .filter((x) => x > 20)
          .orElse(() => IO.pure(10))
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(10, result.get());
    });

    test('test filter found orElse', () async {
      var result = await IO.pure(20)
          .filter((x) => x >= 20)
          .orElse(() => IO.pure(10))
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(20, result.get());
    });

    test('test attempt success', () async {
      var result = await IO.attempt(() => 20)
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(20, result.get());
    });

    test('test attempt error', () async {
      try {
        await IO.attempt(() => throw Exception("custom error"))
            .unsafeRun();
        fail("exception expected");
      }on Exception catch (err, _) {
        expect("Exception: custom error", "$err");
      } catch(err) {
        fail("exception type expected");
      }

    });

    test('test recover', () async {
        var result = await IO.attempt<String>(() => throw Exception("custom error"))
            .recoverWith((_) => IO.pure("success"))
            .unsafeRun();
        expect(true, result.nonEmpty);
        expect("success", result.get());
    });

    test('test race', () async {
      final tasks = List.generate(10, (i) => i);

      final computeTask = (int n) async {
        // Simular trabalho de duração variada
        final duration = Duration(milliseconds: n != 5 ? 2000 : 10);
        await Future.delayed(duration);
        return n;
      };

      final result = await IO.race(tasks, computeTask).unsafeRun();

      expect(true, result.nonEmpty);
      expect(5, result.get());

    });

    test('test retry', () async {
      int n = 0;
      final result = await IO.attempt((){
        if(n++ == 3) {
          return 1;
        }
        throw 'error';
      }).retry(5, interval: 200.millis)
          .unsafeRun();

      expect(true, result.nonEmpty);
      expect(1, result.get());
    });

    test('test sleep', () async {
      final stopwatch = Stopwatch()..start();
      final result = await IO.pure(1).sleep(1.seconds)
          .unsafeRun();
      stopwatch.stop();
      expect(true, result.nonEmpty);
      expect(1, result.get());
      expect(true, stopwatch.elapsed.inMilliseconds > 1000);
    });

    test('test timeout with failure', () async {
      try {
        await IO.attempt(() async => Future.delayed(1.seconds))
            .timeout(500.millis)
            .unsafeRun();
        fail("expect TimeoutException");
      } on TimeoutException catch(err, _) {
        print("fine!");
      } catch(err) {
        fail("expect TimeoutException, but receive $err");
      }
    });

    test('test timeout with success', () async {
      try {
        await IO.attempt(() async => Future.delayed(200.millis))
            .timeout(500.millis)
            .unsafeRun();
      } on TimeoutException catch(err, _) {
        fail("expect success, but receive TimeoutException");
      } catch(err) {
        fail("expect success, but receive $err");
      }
    });
  });
}
