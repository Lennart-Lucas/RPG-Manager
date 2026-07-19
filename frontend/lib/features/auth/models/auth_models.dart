class TokenPair {
  const TokenPair({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
  });

  final String accessToken;
  final String refreshToken;
  final int expiresIn;

  factory TokenPair.fromJson(Map<String, dynamic> json) {
    return TokenPair(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      expiresIn: json['expires_in'] as int,
    );
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.isActive,
    required this.isDm,
    this.aiIntegration = false,
  });

  final int id;
  final String email;
  final bool isActive;
  final bool isDm;
  final bool aiIntegration;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      email: json['email'] as String,
      isActive: json['is_active'] as bool,
      isDm: json['is_dm'] as bool,
      aiIntegration: json['ai_integration'] as bool? ?? false,
    );
  }

  UserProfile copyWith({
    int? id,
    String? email,
    bool? isActive,
    bool? isDm,
    bool? aiIntegration,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      isDm: isDm ?? this.isDm,
      aiIntegration: aiIntegration ?? this.aiIntegration,
    );
  }
}
