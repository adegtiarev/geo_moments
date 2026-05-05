class AppUser {
  const AppUser({
    required this.id,
    this.email,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? email;
  final String? displayName;
  final String? avatarUrl;

  String get bestDisplayName {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final emailValue = email?.trim();
    if (emailValue != null && emailValue.isNotEmpty) {
      return emailValue;
    }

    return 'Geo Moments user';
  }
}
