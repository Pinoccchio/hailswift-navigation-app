import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'search_places.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

class ClientCityMap extends StatefulWidget {
  final String email;

  const ClientCityMap({Key? key, required this.email}) : super(key: key);

  @override
  _ClientCityMapState createState() => _ClientCityMapState();
}

class _ClientCityMapState extends State<ClientCityMap> {
  late GoogleMapController mapController;
  MapType _currentMapType = MapType.normal;
  LatLng? _userLocation;
  LatLng? _pickupLocation;
  LatLng? _driverLocation;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  String _requestStatus = 'No active request';
  PolylinePoints polylinePoints = PolylinePoints();
  List<LatLng> polylineCoordinates = [];

  final String apiKey = 'AIzaSyD4UAtE_r8JjBbd0o5qfv3ZSPX_8xkNJ7c'; // Replace with your actual API key
  final LatLng _center = const LatLng(14.5373, 121.0010); // Pasay City center

  late StreamSubscription<DocumentSnapshot> requestStatusSubscription;
  StreamSubscription<DocumentSnapshot>? driverLocationSubscription; // Changed to nullable

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _listenForRequestStatus();
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
        _userLocation = latLng;
      });

      mapController.animateCamera(CameraUpdate.newLatLngZoom(latLng, 15));
      _showSnackBar('Current location found', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to get current location', Colors.red);
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

  void _onMapTap(LatLng latLng) {
    _showConfirmationDialog(latLng);
  }

  void _showConfirmationDialog(LatLng latLng) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Confirm Pickup Location',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Is this your desired pickup location?',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('No'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _pickupLocation = latLng;
                      _updateMarkers();
                    });
                    _saveOrUpdatePickupLocation();
                    Navigator.pop(context);
                  },
                  child: const Text('Yes'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveOrUpdatePickupLocation() async {
    if (_pickupLocation != null) {
      final requestRef = FirebaseFirestore.instance
          .collection('ride_requests')
          .doc(widget.email);

      await requestRef.set({
        'email': widget.email,
        'pickup_location': GeoPoint(_pickupLocation!.latitude, _pickupLocation!.longitude),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      }).then((_) {
        _showSnackBar('Pickup location saved/updated', Colors.green);
      }).catchError((error) {
        _showSnackBar('Failed to save/update pickup location', Colors.red);
      });
    }
  }

  void _listenForRequestStatus() {
    requestStatusSubscription = FirebaseFirestore.instance
        .collection('ride_requests')
        .doc(widget.email)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final status = data['status'];
        final pickupLocation = data['pickup_location'] as GeoPoint;
        final driverEmail = data['driver_email'] as String?;

        if (mounted) {
          setState(() {
            _requestStatus = status;
            _pickupLocation = LatLng(pickupLocation.latitude, pickupLocation.longitude);

            // Cancel previous subscription if it exists
            if (driverLocationSubscription != null) {
              driverLocationSubscription!.cancel();
              driverLocationSubscription = null; // Reset to null after canceling
            }

            if (driverEmail != null) {
              _listenForDriverLocation(driverEmail);
            } else {
              _driverLocation = null;
            }

            _updateMarkers();

            // Reset navigation if trip is completed or unsuccessful
            if (status == 'completed' || status == 'unsuccessful') {
              _resetNavigation();
            } else if (status == 'pending' || status == 'onGoing') {
              mapController.animateCamera(CameraUpdate.newLatLngZoom(_pickupLocation!, 15));
            }
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _requestStatus = 'No active request';
            _pickupLocation = null;
            _driverLocation = null;
            _resetNavigation(); // Ensure to reset when no active request
          });
        }
      }
    });
  }

  void _resetNavigation() {
    setState(() {
      _polylines.clear(); // Clear the polylines to remove the blue navigation line
      polylineCoordinates.clear();
    });
  }

  void _listenForDriverLocation(String driverEmail) {
    driverLocationSubscription = FirebaseFirestore.instance
        .collection('drivers')
        .doc(driverEmail)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data()!;
        final location = data['location'] as GeoPoint;

        if (mounted) {
          setState(() {
            _driverLocation = LatLng(location.latitude, location.longitude);
            _updateMarkers();
            if (_pickupLocation != null) {
              _getPolyline();
            }
          });
        }
      }
    });
  }

  void _updateMarkers() {
    _markers.clear();
    if (_pickupLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(_getMarkerColor()),
        infoWindow: InfoWindow(title: 'Pickup Location ($_requestStatus)'),
      ));
    }
    if (_driverLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('driver'),
        position: _driverLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Driver Location'),
      ));
    }
  }

  double _getMarkerColor() {
    switch (_requestStatus) {
      case 'pending':
        return BitmapDescriptor.hueYellow;
      case 'onGoing':
        return BitmapDescriptor.hueBlue;
      case 'completed':
        return BitmapDescriptor.hueGreen;
      case 'unsuccessful':
        return BitmapDescriptor.hueRed;
      default:
        return BitmapDescriptor.hueRed;
    }
  }

  Future<void> _getPolyline() async {
    PolylineRequest request = PolylineRequest(
      origin: PointLatLng(_driverLocation!.latitude, _driverLocation!.longitude),
      destination: PointLatLng(_pickupLocation!.latitude, _pickupLocation!.longitude),
      mode: TravelMode.driving,
    );

    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      googleApiKey: apiKey,
      request: request,
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates.clear();
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    if (mounted) {
      setState(() {
        _polylines.clear();
        _polylines.add(Polyline(
          polylineId: const PolylineId('poly'),
          color: Color.fromARGB(255, 40, 122, 198),
          points: polylineCoordinates,
          width: 5,
        ));
      });
    }
  }

  Future<void> _searchPlace() async {
    final String? selectedPlaceId = await showSearch(
      context: context,
      delegate: PlaceSearch(apiKey),
    );

    if (selectedPlaceId != null && selectedPlaceId.isNotEmpty) {
      final details = await _getPlaceDetails(selectedPlaceId);
      if (details != null) {
        final lat = details['geometry']['location']['lat'];
        final lng = details['geometry']['location']['lng'];
        final newLatLng = LatLng(lat, lng);

        mapController.animateCamera(CameraUpdate.newLatLngZoom(newLatLng, 15));
        _showConfirmationDialog(newLatLng);
      }
    }
  }

  Future<Map<String, dynamic>?> _getPlaceDetails(String placeId) async {
    final response = await http.get(
      Uri.parse('https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$apiKey'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['result'];
    } else {
      _showSnackBar('Failed to get place details', Colors.red);
      return null;
    }
  }

  void _goToPickupLocation() {
    if (_pickupLocation != null) {
      mapController.animateCamera(CameraUpdate.newLatLngZoom(_pickupLocation!, 15));
      _showSnackBar('Navigating to pending pickup location', Colors.green);
    }
  }

  @override
  void dispose() {
    requestStatusSubscription.cancel();
    if (driverLocationSubscription != null) {
      driverLocationSubscription!.cancel();
    }
    super.dispose();
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
          zoomControlsEnabled: false,
          myLocationEnabled: true,
          markers: _markers,
          polylines: _polylines,
          onTap: _onMapTap,
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
                    child: Row(
                      children: [
                        Expanded(
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
                        IconButton(
                          icon: const Icon(Icons.search, color: Colors.blue),
                          onPressed: _searchPlace,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      children: [
                        const Icon(Icons.info, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Request Status: $_requestStatus',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_pickupLocation != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: ElevatedButton(
                      onPressed: _goToPickupLocation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Go to Pickup Location'),
                    ),
                  ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: FloatingActionButton(
                    onPressed: _getCurrentLocation,
                    backgroundColor: Colors.blue,
                    child: const Icon(Icons.my_location, color: Colors.white),
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