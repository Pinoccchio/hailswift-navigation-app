import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_app/pages/SignIn_Screen/sign_in_filled.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:lottie/lottie.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'Database_Helper/FirestoreDatabaseHelper.dart';
import 'Home_Screen/client_home_screen.dart'; // For storing preferences
import 'package:http/http.dart' as http;

import 'Home_Screen/driver_home_screen.dart';

class Splash extends StatefulWidget {
  @override
  _SplashState createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    _checkInternetConnectionAndProceed();
  }

  // Check for internet connection and proceed based on its availability
  Future<void> _checkInternetConnectionAndProceed() async {
    var connectivityResult = await Connectivity().checkConnectivity();

    if (connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi)) {
      print('Connected to the internet');
    } else {
      print('No internet connection');
      _showNoInternetDialog();
      return; // Exit the function if no connection
    }

    bool isInternetAvailable = await _checkInternetAvailability();
    if (isInternetAvailable) {
      // Upload default users to Firestore if they don't exist
      await _uploadDefaultUsers();

      // Check if the user is logged in
      _checkUserSession();
    } else {
      _showNoInternetDialog();
    }
  }

  // Check if the internet is actually working
  Future<bool> _checkInternetAvailability() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(Duration(seconds: 5));

      return response.statusCode == 200;
    } on TimeoutException catch (_) {
      return false;
    } catch (e) {
      print('Error checking internet: $e');
      return false;
    }
  }

  // Upload default client and driver users to Firestore if they don't exist
  Future<void> _uploadDefaultUsers() async {
    try {
      await FirestoreDatabaseHelper.uploadClientAndDriver();
      print('Default users uploaded successfully.');
    } catch (e) {
      print('Error uploading default users: $e');
    }
  }

  // Check if the user is logged in and handle navigation
  Future<void> _checkUserSession() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('email');

    if (email != null) {
      _navigateToHomeScreen(email);
    } else {
      _navigateToSignInScreen();
    }
  }

  // Navigate to the sign-in screen
  void _navigateToSignInScreen() {
    Future.delayed(Duration(seconds: 3), () {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SignInFilled()),
      );
    });
  }

  void _navigateToHomeScreen(String email) {
    // Check if the email contains 'user' or 'driver' to navigate appropriately
    if (email.contains('user')) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ClientHomeScreen(email: email),
        ),
      );
    } else if (email.contains('driver')) {
      // Navigate to DriverHomeScreen if applicable (you need to create this class)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DriverHomeScreen(email: email), // Ensure you have this class
        ),
      );
    } else {
      // Handle case where email does not match either type
      _showError('Invalid user type');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // Show no internet connection dialog
  void _showNoInternetDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[800],
        title: Text(
          'No Internet Connection',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Please connect to the internet and try again.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              exit(0);
            },
            child: Text('OK'),
            style: TextButton.styleFrom(foregroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Color(0xFF000000), // Black background
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Centered app title and description
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated app title
                  AnimatedDefaultTextStyle(
                    duration: Duration(seconds: 1),
                    curve: Curves.easeInOut,
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF73CBE6), // Highlighted title color
                    ),
                    child: Text('HailSwift'),
                  ),
                  SizedBox(height: 20),
                  // App description
                  Text(
                    'Your ultimate ride-sharing app,\nbridging people safely and swiftly.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white, // White description text
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Lottie animation at the bottom
            Positioned(
              bottom: 30.0,
              child: SizedBox(
                width: 180,
                height: 180,
                child: Lottie.asset(
                  'assets/animated_icon/loading-animation.json',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


}
