import 'package:image_picker/image_picker.dart';

import '../models/picked_profile_image.dart';
import '../models/services/finance_repository.dart';

Future<PickedProfileImage?> pickProfileImage() async {
  final XFile? image;
  try {
    image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  } catch (_) {
    throw const FinanceException(
      'Não foi possível abrir a galeria. Tente novamente.',
    );
  }
  if (image == null) return null;
  if (await image.length() > 5 * 1024 * 1024) {
    throw const FinanceException('Escolha uma foto de até 5 MB.');
  }
  final bytes = await image.readAsBytes();
  // O formato vem do conteúdo, pois o nome e o MIME do arquivo podem variar.
  final contentType =
      bytes.length >= 3 &&
          bytes[0] == 0xff &&
          bytes[1] == 0xd8 &&
          bytes[2] == 0xff
      ? 'image/jpeg'
      : bytes.length >= 8 &&
            bytes[0] == 0x89 &&
            bytes[1] == 0x50 &&
            bytes[2] == 0x4e &&
            bytes[3] == 0x47 &&
            bytes[4] == 0x0d &&
            bytes[5] == 0x0a &&
            bytes[6] == 0x1a &&
            bytes[7] == 0x0a
      ? 'image/png'
      : bytes.length >= 12 &&
            bytes[0] == 0x52 &&
            bytes[1] == 0x49 &&
            bytes[2] == 0x46 &&
            bytes[3] == 0x46 &&
            bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50
      ? 'image/webp'
      : null;
  if (contentType == null) {
    throw const FinanceException('Escolha uma foto JPG, PNG ou WebP.');
  }
  return PickedProfileImage(bytes: bytes, contentType: contentType);
}
