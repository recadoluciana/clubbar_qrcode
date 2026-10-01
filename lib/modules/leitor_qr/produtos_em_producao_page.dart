import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../../core/widgets/clubbar_page_header.dart';

enum ProdutosControleBarFiltro { pendentes, preparando }

extension on ProdutosControleBarFiltro {
  String get apiValue => switch (this) {
    ProdutosControleBarFiltro.pendentes => 'PENDENTES',
    ProdutosControleBarFiltro.preparando => 'EM_PRODUCAO',
  };

  String get titulo => switch (this) {
    ProdutosControleBarFiltro.pendentes => 'Produtos pendentes',
    ProdutosControleBarFiltro.preparando => 'Em preparação',
  };

  String get mensagemVazia => switch (this) {
    ProdutosControleBarFiltro.pendentes => 'Nenhum produto pendente.',
    ProdutosControleBarFiltro.preparando => 'Nenhum produto em preparação.',
  };

  IconData get icone => switch (this) {
    ProdutosControleBarFiltro.pendentes => Icons.shopping_bag_outlined,
    ProdutosControleBarFiltro.preparando => Icons.restaurant_menu_rounded,
  };
}

class ProdutosEmProducaoPage extends StatefulWidget {
  const ProdutosEmProducaoPage({super.key, required this.filtro});

  final ProdutosControleBarFiltro filtro;

  @override
  State<ProdutosEmProducaoPage> createState() => _ProdutosEmProducaoPageState();
}

class _ProdutosEmProducaoPageState extends State<ProdutosEmProducaoPage> {
  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _itens = const [];
  final Set<int> _entregando = <int>{};
  Timer? _tempoPreparacaoTimer;

  @override
  void initState() {
    super.initState();
    _carregar();
    _tempoPreparacaoTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tempoPreparacaoTimer?.cancel();
    super.dispose();
  }

  Future<void> _carregar() async {
    setState(() {
      _carregando = true;
      _erro = null;
    });
    try {
      final itens = await ApiService.listarProdutosControleBar(
        filtro: widget.filtro.apiValue,
      );
      if (!mounted) return;
      setState(() => _itens = itens);
    } catch (e) {
      if (!mounted) return;
      setState(() => _erro = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _carregando = false);
    }
  }

  Future<void> _entregar(Map<String, dynamic> item) async {
    final id = int.tryParse('${item['itvenda_id']}');
    if (id == null) return;
    setState(() => _entregando.add(id));
    try {
      await ApiService.atualizarControleBar(
        itvendaId: id,
        situacao: 'ENTREGUE',
      );
      if (!mounted) return;
      AppSnackBar.sucesso(context, 'Produto marcado como entregue.');
      await _carregar();
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.erro(
        context,
        e.toString().replaceFirst('Exception: ', ''),
        mostrarFechar: true,
      );
    } finally {
      if (mounted) setState(() => _entregando.remove(id));
    }
  }

  String _foto(Map<String, dynamic> item) {
    final caminho = '${item['urlfotoproduto'] ?? ''}'.trim();
    return ApiConfig.buildUrl(caminho);
  }

  String _formatarDataHora(dynamic valor) {
    final texto = '${valor ?? ''}'.trim();
    final data = DateTime.tryParse(texto);
    if (data == null) return 'Não informada';
    return DateFormat("dd/MM/yyyy 'às' HH:mm", 'pt_BR').format(data);
  }

  String _formatarValidade(dynamic valor) {
    final texto = '${valor ?? ''}'.trim();
    final data = DateTime.tryParse(texto);
    if (data == null) return 'Sem validade';
    return DateFormat('dd/MM/yyyy', 'pt_BR').format(data);
  }

