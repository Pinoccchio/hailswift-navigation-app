import 'package:flutter/material.dart';
import 'package:flutter_app/pages/SignIn_Screen/sign_in_filled.dart';
import 'package:flutter_app/pages/splash.dart';
import 'package:flutter_app/pages/profile.dart';
import 'package:flutter_app/pages/sign_out.dart';

class AppRoutes {
  static const String splashScreen = '/splashScreen';
  static const String signInFilled = '/signInFilled';
  static const String group36133 = '/group36133';
  static const String group36136 = '/group36136';
  static const String group36137 = '/group36137';
  static const String group36139 = '/group36139';
  static const String group36140 = '/group36140';
  static const String group36141 = '/group36141';
  static const String home = '/home';
  static const String profile = '/profile';
  static const String signOut = '/signOut';
  static const String studyPlanner = '/studyPlanner';
  static const String studyPlanner1 = '/studyPlanner1';
  static const String textToSpeech = '/textToSpeech';
  static const String transcriptions = '/transcriptions';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      splashScreen: (context) => Splash(),
      signInFilled: (context) => SignInFilled(),

      /*
      home: (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map?;
        final user = args != null ? User(
          firstName: args['firstName'] ?? 'Guest',
          lastName: args['lastName'] ?? '',
          studentNumber: args['studentNumber'] ?? '',
          password: args['password'] ?? '',
          profilePictureUrl: args['profilePictureUrl'] ?? '', // Add this line
        ) : User(
          firstName: 'Guest',
          lastName: '',
          studentNumber: '',
          password: '',
          profilePictureUrl: '', // Add this line
        );

        return Home(
          studentNumber: user.studentNumber,
          firstName: user.firstName,
          lastName: user.lastName,
        );
      },

       */


      profile: (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

        final email = args?['email'] ?? '';

        return Profile(
          email: email,
        );
      },

      signOut: (context) => SignOut(),
    };
  }
}
