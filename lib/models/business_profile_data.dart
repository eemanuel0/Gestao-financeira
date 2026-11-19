import '../utils/profile_validators.dart';

class BusinessProfileData {
  final String name;
  final String? legalName;
  final String? cnpj;
  final String? contactEmail;
  final String? contactPhone;

  BusinessProfileData({
    required String name,
    String? legalName,
    String? cnpj,
    String? contactEmail,
    String? contactPhone,
  }) : name = name.trim(),
       legalName = _optional(legalName),
       cnpj = _normalizedCnpj(cnpj),
       contactEmail = _optional(contactEmail),
       contactPhone = _optional(contactPhone) {
    if (this.name.isEmpty || this.name.length > 60) {
      throw ArgumentError('O nome deve ter entre 1 e 60 caracteres.');
    }
    if (this.legalName != null && this.legalName!.length > 120) {
      throw ArgumentError('A razão social deve ter até 120 caracteres.');
    }
    if (this.contactEmail != null &&
        (this.contactEmail!.length > 254 ||
            !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                .hasMatch(this.contactEmail!))) {
      throw ArgumentError('Informe um e-mail de contato válido.');
    }
    final phone = this.contactPhone;
    if (phone != null) {
      final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.length > 32 ||
          !RegExp(r'^\+?[0-9()\s.-]+$').hasMatch(phone) ||
          digits.length < 8 ||
          digits.length > 15) {
        throw ArgumentError('Informe um telefone válido com 8 a 15 dígitos.');
      }
    }
  }

  static String? _optional(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String? _normalizedCnpj(String? value) {
    final optional = _optional(value);
    if (optional == null) return null;
    if (!isValidCnpj(optional)) throw ArgumentError('Informe um CNPJ válido.');
    return normalizeCnpj(optional);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'legal_name': legalName,
    'cnpj': cnpj,
    'contact_email': contactEmail,
    'contact_phone': contactPhone,
  };
}
