import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/app_colors.dart';
import '../models/app_user.dart';
import '../models/business_profile_data.dart';
import '../models/financial_profile.dart';
import '../models/picked_profile_image.dart';
import '../models/services/account_service.dart';
import '../models/services/family_group_repository.dart';
import '../models/services/finance_repository.dart';
import '../models/services/financial_profile_repository.dart';
import '../models/services/monthly_limit_repository.dart';
import '../models/services/profile_details_repository.dart';
import '../widgets/app_header.dart';
import 'family_group_screen.dart';
import 'home_screen.dart';

// Mantém os serviços de cada perfil separados durante toda a sessão.
class FinancialWorkspace extends StatefulWidget {
  final AppUser user;
  final AccountService accountService;
  final FinancialProfileRepository profileRepository;
  final FinanceRepository Function(FinancialProfile profile)
  financeRepositoryForProfile;
  final MonthlyLimitRepository Function(FinancialProfile profile)
  monthlyLimitRepositoryForProfile;
  final ProfileDetailsRepository? profileDetailsRepository;
  final FamilyGroupRepository? familyGroupRepository;
  final Future<PickedProfileImage?> Function()? imagePicker;

  const FinancialWorkspace({
    super.key,
    required this.user,
    required this.accountService,
    required this.profileRepository,
    required this.financeRepositoryForProfile,
    required this.monthlyLimitRepositoryForProfile,
    this.profileDetailsRepository,
    this.familyGroupRepository,
    this.imagePicker,
  });

  @override
  State<FinancialWorkspace> createState() => _FinancialWorkspaceState();
}

