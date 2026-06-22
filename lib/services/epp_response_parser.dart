import 'package:xml/xml.dart';

class DomainInfo {
  final String name;
  final List<String> statuses;
  final String? registrant;
  final String? adminContact;
  final String? techContact;
  final List<String> nameservers;
  final String? crDate;
  final String? exDate;

  DomainInfo({
    required this.name,
    required this.statuses,
    this.registrant,
    this.adminContact,
    this.techContact,
    required this.nameservers,
    this.crDate,
    this.exDate,
  });
}

class EppResponse {
  final XmlDocument _doc;
  final String raw;

  EppResponse(this.raw) : _doc = XmlDocument.parse(raw);

  int? get code {
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

  bool get isGreeting {
    final greeting = _doc.findAllElements('greeting', namespace: '*');
    return greeting.isNotEmpty;
  }

  // возвращает домен свободен
  Map<String, bool> domainAvailability() {
    final result = <String, bool>{};
    final tags = _doc.findAllElements('name', namespace: '*');
    for (final el in tags) {
      final avail = el.getAttribute('avail');
      if (avail == null) continue;
      final isAvailable = avail == '1' || avail == 'true';
      final name = el.innerText.trim();
      result[name] = isAvailable;
    }
    return result;
  }

  // Для domain:info — разбирает детальные данные
  DomainInfo? parseDomainInfo() {
    final infData = _doc.findAllElements('infData', namespace: '*').firstOrNull;
    if (infData == null) return null;

    // Имя домена
    final nameEl = infData.findAllElements('name', namespace: '*').firstOrNull;
    final name = nameEl?.innerText.trim() ?? '';

    // Статусы — может быть несколько <domain:status s="ok"/>
    final statuses = infData
        .findAllElements('status', namespace: '*')
        .map((e) => e.getAttribute('s') ?? e.innerText.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Регистрант
    final registrantEl = infData
        .findAllElements('registrant', namespace: '*')
        .firstOrNull;
    final registrant = registrantEl?.innerText.trim();

    // Контакты admin / tech
    String? adminContact;
    String? techContact;
    for (final el in infData.findAllElements('contact', namespace: '*')) {
      final type = el.getAttribute('type');
      if (type == 'admin') adminContact = el.innerText.trim();
      if (type == 'tech') techContact = el.innerText.trim();
    }

    // Неймсерверы
    final nameservers = infData
        .findAllElements('hostObj', namespace: '*')
        .map((e) => e.innerText.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Даты
    final crDateEl = infData
        .findAllElements('crDate', namespace: '*')
        .firstOrNull;
    final exDateEl = infData
        .findAllElements('exDate', namespace: '*')
        .firstOrNull;
    String? crDate = crDateEl?.innerText.trim();
    String? exDate = exDateEl?.innerText.trim();

    // Обрезаем до даты если есть время
    crDate = _formatDate(crDate);
    exDate = _formatDate(exDate);

    return DomainInfo(
      name: name,
      statuses: statuses,
      registrant: registrant,
      adminContact: adminContact,
      techContact: techContact,
      nameservers: nameservers,
      crDate: crDate,
      exDate: exDate,
    );
  }

  String? _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;

    if (raw.length > 10 && raw.contains('T')) {
      return raw.substring(0, 10);
    }
    return raw;
  }

  // Для domain:create — извлекаем svTRID
  String? get svTRID {
    final el = _doc.findAllElements('svTRID', namespace: '*').firstOrNull;
    return el?.innerText.trim();
  }
}
