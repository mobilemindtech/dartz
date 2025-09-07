import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:test/test.dart';

void main() {
  group('Test IOApp', () {
    setUp(() {
      // Additional setup goes here.
    });

    test('Test parMap', () async {
      final tasks = List.generate(100, (i) => i);

      final computeTask = (int n) =>
          IO.attempt(() async {
            // Simular trabalho de duração variada
            final duration = Duration(milliseconds: (n % 20) * 10);
            await Future.delayed(duration);
            return n * n;
          });

      final taskIO = IO.traverseM(tasks, computeTask);

      print('Iniciando execução com work stealing...');
      final stopwatch = Stopwatch()
        ..start();


      await taskIO.unsafeRun()
          .then((result) {
        if (result.empty) {
          fail("result is empty");
        } else {
          expect(result
              .get()
              .length, 100);
          stopwatch.stop();
          print('Tarefas completadas: ${result
              .get()
              .length}');
          print('Tempo total: ${stopwatch.elapsedMilliseconds}ms');
        }
      })
          .catchError((err, stacktrace) {
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
      final stopwatch = Stopwatch()
        ..start();


      await taskIO.unsafeRun()
          .then((result) {
        if (result.empty) {
          fail("result is empty");
        } else {
          expect(result
              .get()
              .length, 100);
          stopwatch.stop();
          print('Tarefas completadas: ${result
              .get()
              .length}');
          print('Tempo total: ${stopwatch.elapsedMilliseconds}ms');
        }
      })
          .catchError((err, stacktrace) {
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
          .flatMap((x) => IO.pure(x * 2))
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
      } on Exception catch (err, _) {
        expect("Exception: custom error", "$err");
      } catch (err) {
        fail("exception type expected");
      }
    });

    test('test recover', () async {
      var result = await IO.attempt<String>(() =>
      throw Exception("custom error"))
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
      final result = await IO.attempt(() {
        if (n++ == 3) {
          return 1;
        }
        throw 'error';
      }).retry(5, interval: 200.millis)
          .unsafeRun();

      expect(true, result.nonEmpty);
      expect(1, result.get());
    });

    test('test sleep', () async {
      final stopwatch = Stopwatch()
        ..start();
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
      } on TimeoutException catch (err, _) {
        print("fine!");
      } catch (err) {
        fail("expect TimeoutException, but receive $err");
      }
    });

    test('test timeout with success', () async {
      try {
        await IO.attempt(() async => Future.delayed(200.millis))
            .timeout(500.millis)
            .unsafeRun();
      } on TimeoutException catch (err, _) {
        fail("expect success, but receive TimeoutException");
      } catch (err) {
        fail("expect success, but receive $err");
      }
    });

    test('env', () async {


      // Usa Logger
      EnvIO<Env, void> logMessage(String msg) =>
          EnvIO((env) => IO.effect(() => env.logger.log(msg)).debug());

      // Usa Database
      EnvIO<Env, String> fetchData(String sql) =>
          EnvIO((env) => IO.attempt(() => env.db.query(sql)).debug());

      // Usa Config
      EnvIO<Env, String> getBaseUrl() =>
          EnvIO((env) => IO.attempt(() => env.config.baseUrl).debug());

      EnvIO<Env, RandomAccessFile> fileWrite(String data) =>
          EnvIO((env) => env.file.use((file) =>
              IO.attempt(() =>
                  file.writeString(data)).touch((file) => file.flush())).debug());

      EnvIO<Env, String> fileRead() =>
          EnvIO((_) => File("test.out").readAsString().lift);

      EnvIO<Env, String> program =
      logMessage("Iniciando...")
          .flatMap((_) => getBaseUrl()
              .flatMap((url) => fetchData("select * from users")
                  .map((data) => "Rodando em $url, resultado: $data"))
          .flatMap(fileWrite)
          .flatMap((_) => fileRead())
      );

      var env = Env(
        Logger(),
        Database(),
        Config("https://api.exemplo.com"),
        Resource(() => File("test.out").open(mode: FileMode.write), (f) => f.close()),
      );

      var io = program.provide(env);
      print("IO = $io");
      var result = await io.safeRun();
      expect(true, result.isOk);
      expect(true, result.value.nonEmpty);
      expect("Rodando em https://api.exemplo.com, resultado: ricardo",
          result.value.value);
    });

    test('state', () async {
      EnvStateIO<Env, int, String> program =
      ask<Env, int>().flatMap((env) =>
          get<Env, int>().flatMap((count) =>
              modify<Env, int>((s) => s + 1).flatMap((_) =>
                  EnvStateIO((_, s) => IO.attempt(() {
                    env.logger.log("Rodando em ${env.config.baseUrl}, contador=$count");
                    return ("OK", s);
                  })))));

      var env = Env(
        Logger(),
        Database(),
        Config("https://api.exemplo.com"),
        Resource(() => File("test.out").open(mode: FileMode.write), (f) => f.close()),
      );

      var io = program.provide(env, 1);
      print("IO = $io");
      var result = await io.safeRun();
      expect(true, result.isOk);
      expect(true, result.value.nonEmpty);
      var (msg, contador) = result.value.value;
      expect(2, contador);
      expect("OK", msg);
    });
  });
}

class Logger {
  void log(String msg) => print("[LOG] $msg");
}

class Database {
  String query(String sql) => "ricardo";
}

class Config {
  final String baseUrl;
  Config(this.baseUrl);
}

class Env {
  final Logger logger;
  final Database db;
  final Config config;
  final Resource<RandomAccessFile> file;

  Env(this.logger, this.db, this.config, this.file);
}