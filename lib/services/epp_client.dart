import 'dart:io';
import 'dart:async';
import 'epp_frame_buffer.dart';
import 'epp_xml_builder.dart';
import 'epp_response_parser.dart';

class EppClient {
  Socket? _socket;
  StreamSubscription<List<int>>? _sub;
  Timer? _keepAlive;

  final _buf = EppFrameBuffer();
  final _queue = <Completer<EppResponse>>[];

  bool get connected => _socket != null;

  Future<EppResponse> connect(String host, int port) async {
    print('[EPP] connecting to $host:$port');
    _socket = await Socket.connect(host, port, timeout: const Duration(seconds: 10));
    print('[EPP] socket connected');
    _sub = _socket!.listen(_onData, onError: _onErr, onDone: _onDone);
    final greeting = _nextResponse();
    _keepAlive = Timer.periodic(const Duration(minutes: 4), (_) async {
      if (!connected) return;
      try {
        final resp = await _sendWait(EppXmlBuilder.pollReq());
        if (resp.code == 1301) {
          final msgId = _extractMsgId(resp.raw);
          if (msgId != null) await _sendWait(EppXmlBuilder.pollAck(msgId));
        }
      } catch (_) {}
    });
    return greeting;
  }

  Future<EppResponse> login(String clId, String pw) {
    return _sendWait(EppXmlBuilder.login(clId: clId, pw: pw));
  }

  Future<EppResponse> domainCheck(List<String> names) {
    return _sendWait(EppXmlBuilder.domainCheck(names));
  }

  Future<EppResponse> domainInfo(String name) {
    return _sendWait(EppXmlBuilder.domainInfo(name));
  }

  Future<EppResponse> contactInfo(String contactId) {
    return _sendWait(EppXmlBuilder.contactInfo(contactId));
  }

  Future<EppResponse> contactCreate({required String contactId}) {
    return _sendWait(EppXmlBuilder.contactCreate(contactId: contactId));
  }

  Future<EppResponse> domainCreate({
    required String name,
    required String authPw,
    required String registrant,
    required String adminContact,
    required String techContact,
    int periodYears = 1,
  }) {
    return _sendWait(EppXmlBuilder.domainCreate(
      name: name,
      authPw: authPw,
      registrant: registrant,
      adminContact: adminContact,
      techContact: techContact,
      periodYears: periodYears,
    ));
  }

  Future<EppResponse> logout() async {
    final r = await _sendWait(EppXmlBuilder.logout());
    close();
    return r;
  }

  void _send(String xml) {
    print('[EPP SEND] ${xml.substring(0, xml.length.clamp(0, 150))}');
    _socket?.add(EppFrameBuffer.wrap(xml));
  }

  Future<EppResponse> _sendWait(String xml) {
    _send(xml);
    return _nextResponse();
  }

  Future<EppResponse> _nextResponse() {
    final c = Completer<EppResponse>();
    _queue.add(c);
    return c.future.timeout(const Duration(seconds: 30));
  }

  void _onData(List<int> bytes) {
    print('[EPP RECV] ${bytes.length} bytes');
    _buf.addBytes(bytes).forEach((xml) {
      final parts = RegExp(r'.{1,600}').allMatches(xml).map((m) => m.group(0)!).toList();
      for (var i = 0; i < parts.length; i++) {
        print('[FRAME $i] ${parts[i]}');
      }
      final resp = EppResponse(xml);
      if (_queue.isNotEmpty) _queue.removeAt(0).complete(resp);
    });
  }

  void _onErr(Object e) {
    print('[EPP ERR] $e');
    for (final c in _queue) c.completeError(e);
    _queue.clear();
    close();
  }

  void _onDone() {
    print('[EPP DONE] server closed connection');
    for (final c in _queue) c.completeError(StateError('connection closed'));
    _queue.clear();
    close();
  }

  void close() {
    _keepAlive?.cancel();
    _sub?.cancel();
    _socket?.destroy();
    _socket = null;
  }

  String? _extractMsgId(String raw) {
    final m = RegExp(r'msgID="([^"]+)"').firstMatch(raw);
    return m?.group(1);
  }
}