import 'package:xml/xml.dart';


class EppResponse {
  final XmlDocument _doc;
  final String raw;

  EppResponse(this.raw) : _doc = XmlDocument.parse(raw);

  int? get code {
    final el = _doc.findAllElements('result').firstOrNull;
    final attr = el?.getAttribute('code');
    return attr != null ? int.tryParse(attr) : null;
  }

  String? get message {
    return _doc.findAllElements('msg').firstOrNull?.innerText;
  }

  bool get ok => (code ?? 0) >= 1000 && (code ?? 0) < 2000;

  // Возвращает {domainName: доступен} из ответа на domain:check
  Map<String, bool> domainAvailability() {
    final result = <String, bool>{};
    // namespace может быть объявлен по-разному, ищем по localName
    for (final el in _doc.findAllElements('name')) {
      final avail = el.getAttribute('avail');
      if (avail == null) continue;
      result[el.innerText.trim()] = avail == '1';
    }
    return result;
  }

  bool get isGreeting => _doc.findAllElements('greeting').isNotEmpty;
}
