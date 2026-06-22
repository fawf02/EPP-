import 'package:xml/xml.dart';

const _epp = 'urn:ietf:params:xml:ns:epp-1.0';
const _domain = 'urn:ietf:params:xml:ns:domain-1.0';
const _contact = 'urn:ietf:params:xml:ns:contact-1.0';
const _contactExt = 'urn:kaznic:params:xml:ns:contact-ext-1.0';

class EppXmlBuilder {
  static String pollReq() =>
      _wrap(XmlElement(XmlName('poll'), [XmlAttribute(XmlName('op'), 'req')]));

  static String pollAck(String id) => _wrap(
    XmlElement(XmlName('poll'), [
      XmlAttribute(XmlName('op'), 'ack'),
      XmlAttribute(XmlName('msgID'), id),
    ]),
  );

  static String login({required String clId, required String pw}) {
    return _wrap(
      XmlElement(XmlName('login'), [], [
        XmlElement(XmlName('clID'), [], [XmlText(clId)]),
        XmlElement(XmlName('pw'), [], [XmlText(pw)]),
        XmlElement(XmlName('options'), [], [
          XmlElement(XmlName('version'), [], [XmlText('1.0')]),
          XmlElement(XmlName('lang'), [], [XmlText('en')]),
        ]),
        XmlElement(XmlName('svcs'), [], [
          XmlElement(XmlName('objURI'), [], [XmlText(_domain)]),
          XmlElement(XmlName('objURI'), [], [XmlText(_contact)]),
          XmlElement(XmlName('svcExtension'), [], [
            XmlElement(XmlName('extURI'), [], [XmlText(_contactExt)]),
          ]),
        ]),
      ]),
    );
  }

  static String logout() => _wrap(XmlElement(XmlName('logout')));

  static String domainCheck(List<String> names) {
    return _wrap(
      XmlElement(XmlName('check'), [], [
        XmlElement(
          XmlName('check', 'domain'),
          [XmlAttribute(XmlName('xmlns:domain'), _domain)],
          names
              .map((n) => XmlElement(XmlName('name', 'domain'), [], [XmlText(n)]))
              .toList(),
        ),
      ]),
    );
  }

  static String domainInfo(String name) {
    return _wrap(
      XmlElement(XmlName('info'), [], [
        XmlElement(
          XmlName('info', 'domain'),
          [XmlAttribute(XmlName('xmlns:domain'), _domain)],
          [XmlElement(XmlName('name', 'domain'), [], [XmlText(name)])],
        ),
      ]),
    );
  }

  static String contactInfo(String contactId) {
    return _wrap(
      XmlElement(XmlName('info'), [], [
        XmlElement(
          XmlName('info', 'contact'),
          [XmlAttribute(XmlName('xmlns:contact'), _contact)],
          [
            XmlElement(XmlName('id', 'contact'), [], [XmlText(contactId)]),
            XmlElement(XmlName('authInfo', 'contact'), [], [
              XmlElement(XmlName('pw', 'contact'), [], [XmlText('')]),
            ]),
          ],
        ),
      ]),
    );
  }

