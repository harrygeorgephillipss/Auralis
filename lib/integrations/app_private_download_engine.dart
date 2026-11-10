import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'download_engine.dart';

/// Conservative app-private HTTP download engine.
/// It supports only provider-authorized HTTPS sources. Pausing restarts the
/// transfer from byte zero; resumable Range requests are intentionally not
/// claimed until a provider can validate range semantics and file hashes.
class AppPrivateDownloadEngine implements DownloadEngine {
  AppPrivateDownloadEngine({required Directory storageDirectory, http.Client? client})
      : _storageDirectory = storageDirectory, _client = client ?? http.Client();

  final Directory _storageDirectory;
  final http.Client _client;
  final Map<String, DownloadTaskSnapshot> _tasks = {};
  final Map<String, DownloadRequest> _requests = {};
  final Map<String, Completer<void>> _aborters = {};
  final Map<String, Future<void>> _workers = {};
  final _updates = StreamController<List<DownloadTaskSnapshot>>.broadcast();
  bool _disposed = false;

  @override Stream<List<DownloadTaskSnapshot>> watchTasks() async* {
    yield _snapshot;
    yield* _updates.stream;
  }
  List<DownloadTaskSnapshot> get _snapshot => List.unmodifiable(_tasks.values);
  void _emit() { if (!_updates.isClosed) _updates.add(_snapshot); }

  @override Future<void> enqueue(DownloadRequest request) async {
    if (_disposed) throw StateError('Download engine is disposed');
    if (!request.offlineSavingAllowed) {
      throw StateError('Provider has not authorized offline saving for this item');
    }
    if (request.source.scheme != 'https' || request.source.host.isEmpty) {
      throw ArgumentError.value(request.source, 'source', 'HTTPS URL required');
    }
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}
      throw ArgumentError.value(request.id, 'id', 'A unique non-empty task id is required');
    }
    await _storageDirectory.create(recursive: true);
    final safeName = _safeFileName(request.fileName);
    if (safeName.isEmpty) throw ArgumentError.value(request.fileName, 'fileName', 'Invalid filename');
    _requests[request.id] = DownloadRequest(
      id: request.id, providerId: request.providerId, source: request.source,
      fileName: safeName, expectedBytes: request.expectedBytes, mimeType: request.mimeType,
      offlineSavingAllowed: request.offlineSavingAllowed,
    );
    _tasks[request.id] = DownloadTaskSnapshot(id: request.id, status: DownloadTaskStatus.queued);
    _emit();
    _workers[request.id] = _run(request.id);
  }

  String _safeFileName(String value) {
    final leaf = value.replaceAll('\\', '/').split('/').last;
    final safe = leaf.replaceAll(RegExp(r'[<>:"/\\\\|?*\\x00-\\x1F]'), '_').trim();
    if (safe.isEmpty || safe == '.' || safe == '..') return '';
    return safe.length > 180 ? safe.substring(safe.length - 180) : safe;
  }

  Future<void> _run(String id) async {
    final request = _requests[id];
    if (request == null || _disposed) return;
    final aborter = Completer<void>();
    _aborters[id] = aborter;
    final temp = File('${_storageDirectory.path}/.$id.part');
    final destination = File('${_storageDirectory.path}/${request.fileName}');
    IOSink? sink;
    try {
      _tasks[id] = DownloadTaskSnapshot(id: id, status: DownloadTaskStatus.running);
      _emit();
      final outgoing = http.AbortableRequest('GET', request.source, abortTrigger: aborter.future)
        ..followRedirects = false;
      final response = await _client.send(outgoing).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw HttpException('Download HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? request.expectedBytes;
      sink = temp.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        if (_tasks[id]?.status == DownloadTaskStatus.cancelled ||
            _tasks[id]?.status == DownloadTaskStatus.paused) throw const _TransferStopped();
        sink.add(chunk);
        received += chunk.length;
        _tasks[id] = DownloadTaskSnapshot(id: id, status: DownloadTaskStatus.running, bytesReceived: received, totalBytes: total);
        _emit();
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (request.expectedBytes != null && received != request.expectedBytes) {
        throw const FormatException('Downloaded byte count did not match expected size');
      }
      if (await destination.exists()) {
        throw FileSystemException('A file with this name already exists', destination.path);
      }
      await temp.rename(destination.path);
      _tasks[id] = DownloadTaskSnapshot(id: id, status: DownloadTaskStatus.completed, bytesReceived: received, totalBytes: total, localUri: destination.uri);
    } on _TransferStopped {
      if (await temp.exists()) await temp.delete();
    } catch (error) {
      if (await temp.exists()) await temp.delete();
      if (_tasks[id]?.status != DownloadTaskStatus.cancelled && _tasks[id]?.status != DownloadTaskStatus.paused) {
        _tasks[id] = DownloadTaskSnapshot(id: id, status: DownloadTaskStatus.failed, errorCode: error.runtimeType.toString());
      }
    } finally {
      await sink?.close();
      _aborters.remove(id);
      _workers.remove(id);
      _emit();
    }
  }

  @override Future<void> pause(String taskId) async {
    if (_tasks[taskId]?.status != DownloadTaskStatus.running) return;
    _tasks[taskId] = DownloadTaskSnapshot(id: taskId, status: DownloadTaskStatus.paused);
    _aborters[taskId]?.complete();
    await _workers[taskId];
    _emit();
  }
  @override Future<void> resume(String taskId) async {
    if (_tasks[taskId]?.status != DownloadTaskStatus.paused) return;
    _tasks[taskId] = DownloadTaskSnapshot(id: taskId, status: DownloadTaskStatus.queued);
    _emit();
    _workers[taskId] = _run(taskId);
  }
  @override Future<void> cancel(String taskId) async {
    final current = _tasks[taskId];
    if (current == null || current.status == DownloadTaskStatus.completed) return;
    _tasks[taskId] = DownloadTaskSnapshot(id: taskId, status: DownloadTaskStatus.cancelled);
    _aborters[taskId]?.complete();
    await _workers[taskId];
    final temp = File('${_storageDirectory.path}/.$taskId.part');
    if (await temp.exists()) await temp.delete();
    _emit();
  }
  Future<void> dispose() async {
    _disposed = true;
    for (final aborter in _aborters.values) { if (!aborter.isCompleted) aborter.complete(); }
    await Future.wait(_workers.values);
    _client.close();
    await _updates.close();
  }
}

