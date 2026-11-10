enum DownloadTaskStatus { queued, running, paused, completed, failed, cancelled }

/// Only enqueue after the provider has confirmed offline saving is permitted.
class DownloadRequest {
  const DownloadRequest({required this.id, required this.providerId, required this.source, required this.fileName, this.expectedBytes, this.mimeType});
  final String id;
  final String providerId;
  final Uri source;
  final String fileName;
  final int? expectedBytes;
  final String? mimeType;
}

class DownloadTaskSnapshot {
  const DownloadTaskSnapshot({required this.id, required this.status, this.bytesReceived = 0, this.totalBytes, this.localUri, this.errorCode});
  final String id;
  final DownloadTaskStatus status;
  final int bytesReceived;
  final int? totalBytes;
  final Uri? localUri;
  final String? errorCode;
  double? get progress {
    final total = totalBytes;
    if (total == null || total <= 0) return null;
    return (bytesReceived / total).clamp(0.0, 1.0).toDouble();
  }
}

/// One engine owns queue state and file lifecycle; widgets never depend on Mornye internals.
abstract interface class DownloadEngine {
  Stream<List<DownloadTaskSnapshot>> watchTasks();
  Future<void> enqueue(DownloadRequest request);
  Future<void> pause(String taskId);
  Future<void> resume(String taskId);
  Future<void> cancel(String taskId);
}
