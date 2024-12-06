import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PickupService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createPickupRequest(String email, LatLng location) async {
    await _firestore.collection('pickup_requests').add({
      'user_email': email,
      'location': GeoPoint(location.latitude, location.longitude),
      'status': 'pending',
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  void listenForPickupRequests(String email, Function(String?) callback) {
    _firestore
        .collection('pickup_requests')
        .where('user_email', isEqualTo: email)
        .where('status', whereIn: ['pending', 'approved'])
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        callback(snapshot.docs.first.id);
      } else {
        callback(null);
      }
    });
  }

  Stream<String> getPickupRequestStatus(String requestId) {
    return _firestore
        .collection('pickup_requests')
        .doc(requestId)
        .snapshots()
        .map((snapshot) => snapshot.data()!['status'] as String);
  }
}

