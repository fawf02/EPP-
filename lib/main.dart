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

  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      final greeting = await _client.connect(
        _hostCtrl.text,
        int.parse(_portCtrl.text),
      );
      if (!greeting.isGreeting) {
        _snack('Странный ответ от сервера');
        return;
      }

      final loginResp = await _client.login(_clIdCtrl.text, _pwCtrl.text);
      if (!loginResp.ok) {
        _snack('Ошибка входа: ${loginResp.message}');
        return;
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

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EPP Client')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _hostCtrl,
                    decoration: const InputDecoration(labelText: 'Host'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _portCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Port'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _clIdCtrl,
              decoration: const InputDecoration(labelText: 'Login'),
            ),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const CircularProgressIndicator()
            else
              ElevatedButton(
                onPressed: _connect,
                child: const Text('Подключиться'),
              ),
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

  Future<void> _openInfo(String domain) async {
    setState(() => _loading = true);
    try {
      final resp = await widget.client.domainInfo(domain);
      if (!mounted) return;
      if (!resp.ok) {
        _snack('Ошибка: ${resp.message}');
        return;
      }
      final info = resp.parseDomainInfo();
      if (info == null) {
        _snack('Не удалось разобрать ответ');
        return;
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DomainInfoScreen(info: info)),
      );
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ConnectScreen()),
              );
            },
            child: const Text('Выход', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CreateDomainScreen(client: widget.client),
          ),
        ),
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              decoration: const InputDecoration(
                labelText: 'Имя домена',
                hintText: 'example.kz, test.kz',
              ),
            ),
            const SizedBox(height: 12),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _check,
              child: const Text('Проверить'),
            ),
            const SizedBox(height: 16),
            if (_results != null)
              Expanded(
                child: ListView(
                  children: [
                    for (final e in _results!.entries)
                      ListTile(
                        leading: Icon(
                          e.value
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: e.value ? Colors.green : Colors.red,
                        ),
                        title: Text(e.key),
                        subtitle: Text(e.value ? 'Свободен' : 'Занят'),
                        trailing: e.value
                            ? null
                            : TextButton(
                          onPressed: () => _openInfo(e.key),
                          child: const Text('Подробнее'),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class DomainInfoScreen extends StatelessWidget {
  final DomainInfo info;
  const DomainInfoScreen({super.key, required this.info});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(info.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Статус', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (info.statuses.isEmpty)
            const Text('—')
          else
            Wrap(
              spacing: 6,
              children: [
                for (final s in info.statuses)
                  Chip(
                    label: Text(s),
                    backgroundColor: s == 'ok'
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                  ),
              ],
            ),
          const SizedBox(height: 16),
          const Text('Контакты', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _row('Registrant', info.registrant),
          _row('Admin', info.adminContact),
          _row('Tech', info.techContact),
          const SizedBox(height: 16),
          const Text('DNS-серверы', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (info.nameservers.isEmpty)
            const Text('—')
          else
            for (final ns in info.nameservers)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.dns, size: 16, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text(ns),
                  ],
                ),
              ),
          const SizedBox(height: 16),
          const Text('Даты', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          _row('Создан', info.crDate),
          _row('Истекает', info.exDate),
        ],
      ),
    );
  }

  Widget _row(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 100,
          child: Text('$label:', style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Text(value ?? '—')),
      ],
    ),
  );
}

class CreateDomainScreen extends StatefulWidget {
  final EppClient client;
  const CreateDomainScreen({super.key, required this.client});
  @override
  State<CreateDomainScreen> createState() => _CreateDomainScreenState();
}

class _CreateDomainScreenState extends State<CreateDomainScreen> {
  final _domainCtrl = TextEditingController();
  final _authCtrl = TextEditingController();
  int _years = 1;
  bool _loading = false;
  String? _resultMsg;
  bool _success = false;

  // захардкоженные контакты которые руководитель создал на сервере заранее
  static const _registrant   = 'Ali-reg';
  static const _adminContact = 'Ali-adm';
  static const _techContact  = 'Ali-tch';

  Future<void> _create() async {
    final domain = _domainCtrl.text.trim();
    final auth = _authCtrl.text.trim();
    if (domain.isEmpty || auth.isEmpty) {
      _snack('Заполните все поля');
      return;
    }

    setState(() {
      _loading = true;
      _resultMsg = null;
    });

    try {
      final resp = await widget.client.domainCreate(
        name: domain,
        authPw: auth,
        periodYears: _years,
        registrant: _registrant,
        adminContact: _adminContact,
        techContact: _techContact,
      );

      if (resp.ok) {
        setState(() {
          _success = true;
          _resultMsg = 'Домен зарегистрирован!\nsvTRID: ${resp.svTRID ?? "—"}';
        });
      } else {
        setState(() {
          _success = false;
          _resultMsg = 'Ошибка ${resp.code}: ${resp.message}';
        });
      }
    } catch (e) {
      setState(() {
        _success = false;
        _resultMsg = 'Ошибка: $e';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация домена')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _domainCtrl,
              decoration: const InputDecoration(
                labelText: 'Имя домена',
                hintText: 'mysite.kz',
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _authCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Auth-Info пароль'),
            ),
            const SizedBox(height: 20),
            const Text(
              'Срок регистрации',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final y in [1, 2, 3, 5])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('$y г.'),
                      selected: _years == y,
                      onSelected: (_) => setState(() => _years = y),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Контакты: Ali-reg / Ali-adm / Ali-tch',
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 24),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _create,
                child: const Text('Зарегистрировать'),
              ),
            if (_resultMsg != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _success ? Colors.green.shade50 : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _success ? Colors.green : Colors.red,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _success ? Icons.check_circle : Icons.error_outline,
                      color: _success ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _resultMsg!,
                        style: TextStyle(
                          color: _success
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}