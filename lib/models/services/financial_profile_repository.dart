import '../financial_profile.dart';

abstract interface class FinancialProfileRepository {
  Future<FinancialProfileState> loadProfiles();

  Future<void> selectProfile(String profileId);

  Future<FinancialProfile> renameBusiness({
    required String profileId,
    required String name,
  });
}
