import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class SensorHelper {
  static StreamController<AccelerometerEvent>? _accelerometerController;
  static StreamSubscription<AccelerometerEvent>? _accelerometerSub;

  static StreamController<UserAccelerometerEvent>? _userAccelerometerController;
  static StreamSubscription<UserAccelerometerEvent>? _userAccelerometerSub;

  static Stream<AccelerometerEvent> get accelerometerEvents {
    _accelerometerController ??= StreamController<AccelerometerEvent>.broadcast(
      onListen: () {
        _accelerometerSub ??= accelerometerEventStream().listen(
          (event) {
            if (_accelerometerController?.isClosed == false) {
              _accelerometerController?.add(event);
            }
          },
          onError: (err) {
            _accelerometerController?.addError(err);
          },
        );
      },
      onCancel: () {
        _accelerometerSub?.cancel();
        _accelerometerSub = null;
        _accelerometerController = null;
      },
    );
    return _accelerometerController!.stream;
  }

  static Stream<UserAccelerometerEvent> get userAccelerometerEvents {
    _userAccelerometerController ??=
        StreamController<UserAccelerometerEvent>.broadcast(
      onListen: () {
        _userAccelerometerSub ??= userAccelerometerEventStream().listen(
          (event) {
            if (_userAccelerometerController?.isClosed == false) {
              _userAccelerometerController?.add(event);
            }
          },
          onError: (err) {
            _userAccelerometerController?.addError(err);
          },
        );
      },
      onCancel: () {
        _userAccelerometerSub?.cancel();
        _userAccelerometerSub = null;
        _userAccelerometerController = null;
      },
    );
    return _userAccelerometerController!.stream;
  }
}
