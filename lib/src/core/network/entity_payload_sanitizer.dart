const Set<String> blockedEntityOwnershipKeys = <String>{
  'ownerId',
  'tenantUrl',
  'tenantURL',
  'tenentURL',
  'tenantDatabase',
};

Object? sanitizeEntityPayload(Object? value) {
  if (value is List<dynamic>) {
    return value.map<Object?>((item) => sanitizeEntityPayload(item)).toList();
  }

  if (value is Map<Object?, Object?>) {
    final sanitized = <String, dynamic>{};
    for (final entry in value.entries) {
      final key = entry.key.toString();
      if (blockedEntityOwnershipKeys.contains(key)) {
        continue;
      }
      sanitized[key] = sanitizeEntityPayload(entry.value);
    }
    return sanitized;
  }

  return value;
}