  // Создание контакта с расширением contact-ext (residenceDetails)
  // Согласно спецификации KazNIC contact-ext-1.0
  static String contactCreate({required String contactId}) {
    final doc = XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="no"'),
      XmlElement(
        XmlName('epp'),
        [XmlAttribute(XmlName('xmlns'), _epp)],
        [
          XmlElement(XmlName('command'), [], [
            XmlElement(XmlName('create'), [], [
              XmlElement(
                XmlName('create', 'contact'),
                [XmlAttribute(XmlName('xmlns:contact'), _contact)],
                [
                  XmlElement(XmlName('id', 'contact'), [], [XmlText(contactId)]),
                  XmlElement(
                    XmlName('postalInfo', 'contact'),
                    [XmlAttribute(XmlName('type'), 'int')],
                    [
                      XmlElement(XmlName('name', 'contact'), [], [XmlText('Test User')]),
                      XmlElement(XmlName('org', 'contact'), [], [XmlText('Test Org')]),
                      XmlElement(XmlName('addr', 'contact'), [], [
                        XmlElement(XmlName('street', 'contact'), [], [XmlText('Street 1')]),
                        XmlElement(XmlName('city', 'contact'), [], [XmlText('Almaty')]),
                        XmlElement(XmlName('sp', 'contact'), [], [XmlText('AL')]),
                        XmlElement(XmlName('pc', 'contact'), [], [XmlText('050000')]),
                        XmlElement(XmlName('cc', 'contact'), [], [XmlText('KZ')]),
                      ]),
                    ],
                  ),
                  XmlElement(XmlName('voice', 'contact'), [], [XmlText('+7.7777777777')]),
                  XmlElement(XmlName('email', 'contact'), [], [XmlText('test@example.com')]),
                  XmlElement(XmlName('authInfo', 'contact'), [], [
                    XmlElement(XmlName('pw', 'contact'), [], [XmlText('123456')]),
                  ]),
                ],
              ),
            ]),
            // расширение согласно спецификации contact-ext-1.0
            XmlElement(XmlName('extension'), [], [
              XmlElement(
                XmlName('create', 'contact-ext'),
                [XmlAttribute(XmlName('xmlns:contact-ext'), _contactExt)],
                [
                  XmlElement(
                    XmlName('residenceDetails', 'contact-ext'),
                    [XmlAttribute(XmlName('country'), 'KZ')],
                    [
                      XmlElement(XmlName('externalIdType', 'contact-ext'), [], [XmlText('IIN')]),
                      XmlElement(XmlName('externalIdValue', 'contact-ext'), [], [XmlText('123456789012')]),
                    ],
                  ),
                ],
              ),
            ]),
            XmlElement(XmlName('clTRID'), [], [
              XmlText('APP-${DateTime.now().millisecondsSinceEpoch}'),
            ]),
          ]),
        ],
      ),
    ]);
    return doc.toXmlString();
  }

  static String domainCreate({
    required String name,
    required String authPw,
    required String registrant,
    required String adminContact,
    required String techContact,
    int periodYears = 1,
    List<String> ns = const ['ns1.nic.kz', 'ns2.nic.kz'],
  }) {
    return _wrap(
      XmlElement(XmlName('create'), [], [
        XmlElement(
          XmlName('create', 'domain'),
          [XmlAttribute(XmlName('xmlns:domain'), _domain)],
          [
            XmlElement(XmlName('name', 'domain'), [], [XmlText(name)]),
            XmlElement(
              XmlName('period', 'domain'),
              [XmlAttribute(XmlName('unit'), 'y')],
              [XmlText('$periodYears')],
            ),
            XmlElement(
              XmlName('ns', 'domain'),
              [],
              ns.map((h) => XmlElement(XmlName('hostObj', 'domain'), [], [XmlText(h)])).toList(),
            ),
            XmlElement(XmlName('registrant', 'domain'), [], [XmlText(registrant)]),
            XmlElement(
              XmlName('contact', 'domain'),
              [XmlAttribute(XmlName('type'), 'admin')],
              [XmlText(adminContact)],
            ),
            XmlElement(
              XmlName('contact', 'domain'),
              [XmlAttribute(XmlName('type'), 'tech')],
              [XmlText(techContact)],
            ),
            XmlElement(XmlName('authInfo', 'domain'), [], [
              XmlElement(XmlName('pw', 'domain'), [], [XmlText(authPw)]),
            ]),
          ],
        ),
      ]),
    );
  }

  static String _wrap(XmlElement child) {
    final doc = XmlDocument([
      XmlProcessing('xml', 'version="1.0" encoding="UTF-8" standalone="no"'),
      XmlElement(
        XmlName('epp'),
        [XmlAttribute(XmlName('xmlns'), _epp)],
        [
          XmlElement(XmlName('command'), [], [
            child,
            XmlElement(XmlName('clTRID'), [], [
              XmlText('APP-${DateTime.now().millisecondsSinceEpoch}'),
            ]),
          ]),
        ],
      ),
    ]);
    return doc.toXmlString();
  }
}