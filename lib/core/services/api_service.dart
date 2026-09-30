import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'storage_service.dart';

class ApiService {
  static Future<Map<String, String>> _headers() async {
    final token = await StorageService.getToken();

    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<http.Response> get(String endpoint) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final response = await http.get(url, headers: await _headers());
    return _tratarRespostaDeAutenticacao(response);
  }

  static Future<http.Response> post(
    String endpoint,
    Map<String, dynamic> body, {
    bool limparSessaoAo401 = true,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final response = await http.post(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _tratarRespostaDeAutenticacao(
      response,
      limparSessaoAo401: limparSessaoAo401,
    );
  }

  static Future<http.Response> put(String endpoint, Object body) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final response = await http.put(
      url,
      headers: await _headers(),
      body: jsonEncode(body),
    );
    return _tratarRespostaDeAutenticacao(response);
  }

  static Future<http.Response> patch(String endpoint, {Object? body}) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final response = await http.patch(
      url,
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _tratarRespostaDeAutenticacao(response);
  }

  static Future<http.Response> delete(String endpoint) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$endpoint');

    final response = await http.delete(url, headers: await _headers());
    return _tratarRespostaDeAutenticacao(response);
  }

  /// Remove dados locais quando a API informa que a sessão não é mais válida.
  /// O app observa essa alteração e retorna o usuário à tela de login.
  static Future<http.Response> _tratarRespostaDeAutenticacao(
    http.Response response, {
    bool limparSessaoAo401 = true,
  }) async {
    if (limparSessaoAo401 && response.statusCode == 401) {
      await StorageService.clearToken();
    }
    return response;
  }

  String mensagemErroAmigavel(Object e) {
    final texto = e.toString();

    final textoLower = texto.toLowerCase();

    if (textoLower.contains('socketexception') ||
        textoLower.contains('failed host lookup') ||
        textoLower.contains('connection refused')) {
      return 'Sem conexão com a internet ou servidor indisponível.';
    }

    if (textoLower.contains('timeout')) {
      return 'O servidor demorou para responder. Tente novamente.';
    }

    if (textoLower.contains('502') ||
        textoLower.contains('503') ||
        textoLower.contains('500')) {
      return 'Sistema em atualização. Tente novamente em instantes.';
    }

    // Preserva a mensagem amigável enviada pela API
    if (texto.startsWith('Exception: ')) {
      return texto.replaceFirst('Exception: ', '');
    }

    return texto;
  }

