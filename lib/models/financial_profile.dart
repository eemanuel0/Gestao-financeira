enum FinancialProfileKind { personal, business }

class FinancialProfile {
  static const String personalId = 'personal';
  static const String businessId = 'business';

  final String id;
  final String userId;
  final String name;
  final FinancialProfileKind kind;
  final String? legalName;
  final String? cnpj;
  final String? contactEmail;
  final String? contactPhone;
  final String? avatarPath;
  final String? avatarUrl;

  FinancialProfile({
    required this.id,
    required this.userId,
    required String name,
    required this.kind,
    this.legalName,
    this.cnpj,
    this.contactEmail,
    this.contactPhone,
    this.avatarPath,
    this.avatarUrl,
  }) : name = name.trim() {
    if (id.trim().isEmpty || id != id.trim() || userId.trim().isEmpty) {
      throw ArgumentError('O perfil precisa de um ID e de um usuário.');
    }
    if (this.name.isEmpty || this.name.length > 60) {
      throw ArgumentError('O nome deve ter entre 1 e 60 caracteres.');
    }
    if ((kind == FinancialProfileKind.personal && id != personalId) ||
        (kind == FinancialProfileKind.business && id == personalId)) {
      throw ArgumentError('O tipo do perfil não corresponde ao seu ID.');
    }
  }

  factory FinancialProfile.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final userId = json['user_id'];
    final name = json['name'];
    final rawKind = json['kind'];
    if (id is! String || userId is! String || name is! String) {
      throw const FormatException('Dados do perfil inválidos.');
    }
    final kind = switch (rawKind) {
      'personal' => FinancialProfileKind.personal,
      'business' => FinancialProfileKind.business,
      _ => throw const FormatException('Tipo de perfil inválido.'),
    };
    try {
      return FinancialProfile(
        id: id,
        userId: userId,
        name: name,
        kind: kind,
        legalName: _optional(json, 'legal_name'),
        cnpj: _optional(json, 'cnpj'),
        contactEmail: _optional(json, 'contact_email'),
        contactPhone: _optional(json, 'contact_phone'),
        avatarPath: _optional(json, 'avatar_path'),
      );
    } on ArgumentError {
      throw const FormatException('Dados do perfil inválidos.');
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'user_id': userId,
    'kind': kind.name,
    'name': name,
    'legal_name': legalName,
    'cnpj': cnpj,
    'contact_email': contactEmail,
    'contact_phone': contactPhone,
    'avatar_path': avatarPath,
  };

  // A URL assinada é temporária e não é gravada no banco.
  FinancialProfile withAvatarUrl(String? url) => FinancialProfile(
    id: id,
    userId: userId,
    name: name,
    kind: kind,
    legalName: legalName,
    cnpj: cnpj,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    avatarPath: avatarPath,
    avatarUrl: url,
  );

  static String? _optional(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('O campo $key precisa ser texto.');
    }
    return value;
  }
}

class FinancialProfileState {
  final List<FinancialProfile> profiles;
  final String activeProfileId;

  FinancialProfileState({
    required List<FinancialProfile> profiles,
    required this.activeProfileId,
  }) : profiles = List<FinancialProfile>.unmodifiable(profiles) {
    final ids = profiles.map((profile) => profile.id).toSet();
    if (ids.length != profiles.length || !ids.contains(activeProfileId)) {
      throw ArgumentError('A seleção dos perfis é inválida.');
    }
    if (!ids.contains(FinancialProfile.personalId) ||
        !ids.contains(FinancialProfile.businessId) ||
        profiles.map((profile) => profile.userId).toSet().length != 1) {
      throw ArgumentError('Os perfis precisam pertencer à mesma conta.');
    }
    for (final profile in profiles) {
      if ((profile.id == FinancialProfile.personalId &&
              profile.kind != FinancialProfileKind.personal) ||
          (profile.id == FinancialProfile.businessId &&
              profile.kind != FinancialProfileKind.business)) {
        throw ArgumentError('Os tipos dos perfis padrão são inválidos.');
      }
    }
  }

  FinancialProfile get activeProfile =>
      profiles.firstWhere((profile) => profile.id == activeProfileId);
}
