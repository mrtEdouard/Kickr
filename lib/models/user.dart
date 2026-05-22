class User {
  final int id;
  final String pseudo;
  final String email;

  const User({required this.id, required this.pseudo, required this.email});

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: (json['id'] as num).toInt(),
        pseudo: json['pseudo'] as String,
        email: json['email'] as String,
      );
}
