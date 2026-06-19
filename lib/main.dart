import 'package:flutter/material.dart';
import 'services/epp_client.dart';
import 'services/epp_response_parser.dart';

void main() {
  runApp(const MaterialApp(home: ConnectScreen()));
}

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _hostCtrl = TextEditingController(text: 'testepp.nic.kz');
  final _portCtrl = TextEditingController(text: '3121');
  final _clIdCtrl = TextEditingController(text: 'kaznic-test');
  final _pwCtrl = TextEditingController(text: '1234567');
  final _client = EppClient();
  bool _loading = false;

  @override
  void dispose() {
    // _client.close();
    super.dispose();
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      final greeting = await _client.connect(
        _hostCtrl.text,
        int.parse(_portCtrl.text),
      );

      if (!greeting.isGreeting) {
        _snack('Странный ответ от сервера: ${greeting.raw.substring(0, 80)}');
        return;
      }

      if (_clIdCtrl.text.isNotEmpty) {
        final loginResp = await _client.login(_clIdCtrl.text, _pwCtrl.text);
        if (!loginResp.ok) {
          _snack('Ошибка входа: ${loginResp.message}');
          return;
        }
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => DomainsScreen(client: _client)),
      );
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EPP Client')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                  flex: 3,
                  child: TextField(
                      controller: _hostCtrl,
                      decoration: const InputDecoration(labelText: 'Host'))),
              const SizedBox(width: 8),
              Expanded(
                  child: TextField(
                      controller: _portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port'))),
            ]),
            const SizedBox(height: 12),
            TextField(
                controller: _clIdCtrl,
                decoration: const InputDecoration(labelText: 'Login')),
            TextField(
                controller: _pwCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password')),
            const SizedBox(height: 24),
            if (_loading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                  onPressed: _connect, child: const Text('Подключиться')),
          ],
        ),
      ),
    );
  }
}

class DomainsScreen extends StatefulWidget {
  final EppClient client;
  const DomainsScreen({super.key, required this.client});

  @override
  State<DomainsScreen> createState() => _DomainsScreenState();
}

class _DomainsScreenState extends State<DomainsScreen> {
  final _ctrl = TextEditingController();
  bool _loading = false;
  // null = ещё не проверяли, иначе результат check
  Map<String, bool>? _results;

  Future<void> _check() async {
    final names = _ctrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (names.isEmpty) return;

    setState(() {
      _loading = true;
      _results = null;
    });

    try {
      final resp = await widget.client.domainCheck(names);
      if (!resp.ok) {
        _snack('Ошибка: ${resp.message}');
        return;
      }
      setState(() => _results = resp.domainAvailability());
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Домены'),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.client.logout();
              if (!context.mounted) return;
              Navigator.pushReplacement(context,
                  MaterialPageRoute(builder: (_) => const ConnectScreen()));
            },
            child: const Text('Выход'),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Домены',
                hintText: 'example.com, test.kz',
              ),
            ),
            const SizedBox(height: 12),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                onPressed: _check, child: const Text('Проверить')),
            const SizedBox(height: 16),
            if (_results != null)
              Expanded(
                child: ListView(
                  children: [
                    for (final e in _results!.entries)
                      ListTile(
                        leading: Icon(
                          e.value ? Icons.check_circle_outline : Icons.cancel_outlined,
                          color: e.value ? Colors.green : Colors.red,
                        ),
                        title: Text(e.key),
                        subtitle: Text(e.value ? 'свободен' : 'занят'),
                      )
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