class _TransferStopped implements Exception { const _TransferStopped(); }
).hasMatch(request.id) || _requests.containsKey(request.id)) {
      throw ArgumentError.value(request.id, 'id', 'A unique non-empty task id is required');
    }
    await _storageDirectory.create(recursive: true);
    final safeName = _safeFileName(request.fileName);
    if (safeName.isEmpty) throw ArgumentError.value(request.fileName, 'fileName', 'Invalid filename');
    _requests[request.id] = DownloadRequest(
      id: request.id, providerId: request.providerId, source: request.source,
      fileName: safeName, expectedBytes: request.expectedBytes, mimeType: request.mimeType,
      offlineSavingAllowed: request.offlineSavingAllowed,
    );
    _tasks[request.id] = DownloadTaskSnapshot(id: request.id, status: DownloadTaskStatus.queued);
    _emit();
    _workers[request.id] = _run(request.id);
  }

  String _safeFileName(String value) {
    final leaf = value.replaceAll('\\', '/').split('/').last;
    final safe = leaf.replaceAll(RegExp(r'[<>:"/\\\\|?*\\x00-\\x1F]'), '_').trim();
    if (safe.isEmpty || safe == '.' || safe == '..') return '';
    return safe.length > 180 ? safe.substring(safe.length - 180) : safe;
  }

  Future<void> _run(String id) async {
    final request = _requests[id];
    if (request == null || _disposed) return;
    final aborter = Completer<void>();
    _aborters[id] = aborter;
    final temp = File('${_storageDirectory.path}/.$id.part');
    final destination = File('${_storageDirectory.path}/${request.fileName}');
    IOSink? sink;
    try {
      _tasks[id] = DownloadTaskSnapshot(id: id, status: DownloadTaskStatus.running);
      _emit();
      final outgoing = http.AbortableRequest('GET', request.source, abortTrigger: aborter.future);
      final response = await _client.send(outgoing).timeout(const Duration(seconds: 30));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.stream.drain<void>();
        throw HttpException('Download HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? request.expectedBytes;
      sink = temp.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        if (_tasks[id]?.status == DownloadTaskStatus.cancelled ||
            _tasks[id]?.status == DownloadTaskStatus.paused) throw const _TransferStopped();
        sink.add(chunk);
        received += chunk.length;
        _tasks[id] = DownloadTaskSnapshot(id: id, status: DownloadTaskStatus.running, bytesReceived: received, totalBytes: total);
        _emit();
      }
      await sink.flush();
      await sink.close();
      sink = null;
      if (request.expectedBytes != null && received != request.expectedBytes) {
        throw const FormatException('Downloaded byte count did not match expected size');
      }
      if (await destination.exists()) await destination.delete();
      await temp.rename(destination.path);
      _tasks[id] = DownloadTaskSnapshot(id: id, status: DownloadTaskStatus.completed, bytesReceived: received, totalBytes: total, localUri: destination.uri);
    } on _TransferStopped {
      if (await temp.exists()) await temp.delete();
    } catch (error) {
      if (await temp.exists()) await temp.delete();
      if (_tasks[id]?.status != DownloadTaskStatus.cancelled && _tasks[id]?.status != DownloadTaskStatus.paused) {
        _tasks[id] = DownloadTaskSnapshot(id: id, status: DownloadTaskStatus.failed, errorCode: error.runtimeType.toString());
      }
    } finally {
      await sink?.close();
      _aborters.remove(id);
      _workers.remove(id);
      _emit();
    }
  }

  @override Future<void> pause(String taskId) async {
    if (_tasks[taskId]?.status != DownloadTaskStatus.running) return;
    _tasks[taskId] = DownloadTaskSnapshot(id: taskId, status: DownloadTaskStatus.paused);
    _aborters[taskId]?.complete();
    await _workers[taskId];
    _emit();
  }
  @override Future<void> resume(String taskId) async {
    if (_tasks[taskId]?.status != DownloadTaskStatus.paused) return;
    _tasks[taskId] = DownloadTaskSnapshot(id: taskId, status: DownloadTaskStatus.queued);
    _emit();
    _workers[taskId] = _run(taskId);
  }
  @override Future<void> cancel(String taskId) async {
    final current = _tasks[taskId];
    if (current == null || current.status == DownloadTaskStatus.completed) return;
    _tasks[taskId] = DownloadTaskSnapshot(id: taskId, status: DownloadTaskStatus.cancelled);
    _aborters[taskId]?.complete();
    await _workers[taskId];
    final temp = File('${_storageDirectory.path}/.$taskId.part');
    if (await temp.exists()) await temp.delete();
    _emit();
  }
  Future<void> dispose() async {
    _disposed = true;
    for (final aborter in _aborters.values) { if (!aborter.isCompleted) aborter.complete(); }
    await Future.wait(_workers.values);
    _client.close();
    await _updates.close();
  }
}

class _TransferStopped implements Exception { const _TransferStopped(); }
