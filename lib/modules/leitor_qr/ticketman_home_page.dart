import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/config/api_config.dart';
import '../../core/services/api_service.dart';
import '../leitor_qr/leitor_qr_retirada_ingresso.dart';
import '../auth/login_page.dart';
import '../../core/services/storage_service.dart';
import '../../core/theme/clubbar_colors.dart';
import '../../core/widgets/clubbar_app_bar.dart';

class TicketmanHomePage extends StatefulWidget {
  const TicketmanHomePage({super.key});

  @override
  State<TicketmanHomePage> createState() => _TicketmanHomePageState();
}

class _TicketmanHomePageState extends State<TicketmanHomePage> {
  String nomeUsuario = '';
  String nomeLoja = '';
  String logoLoja = '';
  String dataHoraAtual = '';
  bool carregandoLoja = true;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    carregarDados();
    iniciarRelogio();
  }

  String _montarUrlImagem(String caminho) {
    final valor = caminho.trim();

    if (valor.isEmpty) return '';

    if (valor.startsWith('http://') || valor.startsWith('https://')) {
      return valor;
    }

    return valor.startsWith('/')
        ? '${ApiConfig.baseUrl}$valor'
        : '${ApiConfig.baseUrl}/$valor';
  }

  Future<void> carregarDados() async {
    final nome = await StorageService.getNomeUsuario();
    final usuarioId = await StorageService.getUsuarioId();

    String nomeLojaRecebido = '';
    String caminhoLogo = '';

    if (usuarioId != null && usuarioId > 0) {
      try {
        final dadosLoja = await ApiService.buscarLojaDoUsuario(
          usuarioId: usuarioId,
        );
        nomeLojaRecebido = (dadosLoja['nmloja'] ?? '').toString().trim();
        caminhoLogo = (dadosLoja['urllogoloja'] ?? '').toString().trim();
      } catch (_) {
        // A leitura de ingressos continua disponível mesmo se a loja falhar.
      }
    }

    if (!mounted) return;

    setState(() {
      nomeUsuario = nome?.trim().isNotEmpty == true
          ? nome!.trim()
          : 'Ticketman';
      nomeLoja = nomeLojaRecebido.isNotEmpty
          ? nomeLojaRecebido
          : 'Estabelecimento não identificado';
      logoLoja = _montarUrlImagem(caminhoLogo);
      carregandoLoja = false;
    });
  }

  Widget _logoDaLoja() {
    const placeholder = Icon(
      Icons.storefront_rounded,
      size: 44,
      color: ClubbarColors.primariaEscuro,
    );

    if (logoLoja.isEmpty) return placeholder;

    return Image.network(
      logoLoja,
      width: 88,
      height: 88,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => placeholder,
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

  void iniciarRelogio() {
    dataHoraAtual = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.now());

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      setState(() {
        dataHoraAtual = DateFormat(
          'dd/MM/yyyy HH:mm:ss',
        ).format(DateTime.now());
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _sair() async {
    await StorageService.clearToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      appBar: ClubbarAppBar(mostrarSair: true, onSair: _sair),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              children: [
                if (carregandoLoja)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(
                      color: ClubbarColors.primaria,
                    ),
                  )
                else
                  _cardLoja(),

                const SizedBox(height: 28),

                const Text(
                  'Ticketman',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 20),

                const Icon(
                  Icons.security,
                  size: 90,
                  color: ClubbarColors.primaria,
                ),

                const SizedBox(height: 24),

                Text(
                  'Olá, $nomeUsuario',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  dataHoraAtual,
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),

                const SizedBox(height: 20),

                const Text(
                  'Validação de ingressos e controle de acesso',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),

                const SizedBox(height: 40),

                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              const LeitorQrRetiradaIngressoScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text(
                      'Ler QrCode do Ingresso',
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
}
