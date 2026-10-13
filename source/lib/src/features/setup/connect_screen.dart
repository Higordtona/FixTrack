import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/session.dart';
import '../../core/theme.dart';
import '../../server/discovery.dart';
import '../../widgets/common.dart';

/// الجهاز بيدوّر على سيرفر المحل في الواي فاي، أو المستخدم يكتب العنوان بإيده.
class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> {
  final _address = TextEditingController();
  List<DiscoveredServer>? _found;
  bool _searching = false;
  String? _connectingTo;
  String? _error;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _searching = true;
      _error = null;
    });
    List<DiscoveredServer> found;
    try {
      found = await discoverServers();
    } catch (_) {
      found = [];
    }
    if (!mounted) return;
    setState(() {
      _found = found;
      _searching = false;
    });
  }

  Future<void> _connect(String url) async {
    if (url.trim().isEmpty) {
      setState(() => _error = 'Digite o endereço do servidor primeiro');
      return;
    }
    setState(() {
      _connectingTo = url;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).connectTo(url);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _connectingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final found = _found ?? const [];

    return CenteredPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const FixTrackLogo(size: 56),
          const SizedBox(height: 24),
          Text('Conectar ao servidor da loja', style: text.titleLarge?.bold),
          const SizedBox(height: 4),
          Text('Verifique se este dispositivo está na mesma rede Wi-Fi da loja e se o programa está aberto no computador principal.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text('Servidores encontrados', style: text.titleSmall?.bold)),
              TextButton.icon(
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Buscar novamente'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_searching)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Procurando servidores na rede...'),
                ]),
              ),
            )
          else if (found.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Nenhum servidor encontrado. Verifique o Wi-Fi ou informe o endereço abaixo '
                  '(no computador: Configurações → Conexão).',
                  style: text.bodyMedium,
                ),
              ),
            )
          else
            for (final s in found)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(Icons.storefront_rounded, color: scheme.onPrimaryContainer),
                    ),
                    title: Text(s.shopName.isEmpty ? 'Nova loja (ainda não cadastrada)' : s.shopName, style: text.titleSmall?.bold),
                    subtitle: Text([if (s.branchName.isNotEmpty) s.branchName, Uri.parse(s.url).host].join(' • ')),
                    trailing: _connectingTo == s.url
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _connectingTo == null ? () => _connect(s.url) : null,
                  ),
                ),
              ),
          const SizedBox(height: 20),
          Text('Ou digite o endereço manualmente', style: text.titleSmall?.bold),
          const SizedBox(height: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: TextField(
              controller: _address,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(hintText: '192.168.1.10', prefixIcon: Icon(Icons.lan_rounded)),
              onSubmitted: _connect,
            ),
          ),
          const SizedBox(height: 12),
          BusyButton(
            label: 'Conectar',
            busy: _connectingTo == _address.text && _connectingTo != null,
            onPressed: _connectingTo == null ? () => _connect(_address.text) : null,
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorBanner(_error!)],
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => ref.read(sessionProvider.notifier).resetConnection(),
            child: const Text('Voltar'),
          ),
        ],
      ),
    );
  }
}
