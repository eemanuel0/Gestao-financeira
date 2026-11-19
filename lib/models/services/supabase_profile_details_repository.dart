import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_user.dart';
import '../business_profile_data.dart';
import '../financial_profile.dart';
import 'finance_repository.dart';
import 'profile_details_repository.dart';

class SupabaseProfileDetailsRepository implements ProfileDetailsRepository {
  static const String photoBucket = 'profile-photos';
  static const int maxPhotoBytes = 5 * 1024 * 1024;
  final SupabaseClient _client;

  SupabaseProfileDetailsRepository(this._client);

  @override
  Future<AppUser> updatePersonalName(String name) async {
    final userId = _requireUserId();
    final normalizedName = name.trim();
    if (normalizedName.isEmpty || normalizedName.length > 60) {
      throw const FinanceException('Informe um nome entre 1 e 60 caracteres.');
    }
    try {
      _checkSession(userId);
      final response = await _client.auth.updateUser(
        UserAttributes(data: {'name': normalizedName}),
      );
      _checkSession(userId);
      final user = response.user;
      if (user == null ||
          user.id != userId ||
          user.userMetadata?['name'] != normalizedName) {
        throw const FinanceException('Não foi possível confirmar seu nome.');
      }
      return AppUser(
        id: user.id,
        email: user.email ?? '',
        name: normalizedName,
      );
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException(
        'Não foi possível alterar seu nome. Tente novamente.',
      );
    }
  }

  @override
  Future<FinancialProfile> updateBusiness({
    required String profileId,
    required BusinessProfileData data,
  }) async {
    final userId = _requireUserId();
    _validateProfileId(profileId);
    if (profileId == FinancialProfile.personalId) {
      throw const FinanceException('Escolha um perfil de empresa.');
    }
    try {
      _checkSession(userId);
      final payload = data.toJson();
      final row = await _client
          .from('financial_profiles')
          .update(payload)
          .eq('user_id', userId)
          .eq('id', profileId)
          .eq('kind', FinancialProfileKind.business.name)
          .select()
          .single();
      _checkSession(userId);
      final profile = _validateProfile(row, userId, profileId);
      if (profile.kind != FinancialProfileKind.business ||
          payload.entries.any((entry) => row[entry.key] != entry.value)) {
        throw const FinanceException(
          'Não foi possível confirmar os dados da empresa.',
        );
      }
      final resolved = await resolveAvatarUrl(_client, profile);
      _checkSession(userId);
      return resolved;
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException(
        'Não foi possível salvar os dados da empresa.',
      );
    }
  }

