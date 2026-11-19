import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../models/business_profile_data.dart';
import '../models/financial_profile.dart';
import 'profile_data_form.dart';

// Preserva o editor modal para os pontos que ainda chamam esta função.
Future<bool?> showEditProfileSheet(
  BuildContext context, {
  required AppUser user,
  FinancialProfile? financialProfile,
  Future<void> Function(String)? onSavePersonalName,
  Future<void> Function(BusinessProfileData)? onSaveBusiness,
}) => showModalBottomSheet<bool>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  builder: (context) => _Editor(
    user: user,
    profile: financialProfile,
    onName: onSavePersonalName,
    onBusiness: onSaveBusiness,
  ),
);

class _Editor extends StatefulWidget {
  final AppUser user;
  final FinancialProfile? profile;
  final Future<void> Function(String)? onName;
  final Future<void> Function(BusinessProfileData)? onBusiness;
  const _Editor({
    required this.user,
    this.profile,
    this.onName,
    this.onBusiness,
  });
  @override
  State<_Editor> createState() => _EditorState();
}

class _EditorState extends State<_Editor> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Editar perfil',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 24),
          ProfileDataForm(
            user: widget.user,
            profile: widget.profile,
            onSavePersonalName: widget.onName,
            onSaveBusiness: widget.onBusiness,
            onBusyChanged: (value) {
              if (mounted) setState(() => _busy = value);
            },
            onSaved: () {
              setState(() => _busy = false);
              Navigator.of(context).pop(true);
            },
          ),
          TextButton(
            key: const ValueKey('cancel-profile-edit'),
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    ),
  );
}
