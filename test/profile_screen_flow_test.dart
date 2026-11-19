import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:gestao_financeira/app.dart';
import 'package:gestao_financeira/models/app_user.dart';
import 'package:gestao_financeira/models/business_profile_data.dart';
import 'package:gestao_financeira/models/finance_transaction.dart';
import 'package:gestao_financeira/models/financial_profile.dart';
import 'package:gestao_financeira/models/monthly_limit.dart';
import 'package:gestao_financeira/models/picked_profile_image.dart';
import 'package:gestao_financeira/models/services/account_service.dart';
import 'package:gestao_financeira/models/services/finance_repository.dart';
import 'package:gestao_financeira/models/services/financial_profile_repository.dart';
import 'package:gestao_financeira/models/services/monthly_limit_repository.dart';
import 'package:gestao_financeira/models/services/profile_details_repository.dart';
import 'package:gestao_financeira/screens/profile_screen.dart';

const _ana = AppUser(id: 'user-a', email: 'ana@teste.com', name: 'Ana Silva');
const _bia = AppUser(id: 'user-b', email: 'bia@teste.com', name: 'Bia Souza');

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'perfil pessoal salva nome confirmado e preserva e-mail da conta',
    (tester) async {
      final harness = _Harness();
      await _mount(tester, harness);
      await _tab(tester, 'Perfil');
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-name-input')),
      );
      expect(_input(tester, 'profile-name-input'), 'Ana Silva');
      final email = find.byKey(const ValueKey('profile-email-input'));
      final emailField = find.descendant(
        of: email,
        matching: find.byType(TextField),
      );
      expect(tester.widget<TextField>(emailField).readOnly, isTrue);
      await _enter(tester, 'profile-name-input', '  Ana Amaral  ');
      final gate = Completer<void>();
      harness.details.personalGate = gate;
      await _beginSave(tester);
      expect(harness.accounts.currentUser!.name, 'Ana Silva');
      expect(harness.details.personalCalls, 1);
      expect(find.byKey(const ValueKey('profile-name-input')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('save-profile')));
      await tester.pump();
      expect(harness.details.personalCalls, 1);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('profile-name-input')), findsOneWidget);
      expect(find.text('Dados atualizados com sucesso.'), findsOneWidget);
      expect(_screen(tester).user.name, 'Ana Amaral');
      expect(_screen(tester).user.email, _ana.email);
      expect(harness.profiles.state(_ana.id).profiles.last.name, 'Empresa');
      await _tab(tester, 'Início');
      expect(find.text('Olá, Ana'), findsOneWidget);
      await _remount(tester, harness);
      await _tab(tester, 'Perfil');
      expect(_screen(tester).user.name, 'Ana Amaral');
      expect(_screen(tester).user.email, _ana.email);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dados empresariais persistem separados e erro mantém a edição disponível',
    (tester) async {
      final harness = _Harness();
      await _mount(tester, harness);
      await _profile(tester, 'business');
      await _tab(tester, 'Perfil');
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-name-input')),
      );
      await _enter(tester, 'profile-name-input', 'Loja da Ana');
      await _enter(tester, 'business-legal-name-input', 'Ana Comércio Ltda');
      await _enter(tester, 'business-cnpj-input', '00.000.000/E08G-12');
      await _enter(tester, 'business-contact-email-input', 'loja@teste.com');
      await _enter(tester, 'business-phone-input', '(71) 99999-1234');
      harness.details.businessError = const FinanceException(
        'Não foi possível salvar os dados da empresa.',
      );
      await _save(tester);
      expect(
        find.text('Não foi possível salvar os dados da empresa.'),
        findsOneWidget,
      );
      expect(_input(tester, 'profile-name-input'), 'Loja da Ana');
      expect(_input(tester, 'business-contact-email-input'), 'loja@teste.com');
      expect(harness.profiles.state(_ana.id).activeProfile.name, 'Empresa');

      harness.details.businessError = null;
      await _save(tester);
      final saved = harness.profiles.state(_ana.id).activeProfile;
      expect(saved.name, 'Loja da Ana');
      expect(saved.legalName, 'Ana Comércio Ltda');
      expect(saved.cnpj, '00000000E08G12');
      expect(saved.contactEmail, 'loja@teste.com');
      expect(saved.contactPhone, '(71) 99999-1234');
      expect(_screen(tester).financialProfile!.cnpj, '00000000E08G12');
      expect(harness.accounts.currentUser!.name, _ana.name);
      expect(harness.accounts.currentUser!.email, _ana.email);

      await _profile(tester, 'personal');
      expect(_screen(tester).user.name, _ana.name);
      expect(_screen(tester).financialProfile!.cnpj, isNull);
      expect(_screen(tester).financialProfile!.contactEmail, isNull);
      await _profile(tester, 'business');
      await _remount(tester, harness);
      await _tab(tester, 'Perfil');
      expect(_screen(tester).financialProfile!.name, 'Loja da Ana');
      expect(_screen(tester).financialProfile!.cnpj, '00000000E08G12');
      await tester.ensureVisible(
        find.byKey(const ValueKey('profile-name-input')),
      );
      expect(_input(tester, 'profile-name-input'), 'Loja da Ana');
      expect(_input(tester, 'business-legal-name-input'), 'Ana Comércio Ltda');
      expect(_input(tester, 'business-contact-email-input'), 'loja@teste.com');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fotos são confirmadas e removidas somente no perfil escolhido', (
    tester,
  ) async {
    final harness = _Harness();
    await _mount(tester, harness);
    await _tab(tester, 'Perfil');
    harness.picks.add(_image());
    final gate = Completer<void>();
    harness.details.uploadGate = gate;
    await _beginTap(tester, find.byKey(const ValueKey('choose-profile-photo')));
    expect(harness.details.uploadCalls, 1);
    expect(_screen(tester).financialProfile!.avatarPath, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    final personalPhoto = _screen(tester).financialProfile!.avatarPath!;
    expect(personalPhoto, startsWith('${_ana.id}/personal/'));
    expect(find.byKey(const ValueKey('remove-profile-photo')), findsOneWidget);

    harness.details.uploadGate = null;
    await _profile(tester, 'business');
    expect(_screen(tester).financialProfile!.avatarPath, isNull);
    harness.picks.add(_image());
    await _tap(tester, find.byKey(const ValueKey('choose-profile-photo')));
    final businessPhoto = _screen(tester).financialProfile!.avatarPath!;
    expect(businessPhoto, startsWith('${_ana.id}/business/'));
    expect(businessPhoto, isNot(personalPhoto));
    await _tap(tester, find.byKey(const ValueKey('remove-profile-photo')));
    expect(_screen(tester).financialProfile!.avatarPath, isNull);
    expect(harness.details.removeCalls, 1);
    expect(
      harness.profiles.profile(_ana.id, 'personal').avatarPath,
      personalPhoto,
    );

    final calls = harness.details.uploadCalls;
    harness.picks.add(null);
    await _tap(tester, find.byKey(const ValueKey('choose-profile-photo')));
    expect(harness.details.uploadCalls, calls);
    expect(_screen(tester).financialProfile!.avatarPath, isNull);

    await _profile(tester, 'personal');
    harness.details.uploadError = const FinanceException(
      'Não foi possível enviar a foto.',
    );
    harness.picks.add(_image());
    await _tap(tester, find.byKey(const ValueKey('choose-profile-photo')));
    expect(find.text('Não foi possível enviar a foto.'), findsOneWidget);
    expect(_screen(tester).financialProfile!.avatarPath, personalPhoto);
    expect(tester.takeException(), isNull);
  });

  testWidgets('foto pendente da conta anterior não aparece na nova conta', (
    tester,
  ) async {
    final harness = _Harness();
    await _mount(tester, harness);
    await _tab(tester, 'Perfil');
    harness.picks.add(_image());
    final gate = Completer<void>();
    harness.details.uploadGate = gate;
    await _beginTap(tester, find.byKey(const ValueKey('choose-profile-photo')));
    expect(harness.details.uploadCalls, 1);
    harness.accounts.switchTo(_bia);
    await tester.pumpAndSettle();
    await _tab(tester, 'Perfil');
    expect(_screen(tester).user.id, _bia.id);
    expect(_screen(tester).financialProfile!.avatarPath, isNull);
    gate.complete();
    await tester.pumpAndSettle();
    expect(_screen(tester).user.id, _bia.id);
    expect(_screen(tester).financialProfile!.avatarPath, isNull);
    expect(harness.profiles.profile(_bia.id, 'personal').avatarPath, isNull);
    expect(
      harness.profiles.profile(_ana.id, 'personal').avatarPath,
      startsWith('${_ana.id}/personal/'),
    );
    expect(find.text('Não foi possível enviar a foto.'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

PickedProfileImage _image() => PickedProfileImage(
  bytes: base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+iN1sAAAAASUVORK5CYII=',
  ),
  contentType: 'image/png',
);

Future<void> _mount(WidgetTester tester, _Harness harness) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 800);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await harness.accounts.close();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
}

Future<void> _remount(WidgetTester tester, _Harness harness) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
  await tester.pumpWidget(harness.app());
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _beginTap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}

