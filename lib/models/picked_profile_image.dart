import 'dart:typed_data';

// Conteúdo selecionado no dispositivo, antes de gravar a foto na nuvem.
class PickedProfileImage {
  final Uint8List bytes;
  final String contentType;

  PickedProfileImage({required Uint8List bytes, required this.contentType})
    : bytes = Uint8List.fromList(bytes);
}
