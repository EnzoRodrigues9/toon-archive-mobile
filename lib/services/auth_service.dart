import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/database/database_helper.dart';
import '../core/database/supabase_client.dart';
import '../models/usuario.dart';

class AuthService {
  final fb.FirebaseAuth _firebaseAuth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);

  SupabaseClient get _supabase => SupabaseClientHelper.client;

  final _uuid = const Uuid();

  // ──────────────────────────────────────────────────────────
  // CADASTRO COM EMAIL/SENHA
  // ──────────────────────────────────────────────────────────

  Future<Usuario?> cadastrar({
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

      return await _persistirUsuarioSupabase(
        supabaseUser: supabaseUser,
        nomeOverride: nome,
      );
    } on AuthException catch (e) {
      onErro?.call(_traduzirErroSupabase(e.message));
      return null;
    } catch (e) {
      debugPrint('Erro no cadastro: $e');
      onErro?.call('Erro inesperado. Tente novamente.');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // LOGIN COM EMAIL/SENHA
  // ──────────────────────────────────────────────────────────

  Future<Usuario?> loginComEmail({
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

      return await _persistirUsuarioSupabase(supabaseUser: supabaseUser);
    } on AuthException catch (e) {
      onErro?.call(_traduzirErroSupabase(e.message));
      return null;
    } catch (e) {
      debugPrint('Erro no login com email: $e');
      onErro?.call('Erro inesperado. Tente novamente.');
      return null;
    }
  }

  // ──────────────────────────────────────────────────────────
  // LOGIN COM GOOGLE
  // ──────────────────────────────────────────────────────────

  Future<Usuario?> signInWithGoogle({
    void Function(String mensagem)? onErro,
  }) async {
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
      onErro?.call('Erro ao entrar com Google.');
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

    final nome = nomeOverride ??
        supabaseUser.userMetadata?['nome'] as String? ??
        supabaseUser.userMetadata?['full_name'] as String? ??
        supabaseUser.email?.split('@').first ??
        'Usuário';

    final email = supabaseUser.email ?? '';
    final avatarUrl = supabaseUser.userMetadata?['avatar_url'] as String?;

    // ── Busca role atual no Supabase antes de qualquer coisa ──
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
      usuario = Usuario.fromMap(localRows.first).copyWith(
        nome: nome,
        avatarUrl: avatarUrl,
        role: roleAtual, // <-- preserva o role real
      );
      await db.update(
        'usuarios',
        {
          'nome': usuario.nome,
          'avatar_url': usuario.avatarUrl,
          'role': roleAtual, // <-- atualiza localmente também
          'atualizado_em': agora.toIso8601String(),
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
        role: roleAtual, // <-- usa o role do Supabase
        ativo: true,
        criadoEm: agora,
        atualizadoEm: agora,
      );
      await db.insert('usuarios', usuario.toMap());
    }

    // Upsert sem sobrescrever o role
    try {
      await _supabase.from('usuarios').upsert({
        'id': usuario.id,
        'nome': usuario.nome,
        'email': email,
        'avatar_url': avatarUrl,
        'atualizado_em': agora.toIso8601String(),
        // role NÃO incluído — não sobrescreve
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
      await db.insert('usuarios', usuario.toMap());
    }

    await _upsertUsuarioSupabase(usuario);
    return usuario;
  }

  Future<void> _upsertUsuarioSupabase(Usuario usuario) async {
    try {
      // ANTES: sobrescrevia o role
      // await _supabase.from('usuarios').upsert(usuario.toSupabase());

      // DEPOIS: usa upsert mas ignora o role (não sobrescreve)
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
