import 'dart:convert';
import 'dart:io';

/// One log record: client envelope + server-assigned sequence.
class LogRecord {
  const LogRecord({
    required this.seq,
    required this.tableName,
    required this.rowId,
    required this.payload,
  });

  final int seq;
  final String tableName;
  final String rowId;
  final Map<String, dynamic> payload;

  /// Full wire shape for GET /events items (envelope + seq).
  Map<String, dynamic> toJson() => <String, dynamic>{
        'seq': seq,
        'tableName': tableName,
        'rowId': rowId,
        'payload': payload,
      };
}

/// Append-only newline-delimited JSON log on local disk.
///
/// ## Durability
/// Every acknowledged append is `flush()`ed before the HTTP handler
/// returns 200. That pushes bytes through Dart into the OS page cache —
/// a process kill (SIGKILL / container stop) cannot lose acked events.
/// Full power-loss durability would need an fsync syscall (not exposed
/// portably by `RandomAccessFile`); out of scope for 8c layer 1.
///
/// ## Sequence recovery
/// On open, the file is scanned and the next seq = max(seq) + 1, so
/// restarts continue the monotonic sequence.
class EventLog {
  EventLog._(this._file, this._nextSeq);

  /// Opens (creating parent dirs if needed) the log at [path].
  static Future<EventLog> open(String path) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    final exists = await file.exists();
    final raf = await file.open(
      mode: exists ? FileMode.writeOnlyAppend : FileMode.writeOnlyAppend,
    );

    var lastSeq = 0;
    if (exists) {
      final lines = await file.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final decoded = jsonDecode(trimmed);
          if (decoded is Map<String, dynamic>) {
            final seq = decoded['seq'];
            if (seq is int && seq > lastSeq) lastSeq = seq;
          }
        } on FormatException {
          // Skip corrupt trailing lines; already-acked lines stay valid.
        }
      }
    }

    return EventLog._(raf, lastSeq + 1);
  }

  final RandomAccessFile _file;
  int _nextSeq;

  /// Highest sequence already persisted, or 0 when the log is empty.
  int get lastSeq => _nextSeq - 1;

  /// Appends [events] with consecutive seqs. Flushes before returning.
  Future<List<LogRecord>> append(
    List<({String tableName, String rowId, Map<String, dynamic> payload})>
        events,
  ) async {
    final written = <LogRecord>[];
    final buffer = StringBuffer();
    for (final event in events) {
      final record = LogRecord(
        seq: _nextSeq++,
        tableName: event.tableName,
        rowId: event.rowId,
        payload: event.payload,
      );
      written.add(record);
      buffer.writeln(jsonEncode(record.toJson()));
    }
    await _file.writeString(buffer.toString());
    await _file.flush();
    return written;
  }

  /// Records with [seq] strictly greater than [since], in log order,
  /// capped at [limit]. [hasMore] is true when further events exist.
  ///
  /// **since is exclusive** — matches the client contract
  /// (`seq > cursor`). `since=0` returns the full log from the start.
  Future<({List<LogRecord> records, bool hasMore})> readSince({
    required int since,
    required int limit,
  }) async {
    final file = File(_file.path);
    if (!await file.exists()) {
      return (records: const <LogRecord>[], hasMore: false);
    }
    final lines = await file.readAsLines();
    final records = <LogRecord>[];
    var hasMore = false;
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final Object? decoded;
      try {
        decoded = jsonDecode(trimmed);
      } on FormatException {
        continue;
      }
      if (decoded is! Map<String, dynamic>) continue;
      final seq = decoded['seq'];
      if (seq is! int || seq <= since) continue;
      if (records.length >= limit) {
        hasMore = true;
        break;
      }
      final payload = decoded['payload'];
      records.add(
        LogRecord(
          seq: seq,
          tableName: decoded['tableName']! as String,
          rowId: decoded['rowId']! as String,
          payload: payload is Map
              ? Map<String, dynamic>.from(payload)
              : <String, dynamic>{},
        ),
      );
    }
    return (records: records, hasMore: hasMore);
  }

  Future<void> close() async {
    await _file.flush();
    await _file.close();
  }
}