  Widget _linhaPreparacao(dynamic valor) {
    final texto = '${valor ?? ''}'.trim();
    final inicio = DateTime.tryParse(texto);
    if (inicio == null) {
      return _linha(
        Icons.schedule_rounded,
        'Preparação',
        'Horário não informado',
      );
    }

    final diferenca = DateTime.now().difference(inicio);
    final minutos = diferenca.isNegative ? 0 : diferenca.inMinutes;
    final cor = minutos > 30
        ? Colors.red.shade700
        : minutos > 20
        ? Colors.orange.shade800
        : ClubbarColors.primaria;

    return Row(
      children: [
        Icon(Icons.schedule_rounded, size: 19, color: ClubbarColors.primaria),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                const TextSpan(
                  text: 'Preparação: ',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: _formatarDataHora(inicio.toIso8601String())),
              ],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cor.withValues(alpha: 0.45)),
          ),
          child: Text(
            '$minutos min',
            style: TextStyle(
              color: cor,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _card(Map<String, dynamic> item) {
    final id = int.tryParse('${item['itvenda_id']}') ?? 0;
    final mesa = '${item['nrmesa'] ?? ''}'.trim();
    final observacao = '${item['dsobsitvenda'] ?? ''}'.trim();
    final foto = _foto(item);
    final entregando = _entregando.contains(id);
    final pendente = widget.filtro == ProdutosControleBarFiltro.pendentes;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    width: 58,
                    height: 58,
                    child: foto.isEmpty
                        ? const ColoredBox(
                            color: Color(0xFFF2F2F2),
                            child: Icon(Icons.fastfood_rounded),
                          )
                        : Image.network(
                            foto,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(
                              color: Color(0xFFF2F2F2),
                              child: Icon(Icons.fastfood_rounded),
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${item['nmproduto'] ?? 'Produto Clubbar'}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (pendente) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Ticket: #${item['itvenda_id'] ?? 'Não informado'}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                      if (!pendente) ...[
                        const SizedBox(height: 4),
                        Text(
                          mesa.isEmpty ? 'Mesa não informada' : 'Mesa: $mesa',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _linha(
              Icons.person_outline_rounded,
              'Cliente',
              '${item['nmcliente'] ?? 'Não informado'}',
            ),
            const SizedBox(height: 9),
            if (pendente) ...[
              _linha(
                Icons.calendar_month_outlined,
                'Compra',
                _formatarDataHora(item['dtcompra']),
              ),
              const SizedBox(height: 9),
              _linha(
                Icons.event_available_outlined,
                'Validade',
                _formatarValidade(item['dtvalidade']),
              ),
            ] else
              _linha(
                Icons.notes_rounded,
                'Observação',
                observacao.isEmpty ? 'Sem observação' : observacao,
              ),
            if (widget.filtro == ProdutosControleBarFiltro.preparando) ...[
              const SizedBox(height: 9),
              _linhaPreparacao(item['dtpreparacao']),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: entregando ? null : () => _entregar(item),
                  icon: entregando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(entregando ? 'Entregando...' : 'Entregue'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ClubbarColors.primaria,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _linha(IconData icone, String titulo, String valor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icone, size: 19, color: ClubbarColors.primaria),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(color: Colors.black87, fontSize: 14),
              children: [
                TextSpan(
                  text: '$titulo: ',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                TextSpan(text: valor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tituloCabecalho = widget.filtro.titulo;
    final subtituloCabecalho =
        widget.filtro == ProdutosControleBarFiltro.pendentes
        ? 'Produtos comprados e ainda não utilizados'
        : 'Clique em Entregue quando o produto estiver pronto e for entregue ao cliente.';

    return Scaffold(
      appBar: ClubbarAppBar(
        mostrarVoltar: true,
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: _carregando ? null : _carregar,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          ClubbarPageHeader(
            titulo: tituloCabecalho,
            subtitulo: subtituloCabecalho,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _carregar,
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : _erro != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 80),
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 62,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Não foi possível carregar ${widget.filtro.titulo.toLowerCase()}.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(_erro!, textAlign: TextAlign.center),
                        const SizedBox(height: 18),
                        ElevatedButton.icon(
                          onPressed: _carregar,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Tentar novamente'),
                        ),
                      ],
                    )
                  : _itens.isEmpty
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 110),
                        Icon(
                          widget.filtro.icone,
                          size: 70,
                          color: Colors.black38,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.filtro.mensagemVazia,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                      children: [..._itens.map(_card)],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
