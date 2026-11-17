// Os dados públicos da pessoa autenticada, sem guardar a senha.
class AppUser {
  final String id;
  final String email;
  final String name;

  const AppUser({required this.id, required this.email, required this.name});

  String get firstName {
    final trimmed = name.trim();
    return trimmed.isEmpty ? 'bem-vindo' : trimmed.split(RegExp(r'\s+')).first;
  }
}