Future<void> _enter(WidgetTester tester, String key, String text) async {
  final field = find.byKey(ValueKey(key));
  await tester.ensureVisible(field);
  await tester.enterText(field, text);
  await tester.pump();
}

String _input(WidgetTester tester, String key) {
  final widget = tester.widget(find.byKey(ValueKey(key)));
  return switch (widget) {
    TextField() => widget.controller!.text,
    TextFormField() => widget.controller!.text,
    _ => throw StateError('Campo sem controlador: $key'),
  };
}

Future<void> _tab(WidgetTester tester, String label) =>
    _tap(tester, find.text(label).last);
Future<void> _profile(WidgetTester tester, String id) =>
    _tap(tester, find.byKey(ValueKey('profile-$id')));
Future<void> _save(WidgetTester tester) =>
    _tap(tester, find.byKey(const ValueKey('save-profile')));
Future<void> _beginSave(WidgetTester tester) =>
    _beginTap(tester, find.byKey(const ValueKey('save-profile')));
ProfileScreen _screen(WidgetTester tester) =>
    tester.widget<ProfileScreen>(find.byType(ProfileScreen));

class _Harness {
  final accounts = _Accounts();
  late final profiles = _Profiles(accounts);
  late final details = _Details(accounts, profiles);
  final picks = Queue<PickedProfileImage?>();
  final _finances = <String, _Finance>{};
  final _budgets = <String, _Budget>{};

