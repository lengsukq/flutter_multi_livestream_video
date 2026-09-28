enum ChatRole {
  participant,
  host,
  viewer;

  String get wireName => name;

  static ChatRole? tryParse(Object? value) {
    final normalized = value?.toString().trim().toLowerCase();
    for (final role in values) {
      if (role.wireName == normalized) return role;
    }
    return null;
  }
}
