import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_app/pages/Home_Screen/driver_home_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Home_Screen/client_home_screen.dart';
import '../Notification_Handler/notification_handler.dart';

class SignInFilled extends StatefulWidget {
  @override
  _SignInFilledState createState() => _SignInFilledState();
}

class _SignInFilledState extends State<SignInFilled> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  final NotificationHandler _notificationHandler = NotificationHandler();

  Future<bool> _isConnectedToInternet() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _saveLoginState(String email) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('email', email);
  }

  @override
  void initState() {
    super.initState();
    _notificationHandler.initializeNotifications();
    _notificationHandler.requestNotificationPermissions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: const BoxDecoration(
            color: Colors.black,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Logo and Welcome Section
              Center(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome!',
                      style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w500,
                        fontSize: 28,
                        height: 1.1,
                        color: const Color(0xFF73CBE6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              // Instruction text
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20.4),
                child: Text(
                  'Please enter your email and password to Sign In',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w400,
                    fontSize: 16,
                    color: const Color(0xFFFFFFFF),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Email field
              _buildInputField(
                label: 'Email Address',
                hintText: 'juandela.cruz@example.com',
                controller: _emailController,
                isPassword: false,
              ),
              // Password field
              _buildInputField(
                label: 'Password',
                hintText: '**********',
                controller: _passwordController,
                isPassword: true,
              ),
              const SizedBox(height: 50),
              // Sign In Button
              ElevatedButton(
                onPressed: () async {
                  String email = _emailController.text;
                  String password = _passwordController.text;

                  if (email.isEmpty || password.isEmpty) {
                    _showToast('Please enter your email and password', Colors.red);
                  } else {
                    if (await _isConnectedToInternet()) {
                      try {
                        // Sign in with Firebase Authentication
                        UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                          email: email,
                          password: password,
                        );

                        // Fetch user data from Firestore
                        var userDoc = await FirebaseFirestore.instance
                            .collection('users')
                            .doc(email) // Use email as document ID
                            .get();

                        if (userDoc.exists) {
                          // Navigate or handle logic based on the email
                          if (email.contains('user')) {
                            _showToast("Welcome, $email", Colors.green);

                            // Save login state in SharedPreferences
                            await _saveLoginState(email);

                            // Show welcome notification
                            await _notificationHandler.showWelcomeNotification(email);

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ClientHomeScreen(
                                  email: email,
                                ),
                              ),
                            );
                          } else if (email.contains('driver')) {

                            // Save login state in SharedPreferences
                            await _saveLoginState(email);

                            // Show welcome notification
                            await _notificationHandler.showWelcomeNotification(email);

                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DriverHomeScreen(
                                  email: email,
                                ),
                              ),
                            );
                          } else {
                            _showToast("Unknown role. Please contact support.", Colors.red);
                          }
                        } else {
                          _showToast('User not found', Colors.red);
                        }
                      } on FirebaseAuthException catch (e) {
                        _showToast(e.message ?? 'Error occurred', Colors.red);
                      }
                    } else {
                      _showToast('No internet connection', Colors.red);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 100),
                  backgroundColor: const Color(0xFF73CBE6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(27),
                  ),
                ),
                child: Text(
                  'Sign In',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    bool isPassword = false,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 0, 0.7, 35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            obscureText: isPassword && !_isPasswordVisible,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w400,
                fontSize: 16,
                color: Colors.white.withOpacity(0.5),
              ),
              suffixIcon: isPassword
                  ? IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.white,
                ),
                onPressed: () {
                  setState(() {
                    _isPasswordVisible = !_isPasswordVisible;
                  });
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.white.withOpacity(0.1),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
            ),
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w400,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _showToast(String message, Color backgroundColor) {
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: backgroundColor,
      textColor: Colors.white,
      fontSize: 16.0,
    );
  }
}
