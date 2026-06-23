import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class SensorHelper {
  static StreamController<AccelerometerEvent>? _accelerometerController;
  static StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  static StreamController<UserAccelerometerEvent>? _userAccelerometerController;
  static StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSub;

  static Stream<AccelerometerEvent> get accelerometerEvents {
    if (_accelerometerController == null) {
      _accelerometerController = StreamController<AccelerometerEvent>.broadcast(
        onListen: () {
          if (_accelerometerSub == null) {
            _accelerometerSub = accelerometerEventStream().listen(
              (event) {
                if (_accelerometerController?.isClosed == false) {
                  _accelerometerController?.add(event);
                }
              },
              onError: (err) {
                _accelerometerController?.addError(err);
              },
            );
          }
        },
      );
    }
    return _accelerometerController!.stream;
  }

  static Stream<UserAccelerometerEvent> get userAccelerometerEvents {
    if (_userAccelerometerController == null) {
      _userAccelerometerController = StreamController<UserAccelerometerEvent>.broadcast(
        onListen: () {
          if (_userAccelerometerSub == null) {
            _userAccelerometerSub = userAccelerometerEventStream().listen(
              (event) {
                if (_userAccelerometerController?.isClosed == false) {
                  _userAccelerometerController?.add(event);
                }
              },
              onError: (err) {
                _userAccelerometerController?.addError(err);
              },
            );
          }
        },
      );
    }
    return _userAccelerometerController!.stream;
  }
}