class _FinancialWorkspaceState extends State<FinancialWorkspace>
    with WidgetsBindingObserver {
  final _financeRepositories = <(String, String), FinanceRepository>{};
  final _limitRepositories = <(String, String), MonthlyLimitRepository>{};
  Timer? _familyRefresh;
  List<FinancialProfile> _profiles = const [];
  String? _activeProfileId;
  bool _loading = true;
  bool _switching = false;
  bool _renaming = false;
  bool _editingDetails = false;
  AppUser? _displayUser;
  bool _signingOut = false;
  String? _error;
  int _generation = 0;
  int _profileRefresh = 0;
  int _profileDataVersion = 0;

  bool get _sessionMatches =>
      widget.accountService.currentUser?.id == widget.user.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadProfiles());
    _familyRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_activeProfileId == FinancialProfile.familyId) {
        unawaited(_refreshProfileDetails());
      }
    });
  }

  @override
  void didUpdateWidget(covariant FinancialWorkspace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.name != widget.user.name ||
        oldWidget.user.email != widget.user.email) {
      _displayUser = null;
    }
    if (oldWidget.user.id != widget.user.id ||
        oldWidget.profileRepository != widget.profileRepository ||
        oldWidget.profileDetailsRepository != widget.profileDetailsRepository ||
        oldWidget.familyGroupRepository != widget.familyGroupRepository ||
        oldWidget.accountService != widget.accountService) {
      _generation++;
      _profiles = const [];
      _activeProfileId = null;
      _financeRepositories.clear();
      _limitRepositories.clear();
      _switching = false;
      _renaming = false;
      _editingDetails = false;
      _displayUser = null;
      unawaited(_loadProfiles());
    }
  }

  @override
  void dispose() {
    _generation++;
    _profileRefresh++;
    _familyRefresh?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshProfileDetails());
  }

  Future<void> _refreshProfileDetails() async {
    if (!mounted ||
        _loading ||
        _switching ||
        _renaming ||
        _editingDetails ||
        _signingOut ||
        !_sessionMatches ||
        _activeProfileId == null) {
      return;
    }
    final refresh = ++_profileRefresh;
    final generation = _generation;
    final version = _profileDataVersion;
    final userId = widget.user.id;
    final profileId = _activeProfileId;
    try {
      final state = await widget.profileRepository.loadProfiles();
      if (!mounted ||
          refresh != _profileRefresh ||
          generation != _generation ||
          version != _profileDataVersion ||
          !_sessionMatches ||
          widget.user.id != userId ||
          _activeProfileId != profileId ||
          state.profiles.any((profile) => profile.userId != userId)) {
        return;
      }
      final previous = _profiles.firstWhere(
        (profile) => profile.id == profileId,
      );
      final current = state.profiles.firstWhere(
        (profile) => profile.id == profileId,
        orElse: () => state.activeProfile,
      );
      if (previous.familyOwnerId != current.familyOwnerId) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..removeCurrentSnackBar();
      }
      setState(() {
        _profiles = state.profiles;
        _activeProfileId = current.id;
      });
    } catch (_) {
      // A foto usa as iniciais se indisponível; uma falha aqui não apaga finanças.
    }
  }

  Future<void> _loadProfiles() async {
    if (!mounted || _signingOut) return;
    final generation = ++_generation;
    final userId = widget.user.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (!_sessionMatches) {
        throw const FinanceException('Entre na sua conta para continuar.');
      }
      final state = await widget.profileRepository.loadProfiles();
      if (!mounted || generation != _generation) return;
      if (!_sessionMatches ||
          widget.user.id != userId ||
          state.profiles.any((profile) => profile.userId != userId)) {
        throw const FinanceException('Sua sessão mudou. Entre novamente.');
      }
      // O estado valida que o perfil selecionado existe na lista desta conta.
      final active = state.activeProfile;
      setState(() {
        _profiles = state.profiles;
        _activeProfileId = active.id;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _profiles = const [];
        _activeProfileId = null;
        _loading = false;
        _error = error is FinanceException
            ? error.message
            : 'Não foi possível carregar seus perfis. Tente novamente.';
      });
    }
  }

  Future<void> _selectProfile(String profileId) async {
    if (_loading ||
        _switching ||
        _renaming ||
        _editingDetails ||
        _signingOut ||
        !_sessionMatches ||
        profileId == _activeProfileId ||
        !_profiles.any((profile) => profile.id == profileId)) {
      return;
    }
    final generation = ++_generation;
    final userId = widget.user.id;
    final repository = widget.profileRepository;
    // Avisos com quantias do perfil anterior também saem imediatamente.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    setState(() => _switching = true);
    try {
      await repository.selectProfile(profileId);
      if (!mounted || generation != _generation) return;
      if (!_sessionMatches || widget.user.id != userId) {
        throw const FinanceException('Sua sessão mudou. Entre novamente.');
      }
      // Publica a nova seleção somente depois da confirmação do servidor.
      setState(() {
        _activeProfileId = profileId;
        _switching = false;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _switching = false);
      if (_sessionMatches && widget.user.id == userId) {
        _showError(
          error is FinanceException
              ? error.message
              : 'Não foi possível trocar o perfil. Tente novamente.',
        );
      }
    }
  }

  Future<FinancialProfile> _renameBusiness(String name) async {
    final profileId = _activeProfileId;
    final userId = widget.user.id;
    if (!mounted ||
        _renaming ||
        _editingDetails ||
        _switching ||
        !_sessionMatches ||
        profileId == null) {
      throw const FinanceException(
        'Não foi possível editar este perfil agora.',
      );
    }
    final current = _profiles.firstWhere((profile) => profile.id == profileId);
    if (current.kind != FinancialProfileKind.business) {
      throw const FinanceException('Escolha o perfil Empresa para continuar.');
    }
    _renaming = true;
    _profileDataVersion++;
    try {
      final updated = await widget.profileRepository.renameBusiness(
        profileId: profileId,
        name: name,
      );
      if (!mounted ||
          !_sessionMatches ||
          widget.user.id != userId ||
          _activeProfileId != profileId) {
        throw const FinanceException('Seu perfil mudou. Tente novamente.');
      }
      if (updated.userId != userId ||
          updated.id != profileId ||
          updated.kind != FinancialProfileKind.business ||
          updated.name != name.trim()) {
        throw const FinanceException(
          'Não foi possível confirmar o nome da empresa.',
        );
      }
      _publishProfile(updated);
      return updated;
    } finally {
      _renaming = false;
    }
  }

  void _publishProfile(FinancialProfile updated) {
    final previous = _profiles.firstWhere(
      (profile) => profile.id == updated.id,
    );
    final resolved =
        updated.avatarUrl == null && updated.avatarPath == previous.avatarPath
        ? updated.withAvatarUrl(previous.avatarUrl)
        : updated;
    setState(() {
      _profiles = List<FinancialProfile>.unmodifiable([
        for (final profile in _profiles)
          if (profile.id == resolved.id) resolved else profile,
      ]);
    });
  }

  bool _sameProfileOperation(String userId, String profileId, int generation) =>
      mounted &&
      _sessionMatches &&
      widget.user.id == userId &&
      _activeProfileId == profileId &&
      _generation == generation &&
      !_switching;

  Future<void> _savePersonalName(String name) async {
    final repository = widget.profileDetailsRepository;
    final profileId = _activeProfileId;
    final userId = widget.user.id;
    final generation = _generation;
    if (!mounted ||
        repository == null ||
        profileId != FinancialProfile.personalId ||
        _editingDetails ||
        _renaming ||
        _switching ||
        !_sessionMatches) {
      throw const FinanceException(
        'Não foi possível editar este perfil agora.',
      );
    }
    _editingDetails = true;
    _profileDataVersion++;
    try {
      final updated = await repository.updatePersonalName(name);
      if (!_sameProfileOperation(userId, profileId!, generation)) {
        throw const FinanceException('Seu perfil mudou. Tente novamente.');
      }
      if (updated.id != userId ||
          updated.name != name.trim() ||
          updated.email != widget.user.email) {
        throw const FinanceException('Não foi possível confirmar seus dados.');
      }
      setState(() => _displayUser = updated);
    } finally {
      _editingDetails = false;
    }
  }

  Future<void> _saveProfileDetails(
    Future<FinancialProfile> Function(
      ProfileDetailsRepository repository,
      FinancialProfile current,
      bool Function() isCurrent,
    )
    operation,
  ) async {
    final repository = widget.profileDetailsRepository;
    final profileId = _activeProfileId;
    final userId = widget.user.id;
    final generation = _generation;
    if (!mounted ||
        repository == null ||
        profileId == null ||
        _editingDetails ||
        _renaming ||
        _switching ||
        !_sessionMatches) {
      throw const FinanceException(
        'Não foi possível editar este perfil agora.',
      );
    }
    final current = _profiles.firstWhere((profile) => profile.id == profileId);
    bool isCurrent() => _sameProfileOperation(userId, profileId, generation);
    _editingDetails = true;
    _profileDataVersion++;
    try {
      final updated = await operation(repository, current, isCurrent);
      if (!isCurrent()) {
        throw const FinanceException('Seu perfil mudou. Tente novamente.');
      }
      if (updated.id != profileId ||
          updated.userId != userId ||
          updated.kind != current.kind) {
        throw const FinanceException('Não foi possível confirmar seus dados.');
      }
      _publishProfile(updated);
    } finally {
      _editingDetails = false;
    }
  }

  Future<void> _saveBusiness(BusinessProfileData data) => _saveProfileDetails((
    repository,
    current,
    _,
  ) async {
    if (current.kind != FinancialProfileKind.business) {
      throw const FinanceException('Escolha o perfil Empresa para continuar.');
    }
    final updated = await repository.updateBusiness(
      profileId: current.id,
      data: data,
    );
    if (updated.name != data.name ||
        updated.legalName != data.legalName ||
        updated.cnpj != data.cnpj ||
        updated.contactEmail != data.contactEmail ||
        updated.contactPhone != data.contactPhone) {
      throw const FinanceException(
        'Não foi possível confirmar os dados da empresa.',
      );
    }
    return updated;
  });

  Future<void> _choosePhoto() async {
    final picker = widget.imagePicker;
    if (picker == null) return;
    // O cancelamento da galeria mantém a foto atual.
    await _saveProfileDetails((repository, current, isCurrent) async {
      final image = await picker();
      if (!isCurrent()) {
        throw const FinanceException('Seu perfil mudou. Tente novamente.');
      }
      if (image == null) return current;
      final updated = await repository.uploadPhoto(
        profileId: current.id,
        bytes: image.bytes,
        contentType: image.contentType,
      );
      if (updated.avatarPath == null) {
        throw const FinanceException('Não foi possível confirmar a foto.');
      }
      return updated;
    });
  }

  Future<void> _removePhoto() =>
      _saveProfileDetails((repository, current, _) async {
        final updated = await repository.removePhoto(current.id);
        if (updated.avatarPath != null || updated.avatarUrl != null) {
          throw const FinanceException(
            'Não foi possível confirmar a remoção da foto.',
          );
        }
        return updated;
      });

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await widget.accountService.signOut();
    } catch (_) {
      if (mounted) _showError('Não foi possível sair. Tente novamente.');
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  bool _hasFamilyScope(String userId, String? ownerId) =>
      mounted &&
      _sessionMatches &&
      !_switching &&
      widget.user.id == userId &&
      _activeProfileId == FinancialProfile.familyId &&
      _profiles.any(
        (profile) =>
            profile.kind == FinancialProfileKind.family &&
            profile.familyOwnerId == ownerId,
      );

  Future<void> _openFamilyGroup(
    FamilyGroupRepository repository,
    String ownerId,
  ) async {
    final userId = widget.user.id;
    if (!_hasFamilyScope(userId, ownerId)) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (routeContext) => FamilyGroupScreen(
          repository: repository,
          userId: userId,
          ownerId: ownerId,
          isCurrent: () => _hasFamilyScope(userId, ownerId),
          onMembershipChanged: () async {
            if (ModalRoute.of(routeContext)?.isCurrent == true) {
              Navigator.of(routeContext).pop();
            }
          },
        ),
      ),
    );
    await _refreshProfileDetails();
  }

  @override
  Widget build(BuildContext context) {
    if (!_sessionMatches || _loading || _activeProfileId == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.savings_outlined,
                    color: AppColors.of(context).neon,
                    size: 42,
                  ),
                  const SizedBox(height: 20),
                  if (_loading || !_sessionMatches) ...[
                    CircularProgressIndicator(
                      color: AppColors.of(context).neon,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Carregando seus perfis...',
                      style: GoogleFonts.poppins(),
                    ),
                  ] else ...[
                    Text(
                      _error ?? 'Não foi possível carregar seus perfis.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      key: const ValueKey('retry-financial-profiles'),
                      onPressed: _loadProfiles,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Tentar novamente'),
                    ),
                    TextButton(
                      onPressed: _signingOut ? null : _signOut,
                      child: const Text('Sair da conta'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }
    final profileId = _activeProfileId!;
    final profile = _profiles.firstWhere((profile) => profile.id == profileId);
    final family = widget.familyGroupRepository;
    final familyOwner = profile.familyOwnerId;
    final showFamily =
        family != null &&
        _profiles.any((profile) => profile.kind == FinancialProfileKind.family);

    if (family != null &&
        profile.kind == FinancialProfileKind.family &&
        familyOwner == null) {
      final userId = widget.user.id;
      return FamilyGroupScreen(
        repository: family,
        userId: userId,
        isCurrent: () => _hasFamilyScope(userId, null),
        onMembershipChanged: _refreshProfileDetails,
        header: AppHeader(
          selectedProfileId: profileId,
          showFamily: true,
          isSwitchingProfile: _switching,
          onProfileSelected: (id) => unawaited(_selectProfile(id)),
        ),
      );
    }

    final scope = (profileId, profile.dataOwnerId);
    return HomeScreen(
      key: ValueKey(widget.user.id),
      user: _displayUser ?? widget.user,
      accountService: widget.accountService,
      repository: _financeRepositories.putIfAbsent(
        scope,
        () => widget.financeRepositoryForProfile(profile),
      ),
      monthlyLimitRepository: _limitRepositories.putIfAbsent(
        scope,
        () => widget.monthlyLimitRepositoryForProfile(profile),
      ),
      financialProfile: profile,
      showFamily: showFamily,
      onOpenFamilyGroup: family == null || familyOwner == null
          ? null
          : () => unawaited(_openFamilyGroup(family, familyOwner)),
      onProfileSelected: (id) => unawaited(_selectProfile(id)),
      isSwitchingProfile: _switching,
      onRenameBusiness: _renameBusiness,
      onSavePersonalName: widget.profileDetailsRepository == null
          ? null
          : (name) {
              if (!mounted || _activeProfileId != profileId) {
                throw const FinanceException(
                  'Seu perfil mudou. Tente novamente.',
                );
              }
              return _savePersonalName(name);
            },
      onSaveBusinessDetails: widget.profileDetailsRepository == null
          ? null
          : (data) {
              if (!mounted || _activeProfileId != profileId) {
                throw const FinanceException(
                  'Seu perfil mudou. Tente novamente.',
                );
              }
              return _saveBusiness(data);
            },
      onChooseProfilePhoto:
          profile.kind == FinancialProfileKind.family ||
              widget.profileDetailsRepository == null ||
              widget.imagePicker == null
          ? null
          : _choosePhoto,
      onRemoveProfilePhoto:
          profile.kind == FinancialProfileKind.family ||
              widget.profileDetailsRepository == null
          ? null
          : _removePhoto,
      onRefreshProfile: _refreshProfileDetails,
    );
  }
}
