enum EmailConfirmationStatus { none, confirmed, invalid }

EmailConfirmationStatus emailConfirmationStatusFromUri(Uri uri) {
  final fragmentParameters = _fragmentParameters(uri.fragment);
  final parameters = <String, String>{
    ...uri.queryParameters,
    ...fragmentParameters,
  };

  if (parameters.containsKey('error_code') ||
      parameters['error'] == 'access_denied') {
    return EmailConfirmationStatus.invalid;
  }

  if (fragmentParameters['type'] == 'signup' ||
      fragmentParameters.containsKey('access_token')) {
    return EmailConfirmationStatus.confirmed;
  }

  return EmailConfirmationStatus.none;
}

Map<String, String> _fragmentParameters(String fragment) {
  final value = fragment.startsWith('?') ? fragment.substring(1) : fragment;
  if (value.isEmpty) return const {};

  try {
    return Uri.splitQueryString(value);
  } on FormatException {
    return const {};
  }
}
