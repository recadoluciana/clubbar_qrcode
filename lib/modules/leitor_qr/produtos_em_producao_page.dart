import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/app_snackbar.dart';
import '../../core/widgets/clubbar_app_bar.dart';

class ProdutosEmProducaoPage extends StatefulWidget {
  const ProdutosEmProducaoPage({super.key});

  @override
  State<ProdutosEmProducaoPage> createState() => _ProdutosEmProducaoPageState();
}

class _ProdutosEmProducaoPageState extends State<ProdutosEmProducaoPage> {
  bool _carregando = true;
  String? _erro;
  List<Map<String, dynamic>> _itens = const [];
  final Set<int> _entregando = <int>{};

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
      final itens = await ApiService.listarProdutosEmProducao();
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

  Widget _card(Map<String, dynamic> item) {
    final id = int.tryParse('${item['itvenda_id']}') ?? 0;
    final mesa = '${item['nrmesa'] ?? ''}'.trim();
    final observacao = '${item['dsobsitvenda'] ?? ''}'.trim();
    final foto = _foto(item);
    final entregando = _entregando.contains(id);

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
                      const SizedBox(height: 4),
                      Text(
                        mesa.isEmpty ? 'Mesa não informada' : 'Mesa: $mesa',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
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
            _linha(
              Icons.notes_rounded,
              'Observação',
              observacao.isEmpty ? 'Sem observação' : observacao,
            ),
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
    return Scaffold(
      appBar: const ClubbarAppBar(mostrarVoltar: true),
      body: RefreshIndicator(
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
                  const Text(
                    'Não foi possível carregar os produtos em preparação.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                children: const [
                  SizedBox(height: 110),
                  Icon(
                    Icons.restaurant_menu_rounded,
                    size: 70,
                    color: Colors.black38,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Nenhum produto em preparação.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
                children: [
                  const Text(
                    'Produtos em preparação',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Clique em Entregue quando o produto estiver pronto e for entregue ao cliente.',
                  ),
                  const SizedBox(height: 18),
                  ..._itens.map(_card),
                ],
              ),
      ),
    );
  }
}
