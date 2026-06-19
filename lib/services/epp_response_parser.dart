import 'package:xml/xml.dart';

class EppResponse {
  final XmlDocument _doc;
  final String raw;

  EppResponse(this.raw) : _doc = XmlDocument.parse(raw);

  int? get code {
    // Добавил поиск по всем namespace (*), иначе epp:result не находился
    final el = _doc.findAllElements('result', namespace: '*').firstOrNull;
    if (el == null) return null;

    final attr = el.getAttribute('code');
    if (attr == null) return null;

    return int.tryParse(attr);
  }

  String? get message {
    final msgEl = _doc.findAllElements('msg', namespace: '*').firstOrNull;
    return msgEl?.innerText;
  }

  bool get ok {
    final status = code;
    if (status == null) return false;
    return status >= 1000 && status < 2000;
  }

  // Возвращает {domainName: доступен} из  domain:check
  Map<String, bool> domainAvailability() {
    final result = <String, bool>{};

    // Сервер присылает 'domain:name', поэтому обычный 'name' ничего не находил.
    final tags = _doc.findAllElements('name', namespace: '*');

    for (final el in tags) {
      final avail = el.getAttribute('avail');
      if (avail == null) continue;

      // На всякий случай проверяем и '1', и 'true', мало ли что сервер выкинет
      bool isAvailable = false;
      if (avail == '1' || avail == 'true') {
        isAvailable = true;
      }

      final name = el.innerText.trim();
      result[name] = isAvailable;
    }
    return result;
  }

  bool get isGreeting {
    // Проверка на приветственное сообщение от сервера
    final greeting = _doc.findAllElements('greeting', namespace: '*');
    return greeting.isNotEmpty;
  }
}