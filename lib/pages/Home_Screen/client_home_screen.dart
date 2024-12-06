import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lottie/lottie.dart';
import 'package:google_fonts/google_fonts.dart';
import '../Map_Screen/client_map_screen.dart';
import '../profile.dart';

class ClientHomeScreen extends StatefulWidget {
  final String email;

  const ClientHomeScreen({Key? key, required this.email}) : super(key: key);

  @override
  _ClientHomeScreenState createState() => _ClientHomeScreenState();
}

class _ClientHomeScreenState extends State<ClientHomeScreen> {
  String _profileImageUrl = '';
  String _fullName = 'Guest';

  @override
  void initState() {
    super.initState();
    _listenForUserData();
  }

  void _listenForUserData() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.email)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        var user = snapshot.data()!;
        if (mounted) {
          setState(() {
            _profileImageUrl = user['profilePictureUrl'] ?? '';
            _fullName = user['fullName'] ?? 'Guest';
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.6),
                Colors.transparent,
              ],
            ),
          ),
        ),
        title: Text(
          'Welcome, ${widget.email.split('@').first}',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 20,
            color: Colors.white,
          ),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Profile(
                    email: widget.email,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _profileImageUrl.isNotEmpty
                  ? ClipOval(
                child: Image.network(
                  _profileImageUrl,
                  fit: BoxFit.cover,
                ),
              )
                  : Lottie.asset(
                'assets/animated_icon/wired-flat-268-avatar-man.json',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          ClientCityMap(email: widget.email),
        ],
      ),
    );
  }
}


