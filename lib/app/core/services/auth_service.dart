import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:toonarchive/app/core/database/database_helper.dart';
import 'package:toonarchive/app/core/database/supabase_client.dart';
import 'package:toonarchive/app/core/sync/sync_service.dart';
import 'package:toonarchive/app/modules/usuarios/usuario.dart';

class AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  SupabaseClient get _supabase => SupabaseClientHelper.client;

  final _uuid = const Uuid();

  // ──────────────────────────────────────────────────────────
  // UTILITÁRIOS
  // ──────────────────────────────────────────────────────────

  /// SHA-256 da senha — armazenado localmente para login offline.
  String _hashSenha(String senha) =>
      sha256.convert(utf8.encode(senha)).toString();

  Future<bool> _online() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }

  // ──────────────────────────────────────────────────────────
  // CADASTRO — online cria no Supabase; offline cria localmente
  // ──────────────────────────────────────────────────────────

  Future<Usuario?> cadastrar({
    required String nome,
    required String email,
    required String senha,
    void Function(String mensagem)? onErro,
  }) async {
    final online = await _online();

    if (online) {
      return _cadastrarOnline(
          nome: nome, email: email, senha: senha, onErro: onErro);
    } else {
      return _cadastrarOffline(
          nome: nome, email: email, senha: senha, onErro: onErro);
    }
  }

  Future<Usuario?> _cadastrarOnline({
    required String nome,
    required String email,
    required String senha,
    void Function(String mensagem)? onErro,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: senha,
        data: {'nome': nome, 'full_name': nome},
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        onErro?.call('Não foi possível criar a conta. Tente novamente.');
        return null;
      }

      final usuario = await _persistirUsuarioSupabase(
        supabaseUser: supabaseUser,
        nomeOverride: nome,
      );

      // Guarda hash local para login offline futuro
      if (usuario != null) {
        await DatabaseHelper.instance.update(
          'usuarios',
          {'senha_hash': _hashSenha(senha)},
          'id = ?',
          [usuario.id],
        );
      }

      return usuario;
    } on AuthException catch (e) {
      onErro?.call(_traduzirErroSupabase(e.message));
      return null;
    } catch (e) {
      debugPrint('Erro no cadastro: $e');
      onErro?.call('Erro inesperado. Tente novamente.');
      return null;
    }
  }

  /// Cria conta localmente e enfileira no sync_log para sincronizar quando
  /// a conexão for restaurada.
  Future<Usuario?> _cadastrarOffline({
    required String nome,
    required String email,
    required String senha,
    void Function(String mensagem)? onErro,
  }) async {
    final db = DatabaseHelper.instance;

    // Verifica se já existe um usuário com esse email localmente
    final existe = await db.query(
      'usuarios',
      where: 'email = ?',
      whereArgs: [email],
    );
    if (existe.isNotEmpty) {
      onErro?.call('Este email já está em uso neste dispositivo.');
      return null;
    }

    // Verifica nome único
    final nomeExiste = await db.query(
      'usuarios',
      where: 'LOWER(nome) = LOWER(?)',
      whereArgs: [nome],
    );
    if (nomeExiste.isNotEmpty) {
      onErro?.call('Este nome de usuário já está em uso neste dispositivo.');
      return null;
    }

    final agora = DateTime.now();
    final usuario = Usuario(
      id: _uuid.v4(),
      nome: nome,
      email: email,
      role: 'leitor',
      ativo: true,
      criadoEm: agora,
      atualizadoEm: agora,
    );

    final mapa = usuario.toMap();
    mapa['senha_hash'] = _hashSenha(senha);
    mapa['criado_offline'] = 1; // flag auxiliar para sync

    await db.insert('usuarios', mapa);

    // Enfileira para criar no Supabase quando voltar online
    await SyncService.instance.enfileirar(
      usuarioId: usuario.id,
      tabela: 'usuarios',
      operacao: 'INSERT',
      registroId: usuario.id,
      payload: {
        'id': usuario.id,
        'nome': nome,
        'email': email,
        'role': 'leitor',
        'ativo': true,
        'criado_em': agora.toIso8601String(),
        'atualizado_em': agora.toIso8601String(),
      },
    );

    return usuario;
  }

  // ──────────────────────────────────────────────────────────
  // LOGIN COM EMAIL OU NOME DE USUÁRIO
  // Tenta Supabase se online; cai para SQLite se offline ou falha de rede
  // ──────────────────────────────────────────────────────────

  Future<Usuario?> loginComEmail({
    required String email,
    required String senha,
    void Function(String mensagem)? onErro,
  }) async {
    // Detecta se o campo contém um email ou um nome de usuário
    final isEmail = email.contains('@');

    if (await _online()) {
      if (isEmail) {
        return _loginOnlineEmail(email: email, senha: senha, onErro: onErro);
      } else {
        return _loginOnlineNome(nome: email, senha: senha, onErro: onErro);
      }
    } else {
      return _loginOffline(
          identificador: email, senha: senha, isEmail: isEmail, onErro: onErro);
    }
  }

  Future<Usuario?> _loginOnlineEmail({
    required String email,
    required String senha,
    void Function(String mensagem)? onErro,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: senha,
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        onErro?.call('Credenciais inválidas.');
        return null;
      }

      final usuario =
          await _persistirUsuarioSupabase(supabaseUser: supabaseUser);

      // Atualiza hash local após login online com sucesso
      if (usuario != null) {
        await DatabaseHelper.instance.update(
          'usuarios',
          {'senha_hash': _hashSenha(senha)},
          'id = ?',
          [usuario.id],
        );
      }

      return usuario;
    } on AuthException catch (e) {
      onErro?.call(_traduzirErroSupabase(e.message));
      return null;
    } catch (e) {
      // Tenta offline como fallback
      debugPrint('Login online falhou, tentando offline: $e');
      return _loginOffline(
          identificador: email, senha: senha, isEmail: true, onErro: onErro);
    }
  }

  /// Login por nome de usuário: busca email no SQLite e autentica no Supabase.
  Future<Usuario?> _loginOnlineNome({
    required String nome,
    required String senha,
    void Function(String mensagem)? onErro,
  }) async {
    final db = DatabaseHelper.instance;

    // Primeiro tenta encontrar o usuário pelo nome localmente
    final rows = await db.query(
      'usuarios',
      where: 'LOWER(nome) = LOWER(?)',
      whereArgs: [nome],
    );

    if (rows.isNotEmpty) {
      final email = rows.first['email'] as String? ?? '';
      if (email.isNotEmpty) {
        return _loginOnlineEmail(email: email, senha: senha, onErro: onErro);
      }
    }

    // Se não achou localmente, tenta no Supabase por nome
    try {
      final remoto = await _supabase
          .from('usuarios')
          .select('email')
          .ilike('nome', nome)
          .limit(1);

      if (remoto.isNotEmpty) {
        final emailRemoto = remoto.first['email'] as String? ?? '';
        if (emailRemoto.isNotEmpty) {
          return _loginOnlineEmail(
              email: emailRemoto, senha: senha, onErro: onErro);
        }
      }
    } catch (_) {}

    onErro?.call('Usuário não encontrado.');
    return null;
  }

  /// Login totalmente offline — valida senha_hash no SQLite.
  Future<Usuario?> _loginOffline({
    required String identificador,
    required String senha,
    required bool isEmail,
    void Function(String mensagem)? onErro,
  }) async {
    final db = DatabaseHelper.instance;

    final rows = await db.query(
      'usuarios',
      where: isEmail
          ? 'email = ?'
          : 'LOWER(nome) = LOWER(?)',
      whereArgs: [identificador],
    );

    if (rows.isEmpty) {
      onErro?.call(
          'Usuário não encontrado. Faça login online pelo menos uma vez para habilitar acesso offline.');
      return null;
    }

    final row = rows.first;
    final hashSalvo = row['senha_hash'] as String?;

    if (hashSalvo == null || hashSalvo.isEmpty) {
      onErro?.call(
          'Senha offline não configurada. Conecte-se à internet para fazer login.');
      return null;
    }

    if (hashSalvo != _hashSenha(senha)) {
      onErro?.call('Senha incorreta.');
      return null;
    }

    return Usuario.fromMap(row);
  }

  // ──────────────────────────────────────────────────────────
  // LOGIN COM GOOGLE
  // ──────────────────────────────────────────────────────────

  Future<Usuario?> signInWithGoogle({
    void Function(String mensagem)? onErro,
  }) async {
    // Google exige conexão — não há como autenticar offline pela primeira vez.
    // Se já existe uma sessão Firebase ativa em cache, o SDK pode revalidá-la
    // sem rede; caso contrário, informamos o usuário claramente.
    if (!await _online()) {
      // Tenta usar sessão Firebase já em cache (o SDK persiste o token localmente)
      final cached = _firebaseAuth.currentUser;
      if (cached != null) {
        final rows = await DatabaseHelper.instance.query(
          'usuarios',
          where: 'firebase_uid = ?',
          whereArgs: [cached.uid],
        );
        if (rows.isNotEmpty) return Usuario.fromMap(rows.first);
      }

      // Tenta usar sessão Supabase em cache
      final supabaseCached = _supabase.auth.currentUser;
      if (supabaseCached != null) {
        final rows = await DatabaseHelper.instance.query(
          'usuarios',
          where: 'id = ?',
          whereArgs: [supabaseCached.id],
        );
        if (rows.isNotEmpty) return Usuario.fromMap(rows.first);
      }

      onErro?.call(
        'Login com Google requer conexão com a internet. '
        'Use email e senha para entrar offline.',
      );
      return null;
    }

    try {
      fb.User? firebaseUser;

      if (kIsWeb) {
        final credential =
            await _firebaseAuth.signInWithPopup(fb.GoogleAuthProvider());
        firebaseUser = credential.user;
      } else {
        final googleUser = await _googleSignIn.signIn();
        if (googleUser == null) return null;

        final googleAuth = await googleUser.authentication;
        final credential = fb.GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        final userCredential =
            await _firebaseAuth.signInWithCredential(credential);
        firebaseUser = userCredential.user;
      }

      if (firebaseUser == null) {
        onErro?.call('Não foi possível autenticar com Google.');
        return null;
      }

      return await _persistirUsuarioFirebase(firebaseUser);
    } catch (e) {
      debugPrint('Erro no login com Google: $e');
      onErro?.call('Erro ao entrar com Google. Verifique sua conexão.');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // LOGOUT
  // ──────────────────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
    } catch (_) {}

    try {
      if (!kIsWeb) await _googleSignIn.signOut();
      await _firebaseAuth.signOut();
    } catch (_) {}
  }

  // ──────────────────────────────────────────────────────────
  // GARANTIR USUÁRIO NO SUPABASE
  // Chame antes de qualquer operação que exija FK para usuarios.
  // Resolve o caso de login Google cujo upsert falhou silenciosamente.
  // ──────────────────────────────────────────────────────────

  Future<void> garantirUsuarioNoSupabase(Usuario usuario) async {
    if (!await _online()) return;
    try {
      // Verifica se já existe
      final existe = await _supabase
          .from('usuarios')
          .select('id')
          .eq('id', usuario.id)
          .maybeSingle();
      if (existe != null) return; // já existe, nada a fazer

      // Não existe: insere agora
      await _supabase.from('usuarios').upsert({
        'id': usuario.id,
        'nome': usuario.nome,
        'email': usuario.email,
        'avatar_url': usuario.avatarUrl,
        'role': usuario.role,
        'ativo': true,
        'criado_em': usuario.criadoEm.toIso8601String(),
        'atualizado_em': usuario.atualizadoEm.toIso8601String(),
      }, onConflict: 'id');
      debugPrint('garantirUsuarioNoSupabase: upsert OK para ${usuario.id}');
    } catch (e) {
      debugPrint('garantirUsuarioNoSupabase falhou: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // USUÁRIO ATUAL
  // ──────────────────────────────────────────────────────────

  Future<Usuario?> getUsuarioInterno() async {
    try {
      final supabaseUser = _supabase.auth.currentUser;
      if (supabaseUser != null) {
        final rows = await DatabaseHelper.instance.query(
          'usuarios',
          where: 'id = ?',
          whereArgs: [supabaseUser.id],
        );
        if (rows.isNotEmpty) return Usuario.fromMap(rows.first);

        return await _persistirUsuarioSupabase(supabaseUser: supabaseUser)
            .timeout(const Duration(seconds: 5));
      }

      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        final rows = await DatabaseHelper.instance.query(
          'usuarios',
          where: 'firebase_uid = ?',
          whereArgs: [firebaseUser.uid],
        );
        if (rows.isNotEmpty) return Usuario.fromMap(rows.first);
      }

      // Fallback: retorna o último usuário ativo registrado localmente.
      // Cobre tanto contas criadas offline (criado_offline=1) quanto
      // contas online que já fizeram login ao menos uma vez (criado_offline=0).
      final localRows = await DatabaseHelper.instance.query(
        'usuarios',
        where: 'ativo = 1',
        orderBy: 'atualizado_em DESC',
        limit: 1,
      );
      if (localRows.isNotEmpty) {
        return Usuario.fromMap(localRows.first);
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  bool get estaLogado =>
      _supabase.auth.currentUser != null || _firebaseAuth.currentUser != null;

  // ──────────────────────────────────────────────────────────
  // PERSISTÊNCIA INTERNA
  // ──────────────────────────────────────────────────────────

  Future<Usuario?> _persistirUsuarioSupabase({
    required User supabaseUser,
    String? nomeOverride,
  }) async {
    final db = DatabaseHelper.instance;
    final agora = DateTime.now();

    // Resolve nome: prioriza override > metadados Supabase > nome salvo localmente > prefixo do email
    // Isso evita substituir um nome já cadastrado pelo usuário com "Usuário" genérico
    final metaNome = supabaseUser.userMetadata?['nome'] as String? ??
        supabaseUser.userMetadata?['full_name'] as String?;

    // Busca nome já salvo no SQLite para não perder em logins offline
    String? nomeSalvoLocal;
    try {
      final savedRows = await DatabaseHelper.instance.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [supabaseUser.id],
      );
      if (savedRows.isNotEmpty) {
        nomeSalvoLocal = savedRows.first['nome'] as String?;
      }
    } catch (_) {}

    final nome = nomeOverride ??
        (metaNome?.isNotEmpty == true ? metaNome : null) ??
        (nomeSalvoLocal?.isNotEmpty == true ? nomeSalvoLocal : null) ??
        supabaseUser.email?.split('@').first ??
        'Usuário';

    final email = supabaseUser.email ?? '';
    final avatarUrl = supabaseUser.userMetadata?['avatar_url'] as String?;

    // ── Busca role atual no Supabase ──────────────────────────
    String roleAtual = 'leitor';
    try {
      final rows = await _supabase
          .from('usuarios')
          .select('role')
          .eq('id', supabaseUser.id)
          .limit(1);
      if (rows.isNotEmpty) {
        roleAtual = rows.first['role'] as String? ?? 'leitor';
      }
    } catch (_) {}

    // ── SQLite ────────────────────────────────────────────────
    final localRows = await db.query(
      'usuarios',
      where: 'id = ?',
      whereArgs: [supabaseUser.id],
    );

    final Usuario usuario;

    if (localRows.isNotEmpty) {
      // Preserva senha_hash existente
      final hashExistente = localRows.first['senha_hash'] as String?;
      usuario = Usuario.fromMap(localRows.first).copyWith(
        nome: nome,
        avatarUrl: avatarUrl,
        role: roleAtual,
      );
      await db.update(
        'usuarios',
        {
          'nome': usuario.nome,
          'avatar_url': usuario.avatarUrl,
          'role': roleAtual,
          'atualizado_em': agora.toIso8601String(),
          'criado_offline': 0,
          if (hashExistente != null) 'senha_hash': hashExistente,
        },
        'id = ?',
        [supabaseUser.id],
      );
    } else {
      usuario = Usuario(
        id: supabaseUser.id,
        nome: nome,
        email: email,
        avatarUrl: avatarUrl,
        role: roleAtual,
        ativo: true,
        criadoEm: agora,
        atualizadoEm: agora,
      );
      await db.insert('usuarios', {
        ...usuario.toMap(),
        'criado_offline': 0,
      });
    }

    // Upsert sem sobrescrever role
    try {
      await _supabase.from('usuarios').upsert({
        'id': usuario.id,
        'nome': usuario.nome,
        'email': email,
        'avatar_url': avatarUrl,
        'atualizado_em': agora.toIso8601String(),
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Supabase upsert usuario falhou: $e');
    }

    return usuario;
  }

  Future<Usuario?> _persistirUsuarioFirebase(fb.User firebaseUser) async {
    final db = DatabaseHelper.instance;
    final agora = DateTime.now();

    final rows = await db.query(
      'usuarios',
      where: 'firebase_uid = ?',
      whereArgs: [firebaseUser.uid],
    );

    final Usuario usuario;

    if (rows.isNotEmpty) {
      usuario = Usuario.fromMap(rows.first).copyWith(
        nome: firebaseUser.displayName ?? rows.first['nome'] as String,
        avatarUrl: firebaseUser.photoURL,
      );
      await db.update(
        'usuarios',
        {
          'nome': usuario.nome,
          'avatar_url': usuario.avatarUrl,
          'atualizado_em': agora.toIso8601String(),
          'criado_offline': 0,
        },
        'firebase_uid = ?',
        [firebaseUser.uid],
      );
    } else {
      usuario = Usuario(
        id: _uuid.v4(),
        firebaseUid: firebaseUser.uid,
        nome: firebaseUser.displayName ?? 'Usuário',
        email: firebaseUser.email ?? '',
        avatarUrl: firebaseUser.photoURL,
        role: 'leitor',
        ativo: true,
        criadoEm: agora,
        atualizadoEm: agora,
      );
      await db.insert('usuarios', {
        ...usuario.toMap(),
        'criado_offline': 0,
      });
    }

    await _upsertUsuarioSupabase(usuario);
    return usuario;
  }

  Future<void> _upsertUsuarioSupabase(Usuario usuario) async {
    try {
      await _supabase.from('usuarios').upsert(
            usuario.toSupabase(),
            onConflict: 'id',
            ignoreDuplicates: false,
          );
    } catch (e) {
      debugPrint('Supabase upsert usuario falhou: $e');
    }
  }

  // ──────────────────────────────────────────────────────────
  // HELPERS
  // ──────────────────────────────────────────────────────────

  String _traduzirErroSupabase(String mensagem) {
    final m = mensagem.toLowerCase();
    if (m.contains('invalid login credentials') ||
        m.contains('invalid credentials')) {
      return 'Email ou senha incorretos.';
    }
    if (m.contains('email not confirmed')) {
      return 'Confirme seu email antes de entrar.';
    }
    if (m.contains('user already registered') ||
        m.contains('already been registered')) {
      return 'Este email já está cadastrado.';
    }
    if (m.contains('password should be at least')) {
      return 'A senha deve ter pelo menos 6 caracteres.';
    }
    if (m.contains('unable to validate email address')) {
      return 'Email inválido.';
    }
    if (m.contains('network') || m.contains('connection')) {
      return 'Sem conexão. Verifique sua internet.';
    }
    return mensagem;
  }
}