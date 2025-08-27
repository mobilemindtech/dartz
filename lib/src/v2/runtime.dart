import 'dart:async';
import 'dart:collection';
import 'dart:io';

class Runtime {
  final int workerCount;
  late final List<Queue<Function()>> _workerQueues;
  late final List<bool> _workerBusy;
  late final List<Completer<void>> _idleCompleters;
  Timer? _stealingTimer;

  Function()? onIdle;

  Runtime({this.workerCount = 4}) {
    _workerQueues = List.generate(workerCount, (_) => Queue());
    _workerBusy = List.filled(workerCount, false);
    _idleCompleters = List.generate(workerCount, (_) => Completer<void>()..complete());
  }

  static Runtime defaultExecutor() {
    return Runtime(workerCount: Platform.numberOfProcessors);
  }

  // Executar uma tarefa no executor
  void execute(Function() task, {int? preferredWorker}) {
    ////_lock.synchronized(() async {
      final workerId = preferredWorker ?? _findLeastBusyWorker();
      _workerQueues[workerId].add(task);
      _tryStartWorker(workerId);
    //});
  }

  // Encontrar o worker menos ocupado
  int _findLeastBusyWorker() {
    var minQueue = _workerQueues[0].length;
    var candidate = 0;
//
    for (var i = 1; i < workerCount; i++) {
      if (_workerQueues[i].length < minQueue) {
        minQueue = _workerQueues[i].length;
        candidate = i;
      }
    }

    return candidate;
  }

  // Tentar iniciar um worker
  void _tryStartWorker(int workerId) {
    if (!_workerBusy[workerId] && _workerQueues[workerId].isNotEmpty) {
      _workerBusy[workerId] = true;
      _idleCompleters[workerId] = Completer<void>();
      _executeOnWorker(workerId);
    }
  }

  // Executar tarefas em um worker específico
  void _executeOnWorker(int workerId) {
    Future.microtask(() async {
      while (true) {

        final task = await _nextTask(workerId);

        if (task == null) break;

        try {
          task();
        } catch (error) {
          print('Error in worker $workerId: $error');
        }
      }
    });
  }

  Future<dynamic Function()?> _nextTask(int workerId) async {
    //final task = await _lock.synchronized(() async {
      if (_workerQueues[workerId].isEmpty) {
        // Tentar roubar trabalho de outros workers
        final stolenTask = _tryStealWork(workerId);
        if (stolenTask == null) {
          _workerBusy[workerId] = false;
          _idleCompleters[workerId].complete();
          onIdle?.call();
          return null;
        }
        return stolenTask;
      }
      return _workerQueues[workerId].removeFirst();
    //});
  }

  // Tentar roubar trabalho de outros workers
  Function()? _tryStealWork(int thiefWorkerId) {
    for (var i = 0; i < workerCount; i++) {
      final victimWorkerId = (i + thiefWorkerId) % workerCount;

      if (victimWorkerId != thiefWorkerId &&
          _workerQueues[victimWorkerId].length > 1) {

        final stolenTask = _workerQueues[victimWorkerId].removeLast();
        return stolenTask;
      }
    }

    return null;
  }

  // Esperar até que todas as tarefas sejam concluídas
  Future<void> waitForCompletion() {
    return Future.wait(_idleCompleters.map((c) => c.future));
  }

  // Obter estatísticas do executor
  Map<String, dynamic> get stats {
    return {
      'workerCount': workerCount,
      'queueSizes': _workerQueues.map((q) => q.length).toList(),
      'busyWorkers': _workerBusy.where((busy) => busy).length,
    };
  }

  void dispose() {
    _stealingTimer?.cancel();
  }
}

