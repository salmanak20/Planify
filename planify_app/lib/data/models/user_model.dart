/// User data model.
class UserModel {
  final int id;
  final String email;
  final String fullName;
  final String avatarColor;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.avatarColor,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as int,
        email: json['email'] as String,
        fullName: json['full_name'] as String,
        avatarColor: json['avatar_color'] as String? ?? '#435f92',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'avatar_color': avatarColor,
      };

  /// Returns the user's initials for avatars.
  String get initials {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return fullName.isNotEmpty ? fullName[0].toUpperCase() : '?';
  }
}