  _Finance finance(String id) => _finances.putIfAbsent(id, () => _Finance());
  _Budget budget(String id) => _budgets.putIfAbsent(id, () => _Budget());
  Widget app() => MyApp(
    accountService: accounts,
    repository: finance('personal'),
    monthlyLimitRepository: budget('personal'),
    profileRepository: profiles,
    financeRepositoryForProfile: finance,
    monthlyLimitRepositoryForProfile: budget,
    profileDetailsRepository: details,
    imagePicker: () async => picks.isEmpty ? null : picks.removeFirst(),
  );
}

class _Accounts implements AccountService {
  final _changes = StreamController<AppUser?>.broadcast(sync: true);
  AppUser? _user = _ana;
  @override
  AppUser? get currentUser => _user;
  @override
  Stream<AppUser?> get userChanges => _changes.stream;
  void switchTo(AppUser? user) {
    _user = user;
    _changes.add(user);
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async => switchTo(email == _bia.email ? _bia : _ana);
  @override
  Future<void> signOut() async => switchTo(null);
  @override
  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
  }) async => false;
  Future<void> close() => _changes.close();
}

class _Profiles implements FinancialProfileRepository {
  final _Accounts accounts;
  final _states = <String, FinancialProfileState>{};
  _Profiles(this.accounts);

