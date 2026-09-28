import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'core/services/storage_service.dart';
import 'core/theme/app_theme.dart';
import 'modules/auth/login_page.dart';
import 'modules/leitor_qr/barman_home_page.dart';
import 'modules/leitor_qr/ticketman_home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);
  Intl.defaultLocale = 'pt_BR';
  runApp(const ClubbarQrCodeApp());
}

class ClubbarQrCodeApp extends StatelessWidget {
  const ClubbarQrCodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: StorageService.sessaoAlterada,
      builder: (_, versaoSessao, _) => MaterialApp(
        key: ValueKey(versaoSessao),
        debugShowCheckedModeBanner: false,
        title: 'Clubbar QR Code',
        theme: AppTheme.light,
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _DecisorDeSessao(),
      ),
    );
  }
}

class _DecisorDeSessao extends StatefulWidget {
  const _DecisorDeSessao();

  @override
  State<_DecisorDeSessao> createState() => _DecisorDeSessaoState();
}

class _DecisorDeSessaoState extends State<_DecisorDeSessao> {
  bool _carregando = true;
  String _cargo = '';
  bool _temSessaoOperacional = false;

  @override
  void initState() {
    super.initState();
    _carregarSessao();
  }

  Future<void> _carregarSessao() async {
    final token = await StorageService.getToken();
    final cargo = (await StorageService.getCargo() ?? '').trim().toUpperCase();
    final operacional =
        cargo == 'TICKETMAN' || cargo == 'BARMAN' || cargo == 'WAITER';
    if (token != null && token.isNotEmpty && !operacional) {
      await StorageService.clearToken();
    }
    if (!mounted) return;
    setState(() {
      _cargo = cargo;
      _temSessaoOperacional =
          token != null && token.isNotEmpty && operacional;
      _carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_carregando) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_temSessaoOperacional) return const LoginPage();
    if (_cargo == 'TICKETMAN') return const TicketmanHomePage();
    return const BarmanHomePage();
  }
}
