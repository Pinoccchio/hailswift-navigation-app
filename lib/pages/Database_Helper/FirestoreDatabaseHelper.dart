import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreDatabaseHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final CollectionReference _usersCollection = _firestore.collection('users');

  // Upload default client and driver users to Firestore and Firebase Auth
  static Future<void> uploadClientAndDriver() async {
    List<Map<String, dynamic>> defaultUsers = [
      {
        'email': 'hailswift.user@gmail.com',
        'password': 'useruser',
        'role': 'client',
      },
      {
        'email': 'hailswift.driver@gmail.com',
        'password': 'driverdriver',
        'role': 'driver',
      },
    ];

    for (var userData in defaultUsers) {
      try {
        // Check if the user already exists in Firestore
        var userDoc = await _usersCollection.doc(userData['email']).get();
        if (!userDoc.exists) {
          // Create the user in Firebase Auth
          UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
            email: userData['email'],
            password: userData['password'],
          );

          // Add user details to Firestore
          await _usersCollection.doc(userData['email']).set({
            'email': userData['email'],
            'role': userData['role'],
          });

          print('Uploaded user: ${userData['email']}');
        } else {
          print('User already exists in Firestore: ${userData['email']}');
        }
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          print('Firebase Auth: Email already in use: ${userData['email']}');
        } else {
          print('Firebase Auth Exception for ${userData['email']}: $e');
        }
      } catch (e) {
        print('Failed to upload user ${userData['email']}: $e');
      }
    }
  }
}
