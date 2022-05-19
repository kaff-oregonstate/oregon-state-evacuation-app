import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:evac_app/db/trajectory_database_manager.dart';
import 'package:evac_app/export/create_gpx.dart';
import 'package:evac_app/location_tracking/location_permissions.dart';
import 'package:evac_app/location_tracking/location_service.dart';
import 'package:evac_app/models/participant_location.dart';
import 'package:path_provider/path_provider.dart';

// https://github.com/filiph/hn_app/blob/master/lib/src/notifiers/worker.dart

class LocationTracker {
  final _databaseManager = TrajectoryDatabaseManager.getInstance();
  bool _running = false;
  LocationService? _locationService;
  StreamSubscription? _subscription;

  int _counter = 1;
  ParticipantLocation? _initialLocation;
  double distanceTravelled = 0.0;
  int currentElevation = 0;

  LocationTracker() {}

  void startLogging() async {
    if (!_running) {
      String result = await canUseLocation();
      if (result == 'yes') {
        print('location available');
        // clearing previous data
        // #88: this could be moved to "Aquire GPS Signal"
        await _clearDB(_databaseManager);
        // getting location stream:
        _locationService = LocationService();
        // this line makes sure that if a second drill is run while app is still
        // open, the data from the end of the last drill is not erroneously put
        // into the results for the new drill…
        //    FALSE! THIS LINE WAS MAKING THE LOCATION TRACKING NEVER STOP, AS
        //    "DRAIN()" CREATES A NEW SUBSCRIPTION WHICH ONLY COMPLETES WHEN THE
        //    STREAM IS EMPTIED, WHICH A LOCATION STREAM NEVER WILL BE!
        // _locationService!.stream.drain();

        // so now we are trying this "skip(1)" business to avoid stale data, but
        // it's not working yet...
        // https://github.com/kaff-oregonstate/oregon-state-evacuation-app/issues/88
        // also we are now using "geolocator" package instead of "location"
        // because that was one of the attempts I made to fix the incessant
        // location tracking. I genuinely think this improved it.
        // https://github.com/kaff-oregonstate/oregon-state-evacuation-app/issues/89
        _subscription = _locationService!.stream.skip(1).listen((newLocation) =>
            _setCurrentLocation(_databaseManager, newLocation));
        _running = true;
      } else {
        print('location not available');
      }
    }
  }

  Future<void> stopLogging() async {
    if (_running) {
      _subscription!.cancel();
      _locationService = null;
      _subscription = null;
      _running = false;
    }
  }

  Future<String> createTrajectory(String filename) async {
    // if able to create gpx
    final directory = await getApplicationDocumentsDirectory();
    var exists = Directory(directory.path + '/gpxFiles/').existsSync();
    if (!exists) {
      Directory(directory.path + '/gpxFiles/').createSync();
    }
    var file = File(directory.path + '/gpxFiles/' + filename + '.gpx');
    exists = file.existsSync();
    if (exists) {
      file.deleteSync();
    }
    //  + '-' + DateTime.now().toIso8601String().substring(0,19)
    await CreateGpx().fromList(file);
    await _clearDB(_databaseManager);
    return file.path;
  }

  // right now we are throwing away any results if they back out. In the future we should have much more complex location logging, with pause+resume, etc.

  void _setCurrentLocation(
    _databaseManager,
    ParticipantLocation newLocation,
  ) async {
    if (_counter == 5 && _initialLocation == null) {
      _initialLocation = newLocation;
    }
    if (_counter == 0) {
      // use newLocation to update:
      // update elevation
      if (newLocation.elevation != null)
        // meters to feet
        currentElevation = (newLocation.elevation! * 3.28084).truncate();
      // update distance travelled
      distanceTravelled = calcDistTravelled(_initialLocation!, newLocation);
    }
    await _databaseManager.insert(location: newLocation);
    _counter = (_counter + 1) % 10;
  }

  static Future<void> _clearDB(
      TrajectoryDatabaseManager _databaseManager) async {
    await _databaseManager.wipeData();
    return;
  }

  // function to convert degrees to radians
  static double deg2rad(double deg) {
    return deg * 3.14159 / 180;
  }

  // function to calculate the distance travelled in miles
  static double calcDistTravelled(
    ParticipantLocation start,
    ParticipantLocation cur,
  ) {
    const R = 6371;
    var dLat = deg2rad(cur.latitude - start.latitude);
    var dLon = deg2rad(cur.longitude - start.longitude);
    var a = sin(dLat / 2) * sin(dLat / 2) +
        cos(deg2rad(start.latitude)) *
            cos(deg2rad(cur.latitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    var c = 2 * atan2(sqrt(a), sqrt(1 - a));
    var d = R * c; // Distance in km
    return d * 0.6214; // convert to mile
  }
}
