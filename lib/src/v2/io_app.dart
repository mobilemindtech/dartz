
import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:dio/src/result.dart';
import 'package:dio/src/option.dart';
import 'package:dio/src/trying.dart';
import 'package:dio/src/v2/runtime.dart';
import 'package:dio/src/v2/io.dart';


class IOApp {

  late int? workerCount;
  late final Runtime _runtime;

  IOApp({this.workerCount}){
    _runtime = Runtime(workerCount: workerCount ?? Platform.numberOfProcessors);
  }

  Future<Option<A>> unsafeRun<A>(IO<A> io) async {
    return switch(await eval(io)){
      Ok(:var value) => value,
      Failure f => throw f.failure
    };
  }

  Result<Option<A>> _resultOf<A>(A value) => Result.ok(Option.of(value));

  Future<Result<Option<A>>> eval<A>(IO<A> io) async {
    return switch(io){
      IOPure pt => _resultOf(pt.computation()),
      IOAttempt pt => Try.of(() => Option.of(pt.computation())),
      IOAsync pt =>
          Try.ofAsync(() async => Option.of((await pt.computation()))),
      IOMap pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty => _resultOf(pt.apply(value.get())),
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOFlatMap pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty =>
            switch(await eval(pt.apply(value.get()))){
              Ok(:var value) => Result.ok(value.cast()),
              Failure(:var failure) => Result.failure(failure)
            },
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOFold pt =>
        Result.ok(pt.items.fold(pt.initialValue, pt.apply).liftOption),
      IOAndThan pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty =>
          switch(await eval(pt.computation())){
            Ok(:var value) => Result.ok(value.cast()),
            Failure(:var failure) => Result.failure(failure)
          },
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOForeach pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty => _tap(pt.apply(value.get()), Result.ok(value.cast())),
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOFilter pt =>
        switch(await eval(pt.last)){
          Ok(:var value) when value.nonEmpty => Result.ok(pt.apply(value.get()) ? value.cast() : None()),
          Ok _ => Result.ok(None()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOOr pt =>
        switch(await eval(pt.last)){
          Ok(value: None()) => _resultOf(pt.computation()),
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOOrElse pt =>
        switch(await eval(pt.last)){
          Ok(value: None()) =>
            switch(await eval(pt.computation())){
              Ok(:var value) => Result.ok(value.cast()),
              Failure(:var failure) => Result.failure(failure)
            },
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) => Result.failure(failure)
        },
      IOCatchAll pt =>
        switch(await eval(pt.last)){
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) => _tap(pt.computation(failure), Result.failure(failure))
        },
      IORecover pt =>
        switch(await eval(pt.last)){
          Ok(:var value) => Result.ok(value.cast()),
          Failure(:var failure) =>
            switch(await eval(pt.computation(failure))){
              Ok(:var value) => Result.ok(value.cast()),
              Failure(:var failure) => Result.failure(failure)
            }
        },
      IOParMapM pt =>
          switch(await _parMapM(pt.items, pt.maxParallelism,  pt.apply)){
            Ok(:var value)  => Result.ok(value.map((x) => pt.convert(x) as A)),
            Failure(:var failure) => Result.failure(failure)
          },
      IOParMap pt =>
        switch(await _parMap(pt.items, pt.maxParallelism,  pt.apply)){
          Ok(:var value)  => Result.ok(value.map((x) => pt.convert(x) as A)),
          Failure(:var failure) => Result.failure(failure)
        },
      IORace pt =>
          switch(await _race(pt.items, pt.ignoreErrors)){
            Ok(:var value)  => Result.ok(value.cast()),
            Failure(:var failure) => Result.failure(failure)
          },
      IODebug pt =>
        switch(await eval(pt.last)){
          Ok(:var value)  => _debug(pt.last.runtimeType, pt.label ?? "??", "$value", Result.ok(value.cast())),
          Failure(:var failure) =>
              _debug(pt.last.runtimeType, pt.label ?? "??", "$failure", Result.failure(failure))
        },

      //_ => Result.failure(Exception("io not match"))
    };
  }

  Future<Result<Option<List<B>>>> _parMapM<A, B>(List<A> items, int? maxParallelism, IO<B> Function(A) f) async {
    final results = List<B?>.filled(items.length, null);
    final completer = Completer<Option<List<B>>>();
    var completed = 0;

    // Função para processar um item
    void processItem(int index) {

      _runtime.execute(() async {

        if(completer.isCompleted) return;

        var r = await eval(f(items[index]));
        switch (r) {
          case Ok(:var value) when value.nonEmpty:
            //print("index=$index");
            results[index] = value.get();
            completed++;
            if (completed == items.length) {
              if(completer.isCompleted) return;
              completer.complete(results.cast<B>().liftOption);
            }
            break;
          case Ok _:
            if(completer.isCompleted) return;
            completer.complete(None());
            break;
          case Failure(:var err):
            if(completer.isCompleted) return;
            completer.completeError(err);
            break;
        }
      });
    }

    final max = maxParallelism ?? _runtime.workerCount;
    // Distribuir tarefas inicialmente
    for (var i = 0; i < items.length && i < max; i++) {
      final index = i;
      processItem(index);
    }

    var nextIndex = max;
    // Adicionar callbacks para work stealing
    _runtime.onIdle = () {
      if (nextIndex < items.length) {
        final index = nextIndex++;
        processItem(index);
      }
    };

    try{
      final ok = (await completer.future).liftOk;
      return ok;
    } on Exception catch (err, _){
      return Result.failure(err);
    } on Object catch (err, _) {
      return Result.failure(Exception("$err"));
    }
  }


  Future<Result<Option<List<B>>>> _parMap<A, B>(
      List<A> items, int? maxParallelism, FutureOr<B> Function(A) f) async {
    final results = List<B?>.filled(items.length, null);
    final completer = Completer<Option<List<B>>>();
    var completed = 0;

    // Função para processar um item
    void processItem(int index) {
      _runtime.execute(() async {
        if (completer.isCompleted) return;
        try {
          results[index] = await f(items[index]);
          completed++;
          if (completed == items.length) {
            if (completer.isCompleted) return;
            completer.complete(results
                .cast<B>()
                .liftOption);
          }
        } catch (err) {
          if (completer.isCompleted) return;
          completer.completeError(err);
        }
      });
    }

    final max = maxParallelism ?? _runtime.workerCount;
    // Distribuir tarefas inicialmente
    for (var i = 0; i < items.length && i < max; i++) {
      final index = i;
      processItem(index);
    }

    var nextIndex = max;
    // Adicionar callbacks para work stealing
    _runtime.onIdle = () {
      if (nextIndex < items.length) {
        final index = nextIndex++;
        processItem(index);
      }
    };

    try{
      final ok = (await completer.future).liftOk;
      return ok;
    } on Exception catch (err, _){
      return Result.failure(err);
    } on Object catch (err, _) {
      return Result.failure(Exception("$err"));
    }
  }

  Future<Result<Option<A>>> _race<A>(
      List<IO<A>> items, bool ignoreErrors) async {
    final completer = Completer<Option<A>>();

    for(var io in items){
      _runtime.execute(() async {

        if(completer.isCompleted) return;

        switch(await eval(io)){
           case Ok(:var value) when value.nonEmpty:
             if(completer.isCompleted) return;
            completer.complete(value);
            break;
          case Ok _: // pass
            break;
          case Failure(:var failure):
            if(!ignoreErrors){
              if(completer.isCompleted) return;
              completer.completeError(failure);
              }
            break;
        }
      });
    }

    try{
      return (await completer.future).liftOk;
    } on Exception catch (err, _){
      return Result.failure(err);
    }
  }

  void dispose() {
    _runtime.dispose();
  }

  Map<String, dynamic> get stats => _runtime.stats;
}

T _tap<T>(dynamic unused, T result) => result;

T _debug<T>(Type typ, String label, String msg, T value) {
  log("::> DEBUG [$typ($label)]: $msg");
  return value;
}

extension IOAppIO<A> on IO<A> {
  Future<Option<A>> unsafeRun({int? workerCount}) async =>
      IOApp(workerCount: workerCount).unsafeRun(this);
}