  @override
  Future<FinancialProfile> uploadPhoto({
    required String profileId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final userId = _requireUserId();
    _validateProfileId(profileId);
    final image = _validateImage(bytes, contentType);
    final photoBytes = Uint8List.fromList(bytes);
    await _validateDecodedImage(photoBytes);
    final previous = await _loadProfile(userId, profileId);
    _checkSession(userId);
    final random = Random.secure();
    final filename = List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    final path = '$userId/$profileId/$filename.${image.extension}';
    var metadataSent = false;
    var committed = false;
    String? signedUrl;

    try {
      _checkSession(userId);
      final uploaded = await _client.storage
          .from(photoBucket)
          .uploadBinary(
            path,
            photoBytes,
            fileOptions: FileOptions(
              contentType: image.contentType,
              upsert: false,
            ),
          );
      _checkSession(userId);
      if (uploaded != '$photoBucket/$path' && uploaded != path) {
        throw const FinanceException(
          'Não foi possível confirmar o envio da foto.',
        );
      }
      signedUrl = await _client.storage
          .from(photoBucket)
          .createSignedUrl(path, 3600);
      _checkSession(userId);
      metadataSent = true;
      final row = await _client
          .from('financial_profiles')
          .update({'avatar_path': path})
          .eq('user_id', userId)
          .eq('id', profileId)
          .select()
          .single();
      final saved = _validateProfile(row, userId, profileId);
      if (saved.avatarPath != path) {
        throw const FinanceException(
          'Não foi possível confirmar a foto do perfil.',
        );
      }
      committed = true;
      _checkSession(userId);
      // A limpeza não transforma uma gravação confirmada em erro de salvamento.
      unawaited(_deleteBestEffort(userId, profileId, previous.avatarPath));
      return saved.withAvatarUrl(signedUrl);
    } catch (error) {
      if (!committed) {
        if (metadataSent && _client.auth.currentUser?.id == userId) {
          // Uma resposta perdida pode ocorrer depois de a alteração ser gravada.
          final confirmed = await _reconcilePhoto(userId, profileId, path);
          if (confirmed != null) {
            unawaited(
              _deleteBestEffort(userId, profileId, previous.avatarPath),
            );
            return confirmed.withAvatarUrl(signedUrl);
          }
        }
        if (!metadataSent || _isDefiniteDatabaseRejection(error)) {
          await _deleteBestEffort(userId, profileId, path);
        }
      }
      if (error is FinanceException) rethrow;
      throw const FinanceException(
        'Não foi possível salvar a foto. Tente novamente.',
      );
    }
  }

  @override
  Future<FinancialProfile> removePhoto(String profileId) async {
    final userId = _requireUserId();
    _validateProfileId(profileId);
    FinancialProfile? previous;
    var metadataSent = false;
    try {
      previous = await _loadProfile(userId, profileId);
      _checkSession(userId);
      metadataSent = true;
      final row = await _client
          .from('financial_profiles')
          .update({'avatar_path': null})
          .eq('user_id', userId)
          .eq('id', profileId)
          .select()
          .single();
      final saved = _validateProfile(row, userId, profileId);
      if (saved.avatarPath != null) {
        throw const FinanceException(
          'Não foi possível confirmar a remoção da foto.',
        );
      }
      _checkSession(userId);
      unawaited(_deleteBestEffort(userId, profileId, previous.avatarPath));
      return saved.withAvatarUrl(null);
    } catch (error) {
      if (metadataSent && _client.auth.currentUser?.id == userId) {
        try {
          // Uma resposta perdida não desfaz uma remoção já confirmada no banco.
          final confirmed = await _loadProfile(userId, profileId);
          _checkSession(userId);
          if (confirmed.avatarPath == null) {
            unawaited(
              _deleteBestEffort(userId, profileId, previous?.avatarPath),
            );
            return confirmed.withAvatarUrl(null);
          }
        } catch (_) {
          // Sem confirmação, mantém o erro e não remove o arquivo antigo.
        }
      }
      if (error is FinanceException) rethrow;
      throw const FinanceException(
        'Não foi possível remover a foto. Tente novamente.',
      );
    }
  }

  Future<FinancialProfile> _loadProfile(String userId, String profileId) async {
    try {
      _checkSession(userId);
      final row = await _client
          .from('financial_profiles')
          .select()
          .eq('user_id', userId)
          .eq('id', profileId)
          .single();
      _checkSession(userId);
      return _validateProfile(row, userId, profileId);
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException('Não foi possível carregar seu perfil.');
    }
  }

  Future<FinancialProfile?> _reconcilePhoto(
    String userId,
    String profileId,
    String path,
  ) async {
    try {
      final profile = await _loadProfile(userId, profileId);
      _checkSession(userId);
      return profile.avatarPath == path ? profile : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteBestEffort(
    String userId,
    String profileId,
    String? path,
  ) async {
    if (path == null ||
        _client.auth.currentUser?.id != userId ||
        !isOwnedAvatarPath(path, userId: userId, profileId: profileId)) {
      return;
    }
    try {
      await _client.storage
          .from(photoBucket)
          .remove([path])
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // O arquivo antigo pode ser limpo depois; os dados já foram confirmados.
    }
  }

  static FinancialProfile _validateProfile(
    Map<String, dynamic> row,
    String userId,
    String profileId,
  ) {
    final profile = FinancialProfile.fromJson(row);
    if (profile.userId != userId || profile.id != profileId) {
      throw const FinanceException(
        'Não foi possível confirmar os dados deste perfil.',
      );
    }
    return profile;
  }

  // Nunca assina ou remove caminhos de outra pessoa ou de outro perfil.
  static bool isOwnedAvatarPath(
    String path, {
    required String userId,
    required String profileId,
  }) {
    final parts = path.split('/');
    return parts.length == 3 &&
        parts[0] == userId &&
        parts[1] == profileId &&
        RegExp(r'^[A-Za-z0-9_-]{1,128}\.(jpg|jpeg|png|webp)$')
            .hasMatch(parts[2]);
  }

  static Future<FinancialProfile> resolveAvatarUrl(
    SupabaseClient client,
    FinancialProfile profile,
  ) async {
    final path = profile.avatarPath;
    if (path == null ||
        client.auth.currentUser?.id != profile.userId ||
        !isOwnedAvatarPath(
          path,
          userId: profile.userId,
          profileId: profile.id,
        )) {
      return profile.withAvatarUrl(null);
    }
    try {
      final url = await client.storage
          .from(photoBucket)
          .createSignedUrl(path, 3600)
          .timeout(const Duration(seconds: 10));
      if (client.auth.currentUser?.id != profile.userId) {
        return profile.withAvatarUrl(null);
      }
      return profile.withAvatarUrl(url);
    } catch (_) {
      return profile.withAvatarUrl(null);
    }
  }

  static ({String extension, String contentType}) _validateImage(
    Uint8List bytes,
    String contentType,
  ) {
    if (bytes.isEmpty || bytes.lengthInBytes > maxPhotoBytes) {
      throw const FinanceException('Escolha uma foto de até 5 MB.');
    }
    String? type;
    if (bytes.length >= 4 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff &&
        bytes[bytes.length - 2] == 0xff &&
        bytes.last == 0xd9) {
      type = 'image/jpeg';
    } else if (bytes.length >= 33 &&
        _hasBytes(bytes, 0, [137, 80, 78, 71, 13, 10, 26, 10]) &&
        _hasBytes(bytes, 12, [73, 72, 68, 82])) {
      type = 'image/png';
    } else if (bytes.length >= 20 &&
        _hasBytes(bytes, 0, [82, 73, 70, 70]) &&
        _hasBytes(bytes, 8, [87, 69, 66, 80]) &&
        (_hasBytes(bytes, 12, [86, 80, 56, 32]) ||
            _hasBytes(bytes, 12, [86, 80, 56, 76]) ||
            _hasBytes(bytes, 12, [86, 80, 56, 88])) &&
        ByteData.sublistView(bytes).getUint32(4, Endian.little) + 8 ==
            bytes.length) {
      type = 'image/webp';
    }
    if (type == null || type != contentType.trim().toLowerCase()) {
      throw const FinanceException(
        'Escolha uma imagem JPEG, PNG ou WebP válida.',
      );
    }
    final extension = switch (type) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      _ => 'webp',
    };
    return (extension: extension, contentType: type);
  }

  static bool _hasBytes(Uint8List bytes, int start, List<int> signature) {
    if (start + signature.length > bytes.length) return false;
    for (var index = 0; index < signature.length; index++) {
      if (bytes[start + index] != signature[index]) return false;
    }
    return true;
  }

  static Future<void> _validateDecodedImage(Uint8List bytes) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? frame;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      // O descritor web não expõe dimensões de imagens codificadas.
      // A decodificação abaixo valida o arquivo em todas as plataformas.
      if (!kIsWeb &&
          (descriptor.width > 8192 ||
              descriptor.height > 8192 ||
              descriptor.width * descriptor.height > 16 * 1024 * 1024)) {
        throw const FinanceException('Escolha uma foto com dimensões menores.');
      }
      codec = await descriptor.instantiateCodec(
        targetWidth: 1,
        targetHeight: 1,
      );
      frame = (await codec.getNextFrame()).image;
    } on FinanceException {
      rethrow;
    } catch (_) {
      throw const FinanceException(
        'Escolha uma imagem JPEG, PNG ou WebP válida.',
      );
    } finally {
      frame?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static bool _isDefiniteDatabaseRejection(Object error) =>
      error is PostgrestException &&
      (error.code?.startsWith('23') == true ||
          error.code?.startsWith('42') == true);

  String _requireUserId() {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const FinanceException('Entre na sua conta para continuar.');
    }
    return user.id;
  }

  void _checkSession(String userId) {
    if (_client.auth.currentUser?.id != userId) {
      throw const FinanceException('Sua sessão mudou. Entre novamente.');
    }
  }

  void _validateProfileId(String profileId) {
    if (profileId.trim().isEmpty ||
        profileId != profileId.trim() ||
        profileId.contains('/') ||
        profileId.contains('\\')) {
      throw const FinanceException('Escolha um perfil válido.');
    }
  }
}
