import 'dart:typed_data';

import '../app_user.dart';
import '../business_profile_data.dart';
import '../financial_profile.dart';

abstract interface class ProfileDetailsRepository {
  Future<AppUser> updatePersonalName(String name);

  Future<FinancialProfile> updateBusiness({
    required String profileId,
    required BusinessProfileData data,
  });

  Future<FinancialProfile> uploadPhoto({
    required String profileId,
    required Uint8List bytes,
    required String contentType,
  });

  Future<FinancialProfile> removePhoto(String profileId);
}
