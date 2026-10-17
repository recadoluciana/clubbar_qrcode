import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import 'leitor_qr_retirada_ingresso.dart';

class TicketmanEventosHojePage extends StatefulWidget {
  const TicketmanEventosHojePage({super.key});

  @override
  State<TicketmanEventosHojePage> createState() =>
      _TicketmanEventosHojePageState();
}

class _TicketmanEventosHojePageState extends State<TicketmanEventosHojePage> {
  List<Map<String, dynamic>> _eventos = [];
  bool _carregando = true;
  String? _erro;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _dataHora(Object? valor) {
    final data = DateTime.tryParse('${valor ?? ''}');
    return data == null
        ? 'Data e hora não informadas'
        : DateFormat('dd/MM/yyyy HH:mm').format(data);
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final eventos = await ApiService.listarEventosHojeTicketman();
      if (mounted) {
        setState(() => _eventos = eventos);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: ClubbarColors.fundo,
    appBar: const ClubbarAppBar(mostrarVoltar: true),
    body: RefreshIndicator(
      onRefresh: _carregar,
      child: _carregando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Selecionar evento',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  'Eventos que começam hoje ou ainda estão em andamento, ${DateFormat('dd/MM/yyyy').format(DateTime.now())}.',
                  style: const TextStyle(color: ClubbarColors.textoSecundario),
                ),
                const SizedBox(height: 16),
                if (_erro != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 40,
                          ),
                          const SizedBox(height: 8),
                          Text(_erro!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _carregar,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_eventos.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(Icons.event_busy_outlined, size: 46),
                          SizedBox(height: 10),
                          Text(
                            'Não há eventos em andamento hoje.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  for (final evento in _eventos)
                    Card(
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const CircleAvatar(
                          backgroundColor: ClubbarColors.primariaClaro,
                          child: Icon(Icons.event_available_rounded),
                        ),
                        title: Text(
                          '${evento['nmtituloevento']}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'Data e hora: ${_dataHora(evento['dtinicioevento'])}\n'
                            'Local: ${evento['nmlocalevento']}',
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TicketmanResumoEventoPage(
                              eventoId: int.parse('${evento['evento_id']}'),
                            ),
                          ),
                        ),
                      ),
                    ),
              ],
            ),
    ),
  );
}

class TicketmanResumoEventoPage extends StatefulWidget {
  final int eventoId;

  const TicketmanResumoEventoPage({super.key, required this.eventoId});

  @override
  State<TicketmanResumoEventoPage> createState() =>
      _TicketmanResumoEventoPageState();
}

class _TicketmanResumoEventoPageState extends State<TicketmanResumoEventoPage> {
  Map<String, dynamic>? _evento;
  String? _erro;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  String _urlImagem(String? valor) {
    final caminho = (valor ?? '').trim();
    if (caminho.isEmpty) return '';
    return caminho.startsWith('http') ? caminho : ApiConfig.buildUrl(caminho);
  }

