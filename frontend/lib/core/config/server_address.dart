import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

const _prefsKey = 'server_api_base_url';

/// Charge l'adresse du serveur enregistrée sur l'appareil, si elle existe.
Future<void> loadServerAddress() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved != null && saved.isNotEmpty) AppConfig.apiBaseUrl = saved;
  } catch (_) {
    // Préférences indisponibles (tests) : on garde la valeur par défaut.
  }
}

/// Enregistre une nouvelle adresse (null : revient à celle de la compilation).
Future<void> saveServerAddress(String? url) async {
  final prefs = await SharedPreferences.getInstance();
  if (url == null) {
    await prefs.remove(_prefsKey);
    AppConfig.apiBaseUrl = AppConfig.defaultApiBaseUrl;
  } else {
    await prefs.setString(_prefsKey, url);
    AppConfig.apiBaseUrl = url;
  }
}

/// Transforme une saisie libre en URL d'API complète :
/// `192.168.1.20` → `http://192.168.1.20:3001/api`,
/// `https://xyz.ngrok.app` → `https://xyz.ngrok.app/api`.
String normalizeServerAddress(String input) {
  var s = input.trim();
  if (s.isEmpty) return s;
  if (!s.startsWith('http://') && !s.startsWith('https://')) s = 'http://$s';
  var uri = Uri.parse(s);
  if (!uri.hasPort && uri.scheme == 'http') uri = uri.replace(port: 3001);
  var path = uri.path.replaceAll(RegExp(r'/+$'), '');
  if (!path.endsWith('/api')) path = '$path/api';
  return uri.replace(path: path).toString();
}

/// Vérifie que le serveur répond (route `/health` de l'API).
Future<bool> pingServer(String apiUrl) async {
  try {
    final root = apiUrl.replaceAll(RegExp(r'/api/?$'), '');
    final res = await Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
      ),
    ).get<dynamic>('$root/health');
    return res.statusCode == 200;
  } catch (_) {
    return false;
  }
}

/// Bouton « Serveur » affiché sur les écrans de connexion.
class ServerAddressButton extends StatelessWidget {
  const ServerAddressButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Adresse du serveur',
    icon: const Icon(Icons.dns_outlined),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => const _ServerAddressDialog(),
    ),
  );
}

class _ServerAddressDialog extends StatefulWidget {
  const _ServerAddressDialog();

  @override
  State<_ServerAddressDialog> createState() => _ServerAddressDialogState();
}

class _ServerAddressDialogState extends State<_ServerAddressDialog> {
  late final _controller = TextEditingController(text: AppConfig.apiBaseUrl);
  bool _busy = false;
  String? _message;
  bool _ok = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _test({bool save = false}) async {
    final url = normalizeServerAddress(_controller.text);
    if (url.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final ok = await pingServer(url);
    if (!mounted) return;
    if (ok && save) {
      await saveServerAddress(url);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Serveur enregistré : $url')));
      return;
    }
    setState(() {
      _busy = false;
      _ok = ok;
      _controller.text = url;
      _message = ok
          ? 'Serveur joignable ✔'
          : 'Serveur injoignable. Même Wi-Fi ? Pare-feu ouvert (port 3001) ?';
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adresse du serveur'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Saisissez l'IP du PC qui fait tourner le backend "
          '(ex. 192.168.1.20) ou une URL complète.',
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          keyboardType: TextInputType.url,
          autocorrect: false,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: '192.168.1.20',
          ),
        ),
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(
            _message!,
            style: TextStyle(color: _ok ? Colors.green : Colors.red),
          ),
        ],
      ],
    ),
    actions: [
      TextButton(
        onPressed: _busy
            ? null
            : () async {
                await saveServerAddress(null);
                setState(() => _controller.text = AppConfig.apiBaseUrl);
              },
        child: const Text('Par défaut'),
      ),
      TextButton(onPressed: _busy ? null : _test, child: const Text('Tester')),
      FilledButton(
        onPressed: _busy ? null : () => _test(save: true),
        child: _busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Enregistrer'),
      ),
    ],
  );
}
