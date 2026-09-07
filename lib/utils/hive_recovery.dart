/// Helper used by every provider's `init()` to decide whether a Hive error
/// is genuinely unrecoverable (a broken/incompatible on-disk schema) versus
/// a transient failure (e.g. a locked file, a momentary I/O hiccup).
///
/// Only unrecoverable errors should trigger `Hive.deleteBoxFromDisk(...)` —
/// deleting the box on any other error would silently wipe the user's data.
bool isUnrecoverableHiveError(Object e) {
  final msg = e.toString().toLowerCase();
  return msg.contains('unknown typeid') ||
      msg.contains('cannot read, unknown') ||
      msg.contains('adapter') ||
      msg.contains('corrupt');
}
