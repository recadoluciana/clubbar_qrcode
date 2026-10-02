import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';
import '../auth/login_page.dart';
import 'leitor_qr_retirada_page.dart';
import 'produtos_em_producao_page.dart';

class BarmanHomePage extends StatefulWidget {
  const BarmanHomePage({super.key});

  @override
  State<BarmanHomePage> createState() => _BarmanHomePageState();
}

class _BarmanHomePageState extends State<BarmanHomePage> {
  String nomeUsuario = 'Barman';
  String cargoUsuario = 'BARMAN';
  String nomeLoja = '';
  String logoLoja = '';
  String dataHoraAtual = '';
  Map<String, dynamic> resumo = const {};

  bool carregando = true;
  String? erro;

  Timer? _relogioTimer;
  Timer? _resumoTimer;

  @override
  void initState() {
    super.initState();

    carregarDados();
    iniciarRelogio();
    iniciarAtualizacaoResumo();
  }

  @override
  void dispose() {
    _relogioTimer?.cancel();
    _resumoTimer?.cancel();
    super.dispose();
  }

  void iniciarRelogio() {
    _atualizarRelogio();

    _relogioTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(_atualizarRelogio);
    });
  }

  void _atualizarRelogio() {
    dataHoraAtual = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());
  }

  void iniciarAtualizacaoResumo() {
    _resumoTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _atualizarResumoSilenciosamente();
    });
  }

  Future<void> _atualizarResumoSilenciosamente() async {
    if (!mounted || carregando) return;

    try {
      final dadosResumo = await ApiService.resumoControleBar();
      if (!mounted) return;
      setState(() => resumo = dadosResumo);
    } catch (_) {
      // Mantém os últimos números exibidos quando a conexão oscilar.
    }
  }

  String _montarUrlImagem(String caminho) {
    final valor = caminho.trim();

    if (valor.isEmpty) {
      return '';
    }

    if (valor.startsWith('http://') || valor.startsWith('https://')) {
      return valor;
    }

    return valor.startsWith('/')
        ? '${ApiConfig.baseUrl}$valor'
        : '${ApiConfig.baseUrl}/$valor';
  }

  Future<void> carregarDados() async {
    if (mounted) {
      setState(() {
        carregando = true;
        erro = null;
      });
    }

    try {
      final nome = await StorageService.getNomeUsuario();
      final cargo = await StorageService.getCargo();
      final usuarioId = await StorageService.getUsuarioId();

      if (usuarioId == null || usuarioId == 0) {
        throw Exception('Usuário não identificado. Faça login novamente.');
      }

      final dadosLoja = await ApiService.buscarLojaDoUsuario(
        usuarioId: usuarioId,
      );
      final dadosResumo = await ApiService.resumoControleBar();

      final nomeLojaRecebido = (dadosLoja['nmloja'] ?? '').toString().trim();

      final caminhoLogo = (dadosLoja['urllogoloja'] ?? '').toString().trim();

      if (!mounted) return;

      setState(() {
        nomeUsuario = nome?.trim().isNotEmpty == true ? nome!.trim() : 'Barman';
        cargoUsuario = (cargo ?? 'BARMAN').trim().toUpperCase();

        nomeLoja = nomeLojaRecebido.isNotEmpty
            ? nomeLojaRecebido
            : 'Estabelecimento não identificada';

        logoLoja = _montarUrlImagem(caminhoLogo);
        resumo = dadosResumo;

        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        erro = e.toString().replaceFirst('Exception: ', '').trim();

        carregando = false;
      });
    }
  }

  Future<void> abrirLeitorQr() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LeitorQrRetiradaScreen()),
    );
    if (mounted) await _atualizarResumoSilenciosamente();
  }

  Future<void> abrirProdutosControleBar(
    ProdutosControleBarFiltro filtro,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProdutosEmProducaoPage(filtro: filtro)),
    );
    if (mounted) await carregarDados();
  }

  Future<void> sair() async {
    final tituloCargo = cargoUsuario == 'WAITER' ? 'Waiter' : 'Barman';
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Sair do $tituloCargo',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: const Text('Deseja realmente encerrar sua sessão?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.black),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sair'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );

    if (confirmar != true) return;

    await StorageService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  Widget _logoDaLoja() {
    Widget placeholder() {
      return const Icon(
        Icons.storefront_rounded,
        size: 48,
        color: Colors.black87,
      );
    }

    if (logoLoja.isEmpty) {
      return placeholder();
    }

    return Image.network(
      logoLoja,
      width: 94,
      height: 94,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) {
        return placeholder();
      },
    );
  }

  Widget _cardLoja() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8FD3A8),
            ClubbarColors.primariaClaro,
            ClubbarColors.fundo,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 94,
            height: 94,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ClubbarColors.primariaClaro, width: 3),
            ),
            child: ClipOval(child: _logoDaLoja()),
          ),

          const SizedBox(height: 12),

          Text(
            nomeLoja,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  int _numeroResumo(String campo) {
    return int.tryParse('${resumo[campo] ?? 0}') ?? 0;
  }

  Widget _cardResumo({
    required String titulo,
    required int quantidade,
    required IconData icone,
    required Color cor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: true,
        label: 'Abrir produtos $titulo',
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 82,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cor.withValues(alpha: 0.30)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icone, color: cor, size: 18),
                const SizedBox(height: 2),
                Text(
                  '$quantidade',
                  style: TextStyle(
                    color: cor,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _resumoProdutos() {
    return Row(
      children: [
        _cardResumo(
          titulo: 'Pendentes',
          quantidade: _numeroResumo('pendentes'),
          icone: Icons.shopping_bag_outlined,
          cor: Colors.blue.shade700,
          onTap: () =>
              abrirProdutosControleBar(ProdutosControleBarFiltro.pendentes),
        ),
        _cardResumo(
          titulo: 'Em preparação',
          quantidade: _numeroResumo('em_preparacao'),
          icone: Icons.restaurant_rounded,
          cor: Colors.orange.shade800,
          onTap: () =>
              abrirProdutosControleBar(ProdutosControleBarFiltro.preparando),
        ),
      ],
    );
  }

  Widget _conteudo() {
    if (carregando) {
      return const Center(
        child: CircularProgressIndicator(color: ClubbarColors.primaria),
      );
    }

    if (erro != null) {
      return RefreshIndicator(
        onRefresh: carregarDados,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 70),

            Icon(
              Icons.cloud_off_rounded,
              size: 68,
              color: Colors.grey.shade400,
            ),

            const SizedBox(height: 16),

            const Text(
              'Não foi possível carregar o estabelecimento',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),

            const SizedBox(height: 8),

            Text(
              erro!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: carregarDados,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
              style: ElevatedButton.styleFrom(
                backgroundColor: ClubbarColors.primaria,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: carregarDados,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              children: [
                _cardLoja(),

                const SizedBox(height: 16),

                const Text(
                  'Barman/Waiter',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Olá, $nomeUsuario',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  dataHoraAtual,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),

                const SizedBox(height: 12),

                const Text(
                  'Validação de produtos',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 14),

                _resumoProdutos(),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: abrirLeitorQr,
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Ler QRCode do Produto',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: ClubbarAppBar(mostrarSair: true, onSair: sair),

      body: _conteudo(),
    );
  }
}
