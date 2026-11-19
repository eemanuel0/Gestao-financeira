import 'package:flutter_test/flutter_test.dart';
import 'package:gestao_financeira/models/business_profile_data.dart';
import 'package:gestao_financeira/models/financial_profile.dart';
import 'package:gestao_financeira/utils/profile_validators.dart';

void main() {
  test('CNPJ aceita formatos numérico e alfanumérico com dígitos corretos', () {
    expect(isValidCnpj('11.222.333/0001-81'), isTrue);
    expect(isValidCnpj('00.000.000/E08G-12'), isTrue);
    expect(isValidCnpj(' 00.000.000/e08g-12 '), isTrue);
    expect(normalizeCnpj('00.000.000/e08g-12'), '00000000E08G12');
    expect(formatCnpj('00000000E08G12'), '00.000.000/E08G-12');
    for (final invalid in [
      '',
      '00000000000000',
      '11111111111111',
      '11.222.333/0001-82',
      '00.000.000/E08G-13',
      '00.000.000/E08G-1A',
      '00.000.000/E08G_12',
      '00.000.000/É08G-12',
      '00000000ß0G12',
    ]) {
      expect(isValidCnpj(invalid), isFalse, reason: invalid);
    }
  });

  test('empresa normaliza campos e preserva ausência de CNPJ e contato', () {
    final empty = BusinessProfileData(
      name: '  Minha Loja  ',
      legalName: ' ',
      cnpj: '',
      contactEmail: ' ',
      contactPhone: '',
    );
    expect(empty.toJson(), {
      'name': 'Minha Loja',
      'legal_name': null,
      'cnpj': null,
      'contact_email': null,
      'contact_phone': null,
    });
    final complete = BusinessProfileData(
      name: 'Minha Loja',
      legalName: '  Minha Loja Ltda  ',
      cnpj: '00.000.000/e08g-12',
      contactEmail: ' contato@example.com ',
      contactPhone: ' +55 (71) 99999-9999 ',
    );
    expect(complete.legalName, 'Minha Loja Ltda');
    expect(complete.cnpj, '00000000E08G12');
    expect(complete.contactEmail, 'contato@example.com');
    expect(complete.contactPhone, '+55 (71) 99999-9999');
  });

  test('empresa rejeita dados de identificação inválidos sem truncar', () {
    final constructors = <BusinessProfileData Function()>[
      () => BusinessProfileData(name: ' '),
      () => BusinessProfileData(name: 'a' * 61),
      () => BusinessProfileData(name: 'Loja', legalName: 'a' * 121),
      () => BusinessProfileData(name: 'Loja', cnpj: '123'),
      () => BusinessProfileData(name: 'Loja', contactEmail: 'inválido'),
      () => BusinessProfileData(name: 'Loja', contactPhone: '12345'),
      () => BusinessProfileData(name: 'Loja', contactPhone: '12345678abc'),
      () => BusinessProfileData(name: 'Loja', contactPhone: '1' * 16),
    ];
    for (final build in constructors) {
      expect(build, throwsArgumentError);
    }
  });

  test('perfil legado continua válido e URL assinada nunca é persistida', () {
    final legacy = FinancialProfile.fromJson({
      'id': 'personal',
      'user_id': 'user-a',
      'kind': 'personal',
      'name': 'Pessoal',
    });
    expect(legacy.avatarPath, isNull);
    expect(legacy.avatarUrl, isNull);
    expect(legacy.cnpj, isNull);
    final profile = FinancialProfile.fromJson({
      'id': 'business',
      'user_id': 'user-a',
      'kind': 'business',
      'name': 'Minha Loja',
      'legal_name': 'Minha Loja Ltda',
      'cnpj': '00000000E08G12',
      'contact_email': 'contato@example.com',
      'contact_phone': '71999999999',
      'avatar_path': 'user-a/business/photo.png',
    }).withAvatarUrl('https://example.com/photo?token=temporario');
    expect(profile.avatarUrl, contains('token=temporario'));
    expect(profile.toJson().containsKey('avatar_url'), isFalse);
    expect(profile.toJson().values, isNot(contains(profile.avatarUrl)));
    final cleared = profile.withAvatarUrl(null);
    expect(cleared.toJson(), profile.toJson());
    expect(cleared.avatarUrl, isNull);
    expect(cleared.avatarPath, 'user-a/business/photo.png');
    expect(cleared.legalName, 'Minha Loja Ltda');
  });
}
