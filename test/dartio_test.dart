import 'package:dio/src/v2/io.dart';
import 'package:dio/src/v2/io_app.dart';
import 'package:test/test.dart';

void main() {
  group('Test IOApp', () {

    setUp(() {
      // Additional setup goes here.
    });

    test('Test parMap', () async {
      final tasks = List.generate(100, (i) => i);

      final computeTask = (int n) => IO.fromAsync(() async {
        // Simular trabalho de duração variada
        final duration = Duration(milliseconds: (n % 20) * 10);
        await Future.delayed(duration);
        return n * n;
      });

      final taskIO = IO.parMapM(tasks, computeTask);

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

      final taskIO = IO.parMap(tasks, computeTask);

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
          .or(() => 10)
          .unsafeRun();
      expect(true, result.nonEmpty);
      expect(10, result.get());
    });

    test('test filter found or', () async {
      var result = await IO.pure(20)
          .filter((x) => x >= 20)
          .or(() => 10)
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
            .recover((_) => IO.pure("success"))
            .unsafeRun();
        expect(true, result.nonEmpty);
        expect("success", result.get());
    });

  });
}

/*
void test() async {
  final executor = Runtime(workerCount: 4);

  // Criar algumas tarefas com diferentes durações
  final tasks = List.generate(100, (i) => i);

  final computeTask = (int n) => IO.fromAsync(() async {
    // Simular trabalho de duração variada
    final duration = Duration(milliseconds: (n % 20) * 10);
    await Future.delayed(duration);
    return n * n;
  });

  final program = IO.parMap(tasks, computeTask, maxParallelism: 4);

  print('Iniciando execução com work stealing...');
  final stopwatch = Stopwatch()..start();

  final results = await program.run(executor);

  stopwatch.stop();
  print('Tarefas completadas: ${results.length}');
  print('Tempo total: ${stopwatch.elapsedMilliseconds}ms');

  final stats = executor.getStats();
  print('Estatísticas do executor: $stats');

  executor.dispose();
}
 */
