import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Reads NumPy .npz files (zip archives of .npy arrays).
class NpzReader {
  final Map<String, Float32List> _arrays;

  NpzReader._(this._arrays);

  /// Load an .npz file from disk.
  factory NpzReader.load(String path) {
    final bytes = File(path).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);
    final arrays = <String, Float32List>{};

    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('.npy', '');
      arrays[name] = _parseNpy(file.content as List<int>);
    }

    return NpzReader._(arrays);
  }

  /// Get array by name.
  Float32List? operator [](String name) => _arrays[name];

  /// Available array names.
  Iterable<String> get keys => _arrays.keys;

  /// Parse a .npy file into a flat Float32List.
  static Float32List _parseNpy(List<int> data) {
    final bytes = Uint8List.fromList(data);

    // .npy format: 6-byte magic + 2-byte version + 2-byte header length + header
    // Magic: \x93NUMPY
    if (bytes[0] != 0x93 ||
        bytes[1] != 0x4E ||
        bytes[2] != 0x55 ||
        bytes[3] != 0x4D) {
      throw const FormatException('Not a valid .npy file');
    }

    final major = bytes[6];
    final int headerLen;
    final int headerStart;

    if (major == 1) {
      headerLen = ByteData.sublistView(bytes).getUint16(8, Endian.little);
      headerStart = 10;
    } else {
      headerLen = ByteData.sublistView(bytes).getUint32(8, Endian.little);
      headerStart = 12;
    }

    final dataStart = headerStart + headerLen;
    return Float32List.sublistView(bytes, dataStart);
  }
}