  String _dataHora(Object? valor) {
    final data = DateTime.tryParse('${valor ?? ''}');
    return data == null
        ? 'Data e hora não informadas'
        : DateFormat('dd/MM/yyyy HH:mm').format(data);
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final evento = await ApiService.buscarResumoEventoTicketman(
        widget.eventoId,
      );
      if (mounted) {
        setState(() => _evento = evento);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
      }
    }
  }

  Widget _total(
    String titulo,
    Object? valor,
    IconData icone,
    Color cor,
    String situacao,
  ) => Expanded(
    child: Card(
      clipBehavior: Clip.antiAlias,
      color: cor.withValues(alpha: 0.08),
      child: InkWell(
        onTap: () async {
          await Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => TicketmanIngressosEventoPage(
                eventoId: widget.eventoId,
                situacao: situacao,
              ),
            ),
          );
          if (mounted) await _carregar();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icone, color: cor),
              const SizedBox(height: 7),
              Text(
                '$valor',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: cor,
                ),
              ),
              Text(titulo, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final evento = _evento;
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: _carregando
          ? const Center(child: CircularProgressIndicator())
          : _erro != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 12),
                    Text(_erro!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _carregar,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          SizedBox(
                            width: 108,
                            height: 108,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child:
                                  _urlImagem(evento?['urlbannerevento']).isEmpty
                                  ? const ColoredBox(
                                      color: ClubbarColors.primariaClaro,
                                      child: Icon(
                                        Icons.confirmation_number_rounded,
                                        size: 54,
                                      ),
                                    )
                                  : Image.network(
                                      _urlImagem(evento?['urlbannerevento']),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const ColoredBox(
                                            color: ClubbarColors.primariaClaro,
                                            child: Icon(
                                              Icons.confirmation_number_rounded,
                                              size: 54,
                                            ),
                                          ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            '${evento?['nmtituloevento']}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Data e hora: ${_dataHora(evento?['dtinicioevento'])}',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Local: ${evento?['nmlocalevento']}',
                            textAlign: TextAlign.center,
                          ),
                          if ('${evento?['dsendlocevento'] ?? ''}'
                              .trim()
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${evento?['dsendlocevento']}',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _total(
                        'Vendidos',
                        evento?['vendidos'] ?? 0,
                        Icons.confirmation_number_outlined,
                        Colors.blue,
                        'VENDIDOS',
                      ),
                      _total(
                        'Validados',
                        evento?['validados'] ?? 0,
                        Icons.verified_outlined,
                        ClubbarColors.primaria,
                        'VALIDADOS',
                      ),
                      _total(
                        'Pendentes',
                        evento?['faltam'] ?? 0,
                        Icons.person_outline_rounded,
                        Colors.orange.shade800,
                        'PENDENTES',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LeitorQrRetiradaIngressoScreen(
                              iniciarLeitura: true,
                              eventoId: widget.eventoId,
                            ),
                          ),
                        );
                        if (mounted) await _carregar();
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text(
                        'Ler QRCode do Ingresso',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class TicketmanIngressosEventoPage extends StatefulWidget {
  final int eventoId;
  final String situacao;

  const TicketmanIngressosEventoPage({
    super.key,
    required this.eventoId,
    required this.situacao,
  });

  @override
  State<TicketmanIngressosEventoPage> createState() =>
      _TicketmanIngressosEventoPageState();
}

class _TicketmanIngressosEventoPageState
    extends State<TicketmanIngressosEventoPage> {
  Map<String, dynamic>? _resposta;
  String? _erro;
  bool _carregando = true;

  String get _titulo => switch (widget.situacao) {
    'VALIDADOS' => 'Ingressos validados',
    'PENDENTES' => 'Ingressos pendentes',
    _ => 'Ingressos vendidos',
  };

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
      final resposta = await ApiService.listarIngressosEventoTicketman(
        widget.eventoId,
        situacao: widget.situacao,
      );
      if (mounted) setState(() => _resposta = resposta);
    } catch (e) {
      if (mounted) {
        setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  String _dataHora(Object? valor) {
    final data = DateTime.tryParse('${valor ?? ''}');
    return data == null ? '—' : DateFormat('dd/MM/yyyy HH:mm').format(data);
  }

  @override
  Widget build(BuildContext context) {
    final itens = (_resposta?['ingressos'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
    return Scaffold(
      backgroundColor: ClubbarColors.fundo,
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : _erro != null
            ? ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  Text(_erro!, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _carregar,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Tentar novamente'),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    _titulo,
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_resposta?['evento'] ?? ''} • ${itens.length} registro(s)',
                    style: const TextStyle(
                      color: ClubbarColors.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (itens.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'Nenhum ingresso encontrado nesta situação.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  for (final item in itens)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  item['validado'] == true
                                      ? Icons.verified_rounded
                                      : Icons.confirmation_number_outlined,
                                  color: item['validado'] == true
                                      ? ClubbarColors.primaria
                                      : Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${item['participante']}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                if ((item['quantidade'] as num? ?? 1) > 1)
                                  Chip(
                                    label: Text(
                                      '${item['quantidade']} ingressos',
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Cliente: ${item['cliente']}'),
                            if ('${item['cpf_participante']}'.isNotEmpty)
                              Text('CPF: ${item['cpf_participante']}'),
                            Text('Lote: ${item['lote']} • ${item['setor']}'),
                            Text('Modalidade: ${item['modalidade']}'),
                            Text('Compra: ${_dataHora(item['data_compra'])}'),
                            if (item['validado'] == true)
                              Text(
                                'Validado: ${_dataHora(item['data_validacao'])}',
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}
