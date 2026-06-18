import 'package:xml/xml.dart';

// Строим XML через дерево, а не склейкой строк — иначе namespace'ы
// расставляются неправильно и сервер отвечает 2001 (unknown command).
// Убедился на своих граблях с domain:check.

const _eppNs = 'urn:ietf:params:xml:ns:epp-1.0';
const _domainNs = 'urn:ietf:params:xml:ns:domain-1.0';

class EppXmlBuilder {
  static String hello() {
    final doc = XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="no"'),
      XmlElement(XmlName('epp'), [XmlAttribute(XmlName('xmlns'), _eppNs)], [
        XmlElement(XmlName('hello')),
      ]),
    ]);
    return doc.toXmlString();
  }

  static String login({required String clId, required String pw}) {
    final trid = _trid();
    final doc = XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="no"'),
      XmlElement(XmlName('epp'), [XmlAttribute(XmlName('xmlns'), _eppNs)], [
        XmlElement(XmlName('command'), [], [
          XmlElement(XmlName('login'), [], [
            XmlElement(XmlName('clID'), [], [XmlText(clId)]),
            XmlElement(XmlName('pw'), [], [XmlText(pw)]),
            XmlElement(XmlName('options'), [], [
              XmlElement(XmlName('version'), [], [XmlText('1.0')]),
              XmlElement(XmlName('lang'), [], [XmlText('en')]),
            ]),
            XmlElement(XmlName('svcs'), [], [
              XmlElement(XmlName('objURI'), [], [XmlText(_domainNs)]),
              XmlElement(XmlName('objURI'), [],
                  [XmlText('urn:ietf:params:xml:ns:host-1.0')]),
              XmlElement(XmlName('objURI'), [],
                  [XmlText('urn:ietf:params:xml:ns:contact-1.0')]),
            ]),
          ]),
          XmlElement(XmlName('clTRID'), [], [XmlText(trid)]),
        ]),
      ]),
    ]);
    return doc.toXmlString();
  }

  static String logout() {
    final doc = XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="no"'),
      XmlElement(XmlName('epp'), [XmlAttribute(XmlName('xmlns'), _eppNs)], [
        XmlElement(XmlName('command'), [], [
          XmlElement(XmlName('logout')),
          XmlElement(XmlName('clTRID'), [], [XmlText(_trid())]),
        ]),
      ]),
    ]);
    return doc.toXmlString();
  }

  static String domainCheck(List<String> names) {
    final nameElements = names
        .map((n) => XmlElement(
              XmlName('name', 'domain'),
              [],
              [XmlText(n)],
            ))
        .toList();

    final doc = XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="no"'),
      XmlElement(XmlName('epp'), [XmlAttribute(XmlName('xmlns'), _eppNs)], [
        XmlElement(XmlName('command'), [], [
          XmlElement(XmlName('check'), [], [
            XmlElement(
              XmlName('check', 'domain'),
              [XmlAttribute(XmlName('xmlns:domain'), _domainNs)],
              nameElements,
            ),
          ]),
          XmlElement(XmlName('clTRID'), [], [XmlText(_trid())]),
        ]),
      ]),
    ]);
    return doc.toXmlString();
  }

  static String domainCreate({
    required String name,
    required String registrant,
    required String authPw,
    int periodYears = 1,
    List<String> ns = const [],
  }) {
    final nsEl = ns.isEmpty
        ? null
        : XmlElement(XmlName('ns', 'domain'), [], [
            for (final h in ns)
              XmlElement(XmlName('hostObj', 'domain'), [], [XmlText(h)])
          ]);

    final children = [
      XmlElement(XmlName('name', 'domain'), [], [XmlText(name)]),
      XmlElement(XmlName('period', 'domain'),
          [XmlAttribute(XmlName('unit'), 'y')], [XmlText('$periodYears')]),
      if (nsEl != null) nsEl,
      XmlElement(XmlName('registrant', 'domain'), [], [XmlText(registrant)]),
      XmlElement(XmlName('authInfo', 'domain'), [], [
        XmlElement(XmlName('pw', 'domain'), [], [XmlText(authPw)]),
      ]),
    ];

    final doc = XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="no"'),
      XmlElement(XmlName('epp'), [XmlAttribute(XmlName('xmlns'), _eppNs)], [
        XmlElement(XmlName('command'), [], [
          XmlElement(XmlName('create'), [], [
            XmlElement(
              XmlName('create', 'domain'),
              [XmlAttribute(XmlName('xmlns:domain'), _domainNs)],
              children,
            ),
          ]),
          XmlElement(XmlName('clTRID'), [], [XmlText(_trid())]),
        ]),
      ]),
    ]);
    return doc.toXmlString();
  }

  static String _trid() => 'APP-${DateTime.now().millisecondsSinceEpoch}';
}
