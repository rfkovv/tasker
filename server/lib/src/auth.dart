/// Constant-time Bearer-token check.
///
/// Length is compared first (leaks only key length, which is public for a
/// static API key). Byte compare uses XOR accumulation so early mismatches
/// do not short-circuit the scan.
bool isValidApiKey({required String provided, required String expected}) {
  if (expected.isEmpty) return false;
  if (provided.length != expected.length) return false;
  var diff = 0;
  for (var i = 0; i < expected.length; i++) {
    diff |= provided.codeUnitAt(i) ^ expected.codeUnitAt(i);
  }
  return diff == 0;
}

/// Extracts the token from an `Authorization: Bearer <token>` header.
String? bearerToken(String? authorizationHeader) {
  if (authorizationHeader == null) return null;
  const prefix = 'Bearer ';
  if (!authorizationHeader.startsWith(prefix)) return null;
  final token = authorizationHeader.substring(prefix.length).trim();
  if (token.isEmpty) return null;
  return token;
}