  FinancialProfileState state(String userId) => _states.putIfAbsent(
    userId,
    () => FinancialProfileState(
      profiles: [
        FinancialProfile(
          id: 'personal',
          userId: userId,
          kind: FinancialProfileKind.personal,
          name: 'Pessoal',
        ),
        FinancialProfile(
          id: 'business',
          userId: userId,
          kind: FinancialProfileKind.business,
          name: 'Empresa',
        ),
      ],
      activeProfileId: 'personal',
    ),
  );
  FinancialProfile profile(String userId, String profileId) =>
      state(userId).profiles.singleWhere((profile) => profile.id == profileId);
  void replace(FinancialProfile updated) {
    final previous = state(updated.userId);
    _states[updated.userId] = FinancialProfileState(
      profiles: [
        for (final profile in previous.profiles)
          if (profile.id == updated.id) updated else profile,
      ],
      activeProfileId: previous.activeProfileId,
    );
  }

  @override
  Future<FinancialProfileState> loadProfiles() async =>
      state(accounts.currentUser!.id);
  @override
  Future<void> selectProfile(String profileId) async {
    final userId = accounts.currentUser!.id;
    _states[userId] = FinancialProfileState(
      profiles: state(userId).profiles,
      activeProfileId: profileId,
    );
  }

  @override
  Future<FinancialProfile> renameBusiness({
    required String profileId,
    required String name,
  }) async {
    final original = profile(accounts.currentUser!.id, profileId);
    final updated = FinancialProfile.fromJson({
      ...original.toJson(),
      'name': name.trim(),
    });
    replace(updated);
    return updated;
  }
}

class _Details implements ProfileDetailsRepository {
  final _Accounts accounts;
  final _Profiles profiles;
  Completer<void>? personalGate;
  Completer<void>? uploadGate;
  FinanceException? businessError;
  FinanceException? uploadError;
  int personalCalls = 0;
  int businessCalls = 0;
  int uploadCalls = 0;
  int removeCalls = 0;
  _Details(this.accounts, this.profiles);

  @override
  Future<AppUser> updatePersonalName(String name) async {
    personalCalls++;
    final before = accounts.currentUser!;
    await personalGate?.future;
    final updated = AppUser(
      id: before.id,
      email: before.email,
      name: name.trim(),
    );
    if (accounts.currentUser?.id == before.id) accounts.switchTo(updated);
    return updated;
  }

  @override
  Future<FinancialProfile> updateBusiness({
    required String profileId,
    required BusinessProfileData data,
  }) async {
    businessCalls++;
    final original = profiles.profile(accounts.currentUser!.id, profileId);
    final error = businessError;
    if (error != null) throw error;
    final updated = FinancialProfile.fromJson({
      ...original.toJson(),
      ...data.toJson(),
    });
    profiles.replace(updated);
    return updated;
  }

  @override
  Future<FinancialProfile> uploadPhoto({
    required String profileId,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final serial = ++uploadCalls;
    final userId = accounts.currentUser!.id;
    final original = profiles.profile(userId, profileId);
    await uploadGate?.future;
    final error = uploadError;
    if (error != null) throw error;
    final updated = FinancialProfile.fromJson({
      ...original.toJson(),
      'avatar_path': '$userId/$profileId/photo-$serial.png',
    });
    profiles.replace(updated);
    return updated;
  }

  @override
  Future<FinancialProfile> removePhoto(String profileId) async {
    removeCalls++;
    final original = profiles.profile(accounts.currentUser!.id, profileId);
    final updated = FinancialProfile.fromJson({
      ...original.toJson(),
      'avatar_path': null,
    });
    profiles.replace(updated);
    return updated;
  }
}

class _Finance implements FinanceRepository {
  @override
  Stream<void> get changes => const Stream.empty();
  @override
  Future<List<FinanceTransaction>> loadTransactions() async => const [];
  @override
  Future<void> addTransaction({
    required TransactionType type,
    required int amountCents,
    required TransactionCategory category,
    required String description,
    required DateTime occurredOn,
  }) async => throw UnimplementedError();
  @override
  Future<FinanceTransaction> updateTransactionDescription({
    required String transactionId,
    required String description,
  }) async => throw UnimplementedError();
}

class _Budget implements MonthlyLimitRepository {
  @override
  Future<MonthlyLimit?> loadForMonth(DateTime month) async => null;
  @override
  Future<MonthlyLimit> saveForMonth({
    required DateTime month,
    required int limitCents,
  }) async => throw UnimplementedError();
}
