
import 'dart:async';
import 'package:almost_zenly/screens/map_screen/components/profile_button.dart';
import 'package:almost_zenly/screens/map_screen/components/sign_in_button.dart';
import 'package:almost_zenly/screens/map_screen/components/sign_out_button.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController mapController;
  late StreamSubscription<Position> positionStream;

  Set<Marker> markers = {};

  // ------------  State changes  ------------
  bool isSignedIn = false;
  bool isLoading = false;

  void setIsSignedIn(bool value) {
      setState(() {
          isSignedIn = value;
      });
  }

  void _setIsLoading(bool value) {
    setState(() {
      isLoading = value;
    });
  }

// ------------  Auth  ------------
  late StreamSubscription<User?> authUserStream;

  @override
    void initState() {
        // ログイン状態の変化を監視
        _watchSignInState();
        super.initState();
    }

  // ------------  Methods for Auth  ------------
  void _watchSignInState() {
      authUserStream =
          FirebaseAuth.instance.authStateChanges().listen((User? user) {
          if (user == null) {
          setIsSignedIn(false);
          } else {
          setIsSignedIn(true);
          }
      });
  }


  final CameraPosition initialCameraPosition = const CameraPosition(
    target: LatLng(35.681236, 139.767125), // 東京駅
    zoom: 16.0,
  );

  // 現在地通知の設定
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high, //正確性:highはAndroid(0-100m),iOS(10m)
    distanceFilter: 0,
  );


  @override
  void dispose() {
    mapController.dispose();
    positionStream.cancel();
    // ログイン状態の監視を解放
    authUserStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        initialCameraPosition: initialCameraPosition,
        onMapCreated: (GoogleMapController controller) async {
          mapController = controller;
          await _requestPermission();
          await _moveToCurrentLocation();
          _watchCurrentLocation();
        },
        myLocationButtonEnabled: false,
        markers: markers,
      ),
      floatingActionButtonLocation: !isSignedIn
          ? FloatingActionButtonLocation.centerFloat
          : FloatingActionButtonLocation.endTop,
      floatingActionButton:
          !isSignedIn ? const SignInButton() : const ProfileButton(),
    );
  }

  Future<void> _signOut() async {
    _setIsLoading(true);
    await Future.delayed(const Duration(seconds: 1), () {});
    await FirebaseAuth.instance.signOut();
    _setIsLoading(false);
  }

  void _watchCurrentLocation() {
    // 現在地を監視
    positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((position) async {
      // マーカーの位置を更新
      setState(() {
        markers.removeWhere(
            (marker) => marker.markerId == const MarkerId('current_location'));

        markers.add(Marker(
          markerId: const MarkerId('current_location'),
          position: LatLng(
            position.latitude,
            position.longitude,
          ),
        ));
      });
      // 現在地にカメラを移動
      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );
    });
  }

  Future<void> _requestPermission() async {
    // 位置情報の許可を求める
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      await Geolocator.requestPermission();
    }
  }

  Future<void> _moveToCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // 現在地を取得
      final Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        markers.add(
          Marker(
            markerId: const MarkerId("current_location"),
            position: LatLng(
              position.latitude,
              position.longitude,
            ),
          ),
        );
      });

      // 現在地にカメラを移動
      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16.0,
          ),
        ),
      );
    }
  }

  
}