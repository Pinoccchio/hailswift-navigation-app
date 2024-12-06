class User {
  final String firstName;
  final String lastName;
  final String role; // Role: client or driver
  final String password;
  final String email;

  User({
    required this.firstName,
    required this.lastName,
    required this.role,
    required this.password,
    required this.email,
  });

  // Convert User object to Map
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'role': role,
      'password': password,
      'email': email,
    };
  }

  // Create a User object from Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      firstName: map['firstName'],
      lastName: map['lastName'],
      role: map['role'],
      password: map['password'],
      email: map['email'],
    );
  }
}
