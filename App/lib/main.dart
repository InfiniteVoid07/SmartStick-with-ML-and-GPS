import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:dio/dio.dart';
import 'face_recognition_page.dart'; // Ensure you have this page in your project

void main() {
  runApp(SmartStickApp());
}

class SmartStickApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Stick App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SmartStickHomePage(),
    );
  }
}

class SmartStickHomePage extends StatefulWidget {
  @override
  _SmartStickHomePageState createState() => _SmartStickHomePageState();
}

class _SmartStickHomePageState extends State<SmartStickHomePage> {
  double distanceThreshold = 100.0;
  double hapticPower = 50.0;
  double audioVolume = 50.0;

  GoogleMapController? mapController;
  LocationData? _currentLocationData;
  Location location = Location();
  LatLng? destination;
  Set<Marker> _markers = {};
  List<LatLng> polylineCoordinates = [];

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    _currentLocationData = await location.getLocation();
    location.onLocationChanged.listen((LocationData currentLocation) {
      setState(() {
        _currentLocationData = currentLocation;
        _updateCurrentLocationMarker();
      });
    });
  }

  void _updateCurrentLocationMarker() {
    if (_currentLocationData != null) {
      LatLng currentLatLng = LatLng(
        _currentLocationData!.latitude!,
        _currentLocationData!.longitude!,
      );

      _markers.add(
        Marker(
          markerId: MarkerId("start"),
          position: currentLatLng,
          infoWindow: InfoWindow(title: "Current Location"),
        ),
      );

      if (mapController != null) {
        mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: currentLatLng, zoom: 15),
          ),
        );
      }
    }
  }

  void _setDestination(LatLng destinationLocation) {
    setState(() {
      _markers.removeWhere((marker) => marker.markerId.value == "destination");
      destination = destinationLocation;
      _markers.add(
        Marker(
          markerId: MarkerId("destination"),
          position: destinationLocation,
          infoWindow: InfoWindow(title: "Destination"),
        ),
      );
    });
  }

  Future<void> _drawRoute() async {
    if (_currentLocationData != null && destination != null) {
      LatLng startLatLng = LatLng(
        _currentLocationData!.latitude!,
        _currentLocationData!.longitude!,
      );
      LatLng destinationLatLng = destination!;

      final Dio dio = Dio();
      final String url = 'https://maps.googleapis.com/maps/api/directions/json';

      try {
        final response = await dio.get(url, queryParameters: {
          'origin': '${startLatLng.latitude},${startLatLng.longitude}',
          'destination':
              '${destinationLatLng.latitude},${destinationLatLng.longitude}',
          'key': 'AIzaSyCCzlW7IfXbg8DBBTMimiCn50WjwfOELrA',
        });

        if (response.data['routes'].isNotEmpty) {
          final points =
              response.data['routes'][0]['overview_polyline']['points'];
          final decodedPoints = _decodePolyline(points);
          setState(() {
            polylineCoordinates = decodedPoints;
          });
        }
      } catch (e) {
        print("Error fetching route: $e");
      }
    }
  }

  List<LatLng> _decodePolyline(String polyline) {
    List<LatLng> coordinates = [];
    int index = 0, len = polyline.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      coordinates.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return coordinates;
  }

  @override
  Widget build(BuildContext context) {
    final CameraPosition initialCameraPosition = CameraPosition(
      target: LatLng(
        _currentLocationData?.latitude ?? 12.840881567226841,
        _currentLocationData?.longitude ?? 80.1534604888108,
      ),
      zoom: 15.0,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Stick App'),
        actions: [
          IconButton(
            icon: Icon(Icons.face),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => VideoDetectionPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: initialCameraPosition,
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
                _updateCurrentLocationMarker();
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
              markers: _markers,
              polylines: {
                Polyline(
                  polylineId: PolylineId("route"),
                  points: polylineCoordinates,
                  color: Colors.blue,
                  width: 5,
                ),
              },
              onTap: (LatLng tappedLocation) {
                _setDestination(tappedLocation);
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  if (_currentLocationData != null) {
                    LatLng destLatLng = LatLng(
                      _currentLocationData!.latitude! + 0.01,
                      _currentLocationData!.longitude! + 0.01,
                    );
                    _setDestination(destLatLng);
                  }
                },
                child: Text("Set Destination"),
              ),
              ElevatedButton(
                onPressed: () {
                  _drawRoute();
                },
                child: Text("Start Navigation"),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Settings:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Distance Threshold: ${distanceThreshold.toInt()} cm'),
                    Slider(
                      value: distanceThreshold,
                      min: 10.0,
                      max: 200.0,
                      onChanged: (value) {
                        setState(() {
                          distanceThreshold = value;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Haptic Power: ${hapticPower.toInt()}%'),
                    Slider(
                      value: hapticPower,
                      min: 0.0,
                      max: 100.0,
                      onChanged: (value) {
                        setState(() {
                          hapticPower = value;
                        });
                      },
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Audio Volume: ${audioVolume.toInt()}%'),
                    Slider(
                      value: audioVolume,
                      min: 0.0,
                      max: 100.0,
                      onChanged: (value) {
                        setState(() {
                          audioVolume = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
