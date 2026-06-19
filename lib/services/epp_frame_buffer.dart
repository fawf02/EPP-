import 'dart:convert';
import 'dart:typed_data';

// Разбив входящий поток байт на EPP-фреймы.
class EppFrameBuffer {
  final _buf = <int>[];

  List<String> addBytes(List<int> incoming) {
    _buf.addAll(incoming);

    final result = <String>[];

    while (_buf.length >= 4) {
      //  первые 4 байта = total length включая сам заголовок
      final total = ByteData.sublistView(Uint8List.fromList(_buf.sublist(0, 4)))
          .getUint32(0, Endian.big);


      if (total < 4 || total > 65536) {
        throw const FormatException('bad frame length');
      }

      if (_buf.length < total) break;

      final xmlBytes = _buf.sublist(4, total);
      _buf.removeRange(0, total);

      result.add(utf8.decode(xmlBytes));
    }

    return result;
  }

  static Uint8List wrap(String xml) {
    final body = utf8.encode(xml);
    final out = BytesBuilder();
    final header = ByteData(4)..setUint32(0, body.length + 4, Endian.big);
    out.add(header.buffer.asUint8List());
    out.add(body);
    return out.toBytes();
  }
}
