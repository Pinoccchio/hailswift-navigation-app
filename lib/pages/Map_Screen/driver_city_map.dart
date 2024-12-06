import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class DriverCityMap extends StatefulWidget {
  final String email;

  const DriverCityMap({Key? key, required this.email}) : super(key: key);

  @override
  _DriverCityMapState createState() => _DriverCityMapState();
}

class _DriverCityMapState extends State<DriverCityMap> {
  late GoogleMapController mapController;
  MapType _currentMapType = MapType.normal;
  LatLng? _driverLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  List<LatLng> polylineCoordinates = [];
  PolylinePoints polylinePoints = PolylinePoints();
  List<DocumentSnapshot> _pendingRequests = [];
  int _currentRequestIndex = 0;
  String _currentTripStatus = 'pending';
  String? _currentRequestId;

  final String apiKey = 'AIzaSyD4UAtE_r8JjBbd0o5qfv3ZSPX_8xkNJ7c'; // Replace with your actual API key
  final LatLng _center = const LatLng(14.5373, 121.0010); // Pasay City center

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenForPendingRequests();
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied', Colors.red);
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied', Colors.red);
      return;
    }

    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      LatLng latLng = LatLng(position.latitude, position.longitude);

      setState(() {
        _driverLocation = latLng;
      });

      mapController.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _updateDriverLocation(latLng);
      _showSnackBar('Current location found', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to get current location: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _listenForPendingRequests() {
    FirebaseFirestore.instance
        .collection('ride_requests')
        .snapshots()
        .listen((snapshot) {
      setState(() {
        _pendingRequests = snapshot.docs;
        _updateMarkers();
      });
    });
  }

  void _updateMarkers() {
    _markers.clear();
    for (var doc in _pendingRequests) {
      final data = doc.data() as Map<String, dynamic>;
      final pickupLocation = data['pickup_location'] as GeoPoint?;
      final clientEmail = data['email'] as String?;
      final status = data['status'] as String?;

      if (pickupLocation != null && clientEmail != null && status != null) {
        BitmapDescriptor markerIcon;
        switch (status) {
          case 'pending':
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueYellow);
            break;
          case 'onGoing':
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
            break;
          case 'completed':
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
            break;
          case 'unsuccessful':
            markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
            break;
          default:
            markerIcon = BitmapDescriptor.defaultMarker;
        }

        _markers.add(Marker(
          markerId: MarkerId(doc.id),
          position: LatLng(pickupLocation.latitude, pickupLocation.longitude),
          infoWindow: InfoWindow(title: 'Pickup: $clientEmail'),
          icon: markerIcon,
          onTap: () => _showPickupConfirmation(doc.id, clientEmail, LatLng(pickupLocation.latitude, pickupLocation.longitude)),
        ));
      }
    }
  }

  void _showPickupConfirmation(String requestId, String clientEmail, LatLng pickupLocation) {
    if (_currentTripStatus == 'pending') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Confirm Pickup',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Do you want to pick up $clientEmail?'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey,
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white, backgroundColor: Colors.blue,
              ),
              onPressed: () {
                Navigator.pop(context);
                _acceptRideRequest(requestId, clientEmail, pickupLocation);
              },
              child: Text('Accept'),
            ),
          ],
        ),
      );
    }
  }

  void _acceptRideRequest(String requestId, String clientEmail, LatLng pickupLocation) async {
    DocumentReference requestRef = FirebaseFirestore.instance.collection('ride_requests').doc(requestId);
    DocumentSnapshot requestDoc = await requestRef.get();

    if (requestDoc.exists) {
      // Use a transaction to update the request status
      FirebaseFirestore.instance.runTransaction((transaction) async {
        // Always allow accepting the ride request
        transaction.update(requestRef, {
          'status': 'onGoing',
          'driver_email': widget.email,
        });

        // Update the UI state
        setState(() {
          _currentTripStatus = 'onGoing';
          _currentRequestId = requestId;
        });

        _showSnackBar('Ride request accepted', Colors.green);
        _getDirectionsToPickup(pickupLocation);
      }).catchError((error) {
        _showSnackBar('Failed to accept ride request: $error', Colors.red);
      });
    } else {
      _showSnackBar('Ride request not found', Colors.red);
    }
  }

  Future<void> _getDirectionsToPickup(LatLng destination) async {
    if (_driverLocation == null) return;

    PolylineRequest request = PolylineRequest(
      origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
      destination: PointLatLng(destination.latitude, destination.longitude),
      mode: TravelMode.driving,
    );

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: apiKey,
      request: request,
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates = result.points.map((point) => LatLng(point.latitude, point.longitude)).toList();

      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: PolylineId('pickup_route'),
          color: Colors.blue,
          points: polylineCoordinates,
          width: 5,
        ));
      });

      LatLngBounds bounds = LatLngBounds(
        southwest: LatLng(
          _driverLocation!.latitude < destination.latitude ? _driverLocation!.latitude : destination.latitude,
          _driverLocation!.longitude < destination.longitude ? _driverLocation!.longitude : destination.longitude,
        ),
        northeast: LatLng(
          _driverLocation!.latitude > destination.latitude ? _driverLocation!.latitude : destination.latitude,
          _driverLocation!.longitude > destination.longitude ? _driverLocation!.longitude : destination.longitude,
        ),
      );

      mapController.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  void _updateDriverLocation(LatLng location) {
    FirebaseFirestore.instance.collection('drivers').doc(widget.email).set({
      'location': GeoPoint(location.latitude, location.longitude),
      'email': widget.email,
    }, SetOptions(merge: true)).then((_) {
      if (_currentTripStatus == 'onGoing' && _currentRequestId != null) {
        _checkProximityToPickup(_currentRequestId!);
      }
    }).catchError((error) {
      _showSnackBar('Failed to update driver location: $error', Colors.red);
    });
  }

  void _checkProximityToPickup(String requestId) async {
    DocumentSnapshot requestDoc = await FirebaseFirestore.instance.collection('ride_requests').doc(requestId).get();

    if (requestDoc.exists && _driverLocation != null) {
      final data = requestDoc.data() as Map<String, dynamic>;
      final pickupLocation = data['pickup_location'] as GeoPoint?;

      if (pickupLocation != null) {
        double distanceInMeters = await Geolocator.distanceBetween(
          _driverLocation!.latitude,
          _driverLocation!.longitude,
          pickupLocation.latitude,
          pickupLocation.longitude,
        );

        if (distanceInMeters <= 10) {
          _showTripCompletionDialog(requestId);
        }
      }
    }
  }

  void _showTripCompletionDialog(String requestId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Trip Completion',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Do you want to mark this trip as completed?'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text('No'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: Colors.green,
            ),
            onPressed: () {
              Navigator.pop(context);
              _completeTrip(requestId);
            },
            child: Text('Yes'),
          ),
        ],
      ),
    );
  }

  void _completeTrip(String requestId) {
    FirebaseFirestore.instance.collection('ride_requests').doc(requestId).update({
      'status': 'completed',
    }).then((_) {
      setState(() {
        _currentTripStatus = 'completed';
        _currentRequestId = null;
      });
      _showSnackBar('Trip marked as completed', Colors.green);
      _resetTripState();
    }).catchError((error) {
      _showSnackBar('Failed to complete trip: $error', Colors.red);
    });
  }

  void _markTripAsUnsuccessful(String reason) {
    if (_currentRequestId != null) {
      FirebaseFirestore.instance.collection('ride_requests').doc(_currentRequestId).update({
        'status': 'unsuccessful',
        'unsuccessful_reason': reason,
      }).then((_) {
        setState(() {
          _currentTripStatus = 'unsuccessful';
          _currentRequestId = null;
        });
        _showSnackBar('Trip marked as unsuccessful: $reason', Colors.red);
        _resetTripState();
      }).catchError((error) {
        _showSnackBar('Failed to mark trip as unsuccessful: $error', Colors.red);
      });
    }
  }

  void _resetTripState() {
    setState(() {
      _currentTripStatus = 'pending';
      _currentRequestId = null;
      _polylines.clear();
      polylineCoordinates.clear();
    });
    if (_driverLocation != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_driverLocation!, 15));
    }
  }

  void _showUnsuccessfulTripDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Mark Trip as Unsuccessful',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: ListBody(
            children: <Widget>[
              Text('Are you sure you want to mark this trip as unsuccessful?'),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white, backgroundColor: Colors.red,
            ),
            onPressed: () {
              Navigator.pop(context);
              _markTripAsUnsuccessful('Driver marked as unsuccessful');
            },
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _goToNextPendingRequest() {
    if (_pendingRequests.isNotEmpty) {
      var nextRequest = _pendingRequests[_currentRequestIndex];
      final data = nextRequest.data() as Map<String, dynamic>;
      final pickupLocation = data['pickup_location'] as GeoPoint?;

      if (pickupLocation != null) {
        LatLng nextPickupLocation = LatLng(pickupLocation.latitude, pickupLocation.longitude);
        mapController.animateCamera(CameraUpdate.newLatLngZoom(nextPickupLocation, 15));

        setState(() {
          _currentRequestIndex = (_currentRequestIndex + 1) % _pendingRequests.length;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: CameraPosition(
            target: _center,
            zoom: 14.0,
          ),
          mapType: _currentMapType,
          markers: _markers,
          polylines: _polylines,
          zoomControlsEnabled: false,
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: DropdownButton<MapType>(
                      value: _currentMapType,
                      onChanged: (value) => setState(() => _currentMapType = value!),
                      items: const [
                        DropdownMenuItem(value: MapType.normal, child: Text('Normal')),
                        DropdownMenuItem(value: MapType.satellite, child: Text('Satellite')),
                        DropdownMenuItem(value: MapType.terrain, child: Text('Terrain')),
                        DropdownMenuItem(value: MapType.hybrid, child: Text('Hybrid')),
                      ],
                      underline: SizedBox(),
                    ),
                  ),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      FloatingActionButton(
                        heroTag: 'locationButton',
                        onPressed: _getCurrentLocation,
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.my_location, color: Colors.white),
                      ),
                      SizedBox(height: 16),
                      FloatingActionButton(
                        heroTag: 'directionsButton',
                        onPressed: _goToNextPendingRequest,
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.directions, color: Colors.white),
                      ),
                      if (_currentTripStatus == 'onGoing')
                        Padding(
                          padding: const EdgeInsets.only(top: 16.0),
                          child: FloatingActionButton(
                            heroTag: 'unsuccessfulButton',
                            onPressed: _showUnsuccessfulTripDialog,
                            backgroundColor: Colors.red,
                            child: const Icon(Icons.cancel, color: Colors.white),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

