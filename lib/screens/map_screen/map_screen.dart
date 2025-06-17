
import 'dart:async';
import 'package:almost_zenly/models/app_user.dart';
import 'package:almost_zenly/screens/map_screen/components/profile_button.dart';
import 'package:almost_zenly/screens/map_screen/components/sign_in_button.dart';
import 'package:almost_zenly/screens/map_screen/components/user_card_list.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // ------------  Users  ------------
  late StreamSubscription<List<AppUser>> usersStream;
  late Position currentUserPosition;


  Set<Marker> markers = {};

   // ------------  Methods for Markers  ------------
  void _watchUsers() {
   usersStream = getAppUsersStream().listen((users) {
     _setUserMarkers(users);
   });
  }

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

  void setCurrentUserId(String value) {
       setState(() {
       currentUserId = value;
       });
   }

// ------------  Auth  ------------
  late StreamSubscription<User?> authUserStream;
  String currentUserId = '';

  @override
    void initState() {
        // ログイン状態の変化を監視
        _watchSignInState();
        super.initState();
        _watchUsers();
    }

  // ------------  Methods for Auth  ------------
  void _watchSignInState() {
      authUserStream =
          FirebaseAuth.instance.authStateChanges().listen((User? user) async {
          if (user == null) {
          setIsSignedIn(false);
          setCurrentUserId(''); // サインアウト時は空にする
          clearUserMarkers();
          } else {
          setIsSignedIn(true);
          setCurrentUserId(user.uid); // サインインしている時はuidを登録
          await setUsers();
          }
      });
  }

  // ------------  Methods for Firestore  ------------

 Future<void> _updateUserLocationInFirestore(Position position) async {
   if (isSignedIn) {
     await FirebaseFirestore.instance
         .collection('app_users')
         .doc(currentUserId)
         .update({
       'location': GeoPoint(
         position.latitude,
         position.longitude,
       ),
     });
   }
 }

 Future<List<AppUser>> getAppUsers() async {
   return await FirebaseFirestore.instance.collection('app_users').get().then(
       (snps) => snps.docs
           .map((doc) => AppUser.fromDoc(doc.id, doc.data()))
           .toList());
 }

 Future<void> setUsers() async {
   await getAppUsers().then((users) {
     _setUserMarkers(users);
   });
 }

 void clearUserMarkers() {
   setState(() {
     markers.removeWhere(
       (marker) => marker.markerId != const MarkerId('current_location'),
     );
   });
 }


 Stream<List<AppUser>> getAppUsersStream() {
  return FirebaseFirestore.instance.collection('app_users').snapshots().map(
        (snp) => snp.docs
            .map((doc) => AppUser.fromDoc(doc.id, doc.data()))
            .toList(),
      );
  }

  void _setUserMarkers(List<AppUser> users) {
   // サインインしていなければ後続処理を行わない
   if (!isSignedIn) {
     return;
   }
   // 自分以外のユーザーのリストを作成
   final otherUsers = users.where((user) => user.id != currentUserId).toList();

   // ユーザーのマーカーをセット
   for (final user in otherUsers) {
     if (user.location != null) {
       final lat = user.location!.latitude;
       final lng = user.location!.longitude;
       setState(() {
         // 既にマーカーが作成されている場合は、取り除く
         if (markers
             .where((m) => m.markerId == MarkerId(user.id!))
             .isNotEmpty) {
           markers.removeWhere(
             (marker) => marker.markerId == MarkerId(user.id!),
           );
         }
         // 取り除いた上でマーカーを追加
         markers.add(Marker(
           markerId: MarkerId(user.id!),
           position: LatLng(lat, lng),
           icon: BitmapDescriptor.defaultMarkerWithHue(
             BitmapDescriptor.hueGreen,
           ),
         ));
       });
     }
   }
 }

  //変数initialCameraPositionに緯度と経度・拡大率を渡したカメラの初期値情報を格納する。
  final CameraPosition initialCameraPosition = const CameraPosition(
    target: LatLng(35.681236, 139.767125), // 東京駅
    zoom: 16.0,
  );


  // 現在地通知の設定
  final LocationSettings locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high, //正確性:highはAndroid(0-100m),iOS(10m)
    distanceFilter: 20,
  );


  @override
  void dispose() {
    mapController.dispose();
    positionStream.cancel();
    // ログイン状態の監視を解放
    authUserStream.cancel();
    // ユーザーの購読処理を破棄
    usersStream.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
    body: Stack(
      alignment: Alignment.bottomCenter,
      children: [
      GoogleMap(
        //カメラの初期位置を渡してGoogleMapを表示する。
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
      StreamBuilder(
           stream: getAppUsersStream(),
           builder: (BuildContext context, snapshot) {
             if (snapshot.hasData && isSignedIn) {
               // 自分以外のユーザーかつlocationデータを持つユーザー配列を取得
               final users = snapshot.data!
                   .where((user) => user.id != currentUserId)
                   .where((user) => user.location != null)
                   .toList();

               return UserCardList(
                 onPageChanged: (index) {
                  late GeoPoint location;
                    if (index == 0) {
                      location = GeoPoint(
                        currentUserPosition.latitude,
                        currentUserPosition.longitude,
                      );
                    } else {
                      //スワイプ後のユーザーの位置情報を取得
                      location = users.elementAt(index - 1).location!;
                    }
                   
                   //スワイプ後のユーザーの座標までカメラを移動
                   mapController.animateCamera(
                     CameraUpdate.newCameraPosition(
                       CameraPosition(
                         target: LatLng(
                           location.latitude,
                           location.longitude,
                         ),
                         zoom: 16.0,
                       ),
                     ),
                   );
                 },
                 appUsers: users,
               );
             }
             // サインアウト時、ユーザーデータを未取得時に表示するwidget
             return Container();
           },
         ),
      ],
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
        currentUserPosition = position;
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

      // Firestoreに現在地を更新
     await _updateUserLocationInFirestore(position);

      // 現在地にカメラを移動
      await mapController.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: await mapController.getZoomLevel(),
          ),
        ),
      );
    });
  }

  // 位置情報の許可されていない時に許可をリクエストする。
  Future<void> _requestPermission() async {
    // 現在位置の取得許可状況を確認する
    LocationPermission permission = await Geolocator.checkPermission();
    //そのステータスが許可されていない場合、
    if (permission == LocationPermission.denied) {
      //ユーザに位置情報の使用許可を求める
      await Geolocator.requestPermission();
    }
  }

  Future<void> _moveToCurrentLocation() async {
    // 現在位置の取得許可状況を確認する
    LocationPermission permission = await Geolocator.checkPermission();
    //位置情報の許可されている場合（常に許可されている・許可されている場合）
    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      // 精度を高く現在地の緯度と経度を取得して変数Positionに格納する
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