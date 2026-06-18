import 'dart:io';
import 'dart:async';
import 'epp_frame_buffer.dart';
import 'epp_xml_builder.dart';
import 'epp_response_parser.dart';

class EppClient {
  SecureSocket? _socket;
  StreamSubscription<List<int>>? _sub;
  Timer? _keepAlive;

  final _buf = EppFrameBuffer();

  // Очередь completers — каждая отправленная команда кладёт сюда
  // completer и ждёт, пока _onData не достанет следующий ответ.
  // Работает только потому что EPP — строго request/response,
  // сервер не шлёт ничего сам (кроме greeting при коннекте).
  final _queue = <Completer<EppResponse>>[];

  bool get connected => _socket != null;

  Future<EppResponse> connect(String host, int port) async {
    _socket = await SecureSocket.connect(
      host,
      port,
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 10),
    );

    _sub = _socket!.listen(_onData, onError: _onErr, onDone: _onDone);

    // Сервер сам шлёт greeting сразу после коннекта — ждём его
    final greeting = _nextResponse();

    // Keep-alive: hello каждые 4 минуты.
    // Сервер рвёт сессию примерно через 10 мин без активности.
    _keepAlive = Timer.periodic(const Duration(minutes: 4), (_) {
      if (connected) _send(EppXmlBuilder.hello());
    });

    return greeting;
  }

  Future<EppResponse> login(String clId, String pw) {
    return _sendWait(EppXmlBuilder.login(clId: clId, pw: pw));
  }

  Future<EppResponse> domainCheck(List<String> names) {
    return _sendWait(EppXmlBuilder.domainCheck(names));
  }

  Future<EppResponse> domainCreate({
    required String name,
    required String registrant,
    required String authPw,
    List<String> ns = const [],
  }) {
    return _sendWait(EppXmlBuilder.domainCreate(
      name: name,
      registrant: registrant,
      authPw: authPw,
      ns: ns,
    ));
  }

  Future<EppResponse> logout() async {
    final r = await _sendWait(EppXmlBuilder.logout());
    close();
    return r;
  }

  void _send(String xml) {
    _socket?.add(EppFrameBuffer.wrap(xml));
  }

  Future<EppResponse> _sendWait(String xml) {
    _send(xml);
    return _nextResponse();
  }

  Future<EppResponse> _nextResponse() {
    final c = Completer<EppResponse>();
    _queue.add(c);
    // 30 секунд — с запасом, обычно сервер отвечает за <1 сек
    return c.future.timeout(const Duration(seconds: 30));
  }

  void _onData(List<int> bytes) {
    final frames = _buf.addBytes(bytes);
    for (final xml in frames) {
      final resp = EppResponse(xml);
      if (_queue.isNotEmpty) {
        _queue.removeAt(0).complete(resp);
      }
    }
  }

  void _onErr(Object e) {
    for (final c in _queue) {
      c.completeError(e);
    }
    _queue.clear();
    close();
  }

  void _onDone() {
    for (final c in _queue) {
      c.completeError(StateError('connection closed'));
    }
    _queue.clear();
    close();
  }

  void close() {
    _keepAlive?.cancel();
    _sub?.cancel();
    _socket?.destroy();
    _socket = null;
  }
}
