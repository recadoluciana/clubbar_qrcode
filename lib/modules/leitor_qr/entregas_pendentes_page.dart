import 'package:flutter/material.dart';

import '../../core/services/api_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

class EntregasPendentesPage extends StatefulWidget {
  const EntregasPendentesPage({super.key});

  @override
  State<EntregasPendentesPage> createState() => _EntregasPendentesPageState();
}

class _EntregasPendentesPageState extends State<EntregasPendentesPage> {
  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _pedidos = const [];

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final resposta = await ApiService.listarEntregasPendentesMotoboy();
      final pedidos = resposta['pedidos'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _pedidos = pedidos
            .whereType<Map>()
            .map((pedido) => Map<String, dynamic>.from(pedido))
            .toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _tempoAguardando(Map<String, dynamic> pedido) {
    final minutos = int.tryParse('${pedido['tempo_espera_minutos'] ?? 0}') ?? 0;
    if (minutos < 60) return '$minutos min';
    final horas = minutos ~/ 60;
    final resto = minutos % 60;
    if (horas < 24) return '${horas}h${resto == 0 ? '' : ' ${resto}min'}';
    final dias = horas ~/ 24;
    final horasRestantes = horas % 24;
    return '${dias}d${horasRestantes == 0 ? '' : ' ${horasRestantes}h'}';
  }

  String _situacao(Map<String, dynamic> pedido) {
    return '${pedido['situacao'] ?? ''}'.toUpperCase() == 'EM_ROTA'
        ? 'Em rota'
        : 'Aceito';
  }

  List<Map<String, dynamic>> _itens(Map<String, dynamic> pedido) {
    return (pedido['itens'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  void _verProdutos(Map<String, dynamic> pedido) {
    final itens = _itens(pedido);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Produtos da venda #${pedido['venda_id'] ?? ''}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${pedido['nmcliente'] ?? ''} • ${pedido['endereco'] ?? ''}',
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 16),
              if (itens.isEmpty)
                const Text('Nenhum produto informado para este pedido.')
              else
                ...itens.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE1F5E8),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: Color(0xFF18763B),
                      ),
                    ),
                    title: Text(
                      '${item['nome'] ?? 'Produto'}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    trailing: Text(
                      '${item['quantidade'] ?? 1}x',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardPedido(Map<String, dynamic> pedido) {
    final emRota = '${pedido['situacao'] ?? ''}'.toUpperCase() == 'EM_ROTA';
    final cor = emRota ? Colors.blue.shade700 : Colors.orange.shade800;
    final dataPedido = '${pedido['dtpedido_fmt'] ?? ''}'.trim();
    final dataAceite = '${pedido['dtaceite_fmt'] ?? ''}'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _verProdutos(pedido),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Venda #${pedido['venda_id'] ?? ''}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: cor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _situacao(pedido),
                      style: TextStyle(color: cor, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                '${pedido['nmcliente'] ?? 'Cliente'} • R\$ ${pedido['total'] ?? '0'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 19),
                  const SizedBox(width: 7),
                  Expanded(child: Text('${pedido['endereco'] ?? ''}')),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7F4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 18,
                      color: Color(0xFF18763B),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        dataAceite.isNotEmpty
                            ? 'Aceito em $dataAceite'
                            : 'Solicitado em $dataPedido',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      'Há ${_tempoAguardando(pedido)}',
                      style: const TextStyle(
                        color: Color(0xFF18763B),
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, size: 18),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${_itens(pedido).length} produto(s) • Toque para consultar',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F6F6),
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: 'Entregas pendentes',
            subtitulo: 'Pedidos aceitos, do maior tempo de espera ao menor.',
            trailing: IconButton(
              onPressed: _carregando ? null : _carregar,
              tooltip: 'Atualizar entregas',
              icon: const Icon(Icons.refresh_rounded),
            ),
          ),
          Expanded(
            child: _carregando
                ? const Center(
                    child: CircularProgressIndicator(
                      color: ClubbarColors.primaria,
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _carregar,
                    child: _erro != null
                        ? ListView(
                            padding: const EdgeInsets.all(24),
                            children: [
                              const SizedBox(height: 70),
                              const Icon(
                                Icons.cloud_off_rounded,
                                size: 60,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _erro!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          )
                        : ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              if (_pedidos.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(top: 70),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.delivery_dining_outlined,
                                        size: 62,
                                        color: Colors.grey,
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'Nenhuma entrega pendente.',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._pedidos.map(_cardPedido),
                            ],
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