  static Future<Map<String, dynamic>> confirmarRetirada({
    required int itvendaId,
  }) async {
    final usuarioId = await StorageService.getUsuarioId();

    if (usuarioId == null || usuarioId == 0) {
      throw Exception('Usuário não identificado. Faça login novamente.');
    }

    final response = await _tratarRespostaDeAutenticacao(
      await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/entregas/$itvendaId/entregarproduto?usuario_id=$usuarioId',
        ),
        headers: await _headers(),
      ),
    );

    final data = response.body.isNotEmpty
        ? jsonDecode(response.body) as Map<String, dynamic>
        : <String, dynamic>{};

    if (response.statusCode != 200) {
      throw Exception(response.body);
    }

    return data;
  }

  static Future<Map<String, dynamic>> buscarProdutoPorToken({
    required String token,
  }) async {
    try {
      final usuarioId = await StorageService.getUsuarioId();

      if (usuarioId == null || usuarioId == 0) {
        throw Exception(
          'Usuário responsável não identificado. Faça login novamente.',
        );
      }

      final tokenLimpo = token.trim();

      if (tokenLimpo.isEmpty) {
        throw Exception('Token do produto não informado.');
      }

      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/entregas/buscar-por-token/'
        '${Uri.encodeComponent(tokenLimpo)}'
        '?usuario_id=$usuarioId',
      );

      final response = await _tratarRespostaDeAutenticacao(
        await http.get(uri, headers: await _headers()),
      );

      final texto = response.body.trim();

      final Map<String, dynamic> body = texto.isEmpty
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(jsonDecode(texto));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          body['detail']?.toString() ?? 'Não foi possível consultar o produto.',
        );
      }

      return body;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> confirmarRetiradaPorToken({
    required String token,
    int? eventoId,
  }) async {
    try {
      final usuarioId = await StorageService.getUsuarioId();

      if (usuarioId == null || usuarioId == 0) {
        throw Exception(
          'Usuário responsável não identificado. Faça login novamente.',
        );
      }

      final parametros = <String, String>{
        'usuario_id': '$usuarioId',
        if (eventoId != null) 'evento_id': '$eventoId',
      };
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/entregas/entregar-por-token/'
        '${Uri.encodeComponent(token)}',
      ).replace(queryParameters: parametros);

      final response = await _tratarRespostaDeAutenticacao(
        await http.post(uri, headers: await _headers()),
      );

      final dynamic decoded = response.body.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);

      final body = decoded is Map<String, dynamic>
          ? decoded
          : <String, dynamic>{};

      if (response.statusCode != 200) {
        throw Exception(
          body['detail']?.toString() ??
              'Não foi possível confirmar a retirada.',
        );
      }

      return body;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  static Future<Map<String, dynamic>> atualizarControleBar({
    required int itvendaId,
    required String situacao,
    String? nrMesa,
    String? observacao,
  }) async {
    final usuarioId = await StorageService.getUsuarioId();
    if (usuarioId == null || usuarioId == 0) {
      throw Exception(
        'Usuário responsável não identificado. Faça login novamente.',
      );
    }

    final dados = <String, dynamic>{'situacao': situacao};
    if (nrMesa != null) dados['nrmesa'] = nrMesa;
    if (observacao != null) dados['observacao'] = observacao;

    final response = await _tratarRespostaDeAutenticacao(
      await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/entregas/controle-bar/$itvendaId?usuario_id=$usuarioId',
        ),
        headers: await _headers(),
        body: jsonEncode(dados),
      ),
    );

    final body = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['detail']?.toString() ?? 'Não foi possível atualizar o produto.',
      );
    }
    return body;
  }

  static Future<List<Map<String, dynamic>>> listarProdutosEmProducao() async {
    final usuarioId = await StorageService.getUsuarioId();
    if (usuarioId == null || usuarioId == 0) {
      throw Exception(
        'Usuário responsável não identificado. Faça login novamente.',
      );
    }

    final response = await _tratarRespostaDeAutenticacao(
      await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/entregas/controle-bar/em-producao?usuario_id=$usuarioId',
        ),
        headers: await _headers(),
      ),
    );
    final body = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['detail']?.toString() ??
            'Não foi possível carregar os produtos em preparação.',
      );
    }

    final itens = body['itens'];
    if (itens is! List) return [];
    return itens
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<List<Map<String, dynamic>>> listarProdutosControleBar({
    required String filtro,
  }) async {
    final usuarioId = await StorageService.getUsuarioId();
    if (usuarioId == null || usuarioId == 0) {
      throw Exception(
        'Usuário responsável não identificado. Faça login novamente.',
      );
    }

    final response = await _tratarRespostaDeAutenticacao(
      await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/entregas/controle-bar/produtos/'
          '${Uri.encodeComponent(filtro)}?usuario_id=$usuarioId',
        ),
        headers: await _headers(),
      ),
    );
    final body = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['detail']?.toString() ?? 'Não foi possível carregar os produtos.',
      );
    }

    final itens = body['itens'];
    if (itens is! List) return [];
    return itens
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  static Future<Map<String, dynamic>> resumoControleBar() async {
    final usuarioId = await StorageService.getUsuarioId();
    if (usuarioId == null || usuarioId == 0) {
      throw Exception(
        'Usuário responsável não identificado. Faça login novamente.',
      );
    }
    final response = await _tratarRespostaDeAutenticacao(
      await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/entregas/controle-bar/resumo?usuario_id=$usuarioId',
        ),
        headers: await _headers(),
      ),
    );
    final body = response.body.trim().isEmpty
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(response.body));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        body['detail']?.toString() ?? 'Não foi possível carregar o resumo.',
      );
    }
    return body;
  }

  static Future<List<Map<String, dynamic>>> listarEventosHojeTicketman() async {
    final response = await get('/eventos/leitor-ingressos/hoje');
    final texto = response.body.trim();
    final corpo = texto.isEmpty ? const <dynamic>[] : jsonDecode(texto);
    if (response.statusCode != 200) {
      final detalhe = corpo is Map ? corpo['detail']?.toString() : null;
      throw Exception(
        detalhe ?? 'Não foi possível carregar os eventos de hoje.',
      );
    }
    return (corpo as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  static Future<Map<String, dynamic>> buscarResumoEventoTicketman(
    int eventoId,
  ) async {
    final response = await get('/eventos/$eventoId/leitor-ingressos/resumo');
    final texto = response.body.trim();
    final corpo = texto.isEmpty ? <String, dynamic>{} : jsonDecode(texto);
    if (response.statusCode != 200) {
      final detalhe = corpo is Map ? corpo['detail']?.toString() : null;
      throw Exception(
        detalhe ?? 'Não foi possível carregar o resumo do evento.',
      );
    }
    return Map<String, dynamic>.from(corpo as Map);
  }

  static Future<Map<String, dynamic>> buscarLojaDoUsuario({
    required int usuarioId,
  }) async {
    try {
      if (usuarioId <= 0) {
        throw Exception('Usuário não identificado.');
      }

      final response = await get('/usuarios/$usuarioId/loja');

      final textoResposta = response.body.trim();

      Map<String, dynamic> body = {};

      if (textoResposta.isNotEmpty) {
        final decoded = jsonDecode(textoResposta);

        if (decoded is Map<String, dynamic>) {
          body = decoded;
        } else if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          body['detail']?.toString() ??
              body['message']?.toString() ??
              'Não foi possível carregar os dados do estabelecimento.',
        );
      }

      return body;
    } catch (e) {
      throw Exception(e.toString().replaceFirst('Exception: ', ''));
    }
  }
}
