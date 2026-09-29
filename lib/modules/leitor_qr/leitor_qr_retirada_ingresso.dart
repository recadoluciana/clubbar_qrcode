import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

import '../../core/services/api_service.dart';
import '../../core/config/api_config.dart';
import '../../core/theme/clubbar_colors.dart';

class LeitorQrRetiradaIngressoScreen extends StatefulWidget {
  final bool iniciarLeitura;
  final int? eventoId;

  const LeitorQrRetiradaIngressoScreen({
    super.key,
    this.iniciarLeitura = false,
    this.eventoId,
  });

  @override
  State<LeitorQrRetiradaIngressoScreen> createState() =>
      _LeitorQrRetiradaIngressoScreenState();
}

class _LeitorQrRetiradaIngressoScreenState
    extends State<LeitorQrRetiradaIngressoScreen> {
  bool processando = false;
  late bool lendoQr;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    lendoQr = widget.iniciarLeitura;
  }

  Future<void> vibrarSucesso() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 200);
    }
  }

  Future<void> vibrarErro() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 300, 150, 300]);
    }
  }

  Future<void> tocarOk() async {
    await _audioPlayer.play(AssetSource('sounds/ok.mp3'));
  }

  Future<void> tocarErro() async {
    await _audioPlayer.play(AssetSource('sounds/error.mp3'));
  }

  Future<void> tocarBeep() async {
    await _audioPlayer.play(AssetSource('sounds/beep.mp3'));
  }

  Future<void> _mostrarResultado({
    required bool sucesso,
    required String mensagem,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: sucesso ? Colors.green : Colors.red,
        title: Icon(
          sucesso ? Icons.check_circle : Icons.cancel,
          color: Colors.white,
          size: 82,
        ),
        content: Text(
          mensagem,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: sucesso ? Colors.green : Colors.red,
              backgroundColor: Colors.white,
            ),
            child: const Text(
              'Fechar',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _motivoDaValidacao(Object erro) {
    final mensagem = erro.toString().replaceFirst('Exception: ', '').trim();
    final texto = mensagem.toLowerCase();

    if (texto.contains('já foi utilizado') ||
        texto.contains('ja foi utilizado')) {
      return 'Ingresso já utilizado.\nEste ingresso já foi validado anteriormente.';
    }
    if (texto.contains('outro bar') ||
        texto.contains('outra casa noturna') ||
        texto.contains('outro estabelecimento')) {
      return 'QR Code de outra casa noturna.\n$mensagem';
    }
    if (texto.contains('data do evento') ||
        texto.contains('válido para o evento') ||
        texto.contains('valido para o evento')) {
      return 'Ingresso de outra data.\n$mensagem';
    }
    if (texto.contains('cancelado')) {
      return 'Ingresso cancelado.\nEste ingresso não pode ser validado.';
    }
    if (mensagem.isNotEmpty) return mensagem;
    return 'Não foi possível validar este ingresso.';
  }

  String _primeiroTexto(
    Map<String, dynamic> dados,
    List<String> chaves, {
    String padrao = '',
  }) {
    for (final chave in chaves) {
      final valor = (dados[chave] ?? '').toString().trim();
      if (valor.isNotEmpty && valor.toLowerCase() != 'null') return valor;
    }
    return padrao;
  }

  Widget _detalheIngresso(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text.rich(
        TextSpan(
          text: '$titulo: ',
          style: const TextStyle(fontWeight: FontWeight.w600),
          children: [TextSpan(text: valor)],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Future<void> _processarQr(String raw) async {
    if (processando) return;

    setState(() => processando = true);

    await tocarBeep();

    try {
      const prefixoIngresso = 'CLUBBAR-INGRESSO:';
      const prefixoProduto = 'CLUBBAR-PRODUTO:';
      final conteudo = raw.trim();
      final prefixo = conteudo.startsWith(prefixoIngresso)
          ? prefixoIngresso
          : conteudo.startsWith(prefixoProduto)
          ? prefixoProduto
          : '';
      if (prefixo.isEmpty) {
        throw Exception('Este QR Code não pertence ao Clubbar.');
      }
      final token = conteudo.substring(prefixo.length).trim();
      if (token.isEmpty) {
        throw Exception('Token do ingresso não informado.');
      }
      final data = await ApiService.buscarProdutoPorToken(token: token);

      final tipo = (data['idtipoproduto'] ?? '').toString().toUpperCase();

      if (tipo != 'I') {
        await tocarErro();
        await vibrarErro();

        if (!mounted) return;

        setState(() {
          processando = false;
          lendoQr = false;
        });

        await _mostrarResultado(
          sucesso: false,
          mensagem:
              'Este QR Code é de um produto.\nAbra Meus produtos para fazer a retirada.',
        );
        return;
      }

      final eventoLido = int.tryParse('${data['evento_id'] ?? ''}');
      if (widget.eventoId != null && eventoLido != widget.eventoId) {
        throw Exception(
          'Este ingresso pertence a outro evento. Volte e selecione o evento correto.',
        );
      }

      final loja = data['nmloja'];
      final cliente = data['nmcliente'];
      final participante = data['nmparticipante'];
      final cpf = data['cpfparticipante'];
      final nomeEvento = _primeiroTexto(data, const [
        'nmevento',
        'nmproduto',
      ], padrao: 'Ingresso Clubbar');
      final lote = _primeiroTexto(data, const ['nmlote', 'lote']);
      final numeroLote = _primeiroTexto(data, const ['nrlote', 'numero_lote']);
      final loteExibicao = lote.isNotEmpty
          ? lote
          : numeroLote.isNotEmpty
          ? 'Lote $numeroLote'
          : 'Lote não informado';
      final setor = _primeiroTexto(data, const [
        'nmsetor',
        'nmsetoringresso',
        'setor',
      ], padrao: 'Setor não informado');
      final modalidade = _primeiroTexto(data, const [
        'nmpreco',
        'tipopreco',
      ], padrao: 'Modalidade não informada');
      final dataEvento = _primeiroTexto(data, const [
        'dtinicioevento_fmt',
        'dtinicioevento',
      ], padrao: 'Data não informada');
      final localEvento = _primeiroTexto(data, const [
        'nmlocalevento',
        'nmloja',
      ], padrao: loja.toString());
      final enderecoEvento = _primeiroTexto(data, const [
        'dsendlocevento',
        'endereco_estabelecimento',
      ], padrao: 'Endereço do estabelecimento');

      final fotoUrl = ApiConfig.buildUrl(
        (data['urlfotoproduto'] ?? '').toString(),
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  nomeEvento,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                if (fotoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      fotoUrl,
                      height: 110,
                      width: 110,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const Icon(Icons.image_not_supported, size: 70),
                    ),
                  )
                else
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 70,
                    color: ClubbarColors.primaria,
                  ),

                const SizedBox(height: 10),
                _detalheIngresso('Lote', loteExibicao),
                _detalheIngresso('Setor', setor),
                _detalheIngresso('Modalidade', modalidade),
                _detalheIngresso('Data e hora', dataEvento),
                _detalheIngresso('Local', localEvento),
                _detalheIngresso('Endereço', enderecoEvento),
                const SizedBox(height: 12),

                Text(
                  'Cliente: $cliente',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),

                if ((participante ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Participante: $participante',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],

                if ((cpf ?? '').toString().trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'CPF: $cpf',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                ],

                const SizedBox(height: 8),

                Text(
                  'Estabelecimento: $loja',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);

                setState(() {
                  processando = false;
                  lendoQr = false;
                });
              },
              child: const Text('Fechar'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final resposta = await ApiService.confirmarRetiradaPorToken(
                    token: token,
                    eventoId: widget.eventoId,
                  );

                  if (!mounted) return;

                  Navigator.pop(context);

                  if (resposta['already'] == true) {
                    await tocarErro();
                    await vibrarErro();

                    if (!mounted) return;

                    setState(() {
                      processando = false;
                      lendoQr = false;
                    });

                    await _mostrarResultado(
                      sucesso: false,
                      mensagem: 'INGRESSO JÁ UTILIZADO',
                    );
                  } else {
                    await tocarOk();
                    await vibrarSucesso();

                    if (!mounted) return;

                    setState(() {
                      processando = false;
                      lendoQr = false;
                    });

                    await _mostrarResultado(
                      sucesso: true,
                      mensagem: 'INGRESSO VALIDADO',
                    );
                  }
                } catch (e) {
                  if (!mounted) return;

                  Navigator.pop(context);

                  await tocarErro();
                  await vibrarErro();

                  if (!mounted) return;

                  setState(() {
                    processando = false;
                    lendoQr = false;
                  });

                  await _mostrarResultado(
                    sucesso: false,
                    mensagem: _motivoDaValidacao(e),
                  );
                }
              },
              child: const Text('Validar ingresso'),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        processando = false;
        lendoQr = false;
      });

      await tocarErro();
      await vibrarErro();

      if (!mounted) return;

      await _mostrarResultado(sucesso: false, mensagem: _motivoDaValidacao(e));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Leitor de ingresso'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (lendoQr)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  lendoQr = false;
                  processando = false;
                });
              },
            ),
        ],
      ),
      body: lendoQr
          ? Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) {
                    final barcode = capture.barcodes.firstOrNull;
                    final raw = barcode?.rawValue;

                    if (raw != null && raw.isNotEmpty) {
                      _processarQr(raw);
                    }
                  },
                ),
                Center(
                  child: Container(
                    width: 260,
                    height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: ClubbarColors.primaria,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            )
          : Center(
              child: SizedBox(
                width: 280,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      lendoQr = true;
                      processando = false;
                    });
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                  label: const Text(
                    'Ler QR Code do ingresso',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ),
    );
  }
}
