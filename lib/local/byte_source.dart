import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Random access, async byte reader used by the tag probes, so a large file
/// is never read whole (an M4A keeps its metadata at the end, a FLAC picture
/// sits between header blocks...).
abstract class ByteSource {
  int get length;

  /// Reads up to [count] bytes at [offset]; shorter at the end of the data.
  Future<Uint8List> read(int offset, int count);

  Future<void> close();
}

/// [ByteSource] over a file opened with [RandomAccessFile].
class FileByteSource implements ByteSource {
  FileByteSource._(this._file, this.length);

  final RandomAccessFile _file;

  @override
  final int length;

  static Future<FileByteSource> open(String path) async {
    final file = await File(path).open();
    try {
      return FileByteSource._(file, await file.length());
    } on Object {
      await file.close();
      rethrow;
    }
  }

  @override
  Future<Uint8List> read(int offset, int count) async {
    if (offset >= length || count <= 0) return Uint8List(0);
    await _file.setPosition(offset);
    return _file.read(math.min(count, length - offset));
  }

  @override
  Future<void> close() => _file.close();
}

/// [ByteSource] over bytes in memory (tests, small buffers).
class MemoryByteSource implements ByteSource {
  MemoryByteSource(this._bytes);

  final Uint8List _bytes;

  @override
  int get length => _bytes.length;

  @override
  Future<Uint8List> read(int offset, int count) async {
    if (offset >= _bytes.length || count <= 0) return Uint8List(0);
    final end = math.min(_bytes.length, offset + count);
    return Uint8List.sublistView(_bytes, offset, end);
  }

  @override
  Future<void> close() async {}
}

/// Big / little endian helpers over a byte list.
extension BytesRead on List<int> {
  int u16be(int at) => (this[at] << 8) | this[at + 1];
  int u24be(int at) => (this[at] << 16) | (this[at + 1] << 8) | this[at + 2];
  int u32be(int at) =>
      (this[at] << 24) |
      (this[at + 1] << 16) |
      (this[at + 2] << 8) |
      this[at + 3];
  int u64be(int at) => (u32be(at) * 0x100000000) + u32be(at + 4);
  int u16le(int at) => this[at] | (this[at + 1] << 8);
  int u32le(int at) =>
      this[at] |
      (this[at + 1] << 8) |
      (this[at + 2] << 16) |
      (this[at + 3] << 24);

  /// ID3v2 "syncsafe" integer (7 bits per byte).
  int syncsafe(int at) =>
      ((this[at] & 0x7F) << 21) |
      ((this[at + 1] & 0x7F) << 14) |
      ((this[at + 2] & 0x7F) << 7) |
      (this[at + 3] & 0x7F);

  /// Whether the bytes at [at] spell [ascii].
  bool matches(int at, String ascii) {
    if (at < 0 || at + ascii.length > length) return false;
    for (var i = 0; i < ascii.length; i++) {
      if (this[at + i] != ascii.codeUnitAt(i)) return false;
    }
    return true;
  }
}

/// Byte writer helpers.
class ByteWriter {
  final BytesBuilder _builder = BytesBuilder(copy: false);

  int get length => _builder.length;

  void bytes(List<int> data) => _builder.add(data);
  void byte(int value) => _builder.addByte(value & 0xFF);
  void ascii(String text) => _builder.add(text.codeUnits);

  void u16be(int v) => bytes([(v >> 8) & 0xFF, v & 0xFF]);
  void u24be(int v) => bytes([(v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);
  void u32be(int v) =>
      bytes([(v >> 24) & 0xFF, (v >> 16) & 0xFF, (v >> 8) & 0xFF, v & 0xFF]);
  void u32le(int v) =>
      bytes([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);
  void syncsafe(int v) =>
      bytes([(v >> 21) & 0x7F, (v >> 14) & 0x7F, (v >> 7) & 0x7F, v & 0x7F]);

  Uint8List take() => _builder.takeBytes();
}
