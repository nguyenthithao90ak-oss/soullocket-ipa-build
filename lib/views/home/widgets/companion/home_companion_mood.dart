import 'package:flutter/widgets.dart';

/// Trạng thái người ấy mà bé đại diện (thỏ = người ấy, gấu = mình).
enum HomeCompanionPartnerStatus { unknown, online, away }

/// Phần trình bày thêm của một bé, do Scene cập nhật theo ticker.
/// Chỉ ảnh hưởng hình vẽ; vị trí/đường đi vẫn do [HomeCompanionMotion].
class HomeCompanionMood extends ChangeNotifier {
  double _opacity = 1;
  bool _dozing = false;
  bool _carryingLetter = false;
  String? _bubble;
  double _bubbleOpacity = 0;
  TextDirection bubbleDirection = TextDirection.ltr;
  TextStyle bubbleStyle = const TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w700,
    color: Color(0xFF6B3A4C),
  );

  /// 1 = rõ hẳn; thấp hơn khi thân bé đang đè lên chữ/khối nội dung.
  double get opacity => _opacity;
  set opacity(double value) {
    final next = value.clamp(0.0, 1.0).toDouble();
    if ((next - _opacity).abs() < 0.01 && next != 1 && next != 0) return;
    if (next == _opacity) return;
    _opacity = next;
    notifyListeners();
  }

  /// Nhắm mắt, thở chậm, có chữ "z" bay lên.
  bool get dozing => _dozing;
  set dozing(bool value) {
    if (value == _dozing) return;
    _dozing = value;
    notifyListeners();
  }

  /// Cầm phong thư thay cho đạo cụ đang đeo.
  bool get carryingLetter => _carryingLetter;
  set carryingLetter(bool value) {
    if (value == _carryingLetter) return;
    _carryingLetter = value;
    notifyListeners();
  }

  /// Bong bóng chữ ngắn trên đầu bé; null khi không hiện.
  String? get bubble => _bubble;
  double get bubbleOpacity => _bubbleOpacity;

  void setBubble(String? text, double opacity) {
    final nextOpacity = text == null ? 0.0 : opacity.clamp(0.0, 1.0);
    if (text == _bubble && (nextOpacity - _bubbleOpacity).abs() < 0.02) {
      return;
    }
    _bubble = text;
    _bubbleOpacity = nextOpacity.toDouble();
    notifyListeners();
  }
}
