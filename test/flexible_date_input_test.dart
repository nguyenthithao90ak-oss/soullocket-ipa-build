import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soullocket_app/utils/flexible_date_input.dart';

void main() {
  tearDown(() {
    DateInputUtils.order = DateFieldOrder.dmy;
    DateInputUtils.acceptBuddhistEra = false;
  });

  group('thứ tự ngày theo vùng', () {
    test('orderFor', () {
      expect(
        DateInputUtils.orderFor(languageCode: 'vi', countryCode: 'VN'),
        DateFieldOrder.dmy,
      );
      expect(
        DateInputUtils.orderFor(languageCode: 'en', countryCode: 'US'),
        DateFieldOrder.mdy,
      );
      expect(
        DateInputUtils.orderFor(languageCode: 'en', countryCode: 'GB'),
        DateFieldOrder.dmy,
      );
      expect(
        DateInputUtils.orderFor(languageCode: 'ja', countryCode: 'JP'),
        DateFieldOrder.ymd,
      );
      expect(
        DateInputUtils.orderFor(languageCode: 'tl', countryCode: 'PH'),
        DateFieldOrder.mdy,
      );
      expect(
        DateInputUtils.orderFor(languageCode: 'de', countryCode: 'US'),
        DateFieldOrder.dmy,
      );
    });

    test('người dùng Mỹ gõ 03/04/2024 là ngày 4 tháng 3', () {
      DateInputUtils.order = DateFieldOrder.mdy;
      expect(DateInputUtils.parse('03/04/2024'), DateTime(2024, 3, 4));
      expect(DateInputUtils.formatDisplayDate(DateTime(2024, 3, 4)), '03/04/2024');
      // Gõ nhầm kiểu ngày trước vẫn hiểu được khi không thể là tháng.
      expect(DateInputUtils.parse('14/03/2024'), DateTime(2024, 3, 14));
      expect(DateInputUtils.parse('03142024'), DateTime(2024, 3, 14));
    });

    test('người dùng Việt Nam giữ nguyên dd/MM/yyyy', () {
      expect(DateInputUtils.parse('03/04/2024'), DateTime(2024, 4, 3));
      expect(DateInputUtils.parse('03042024'), DateTime(2024, 4, 3));
      expect(DateInputUtils.parse('2024-04-03'), DateTime(2024, 4, 3));
      expect(DateInputUtils.formatDisplayDate(DateTime(2024, 4, 3)), '03/04/2024');
    });

    test('Nhật/Hàn/Trung dùng năm trước', () {
      DateInputUtils.order = DateFieldOrder.ymd;
      expect(DateInputUtils.parse('20240403'), DateTime(2024, 4, 3));
      expect(DateInputUtils.formatDisplayDate(DateTime(2024, 4, 3)), '2024/04/03');
      const formatter = FlexibleDateInputFormatter();
      final value = formatter.formatEditUpdate(
        TextEditingValue.empty,
        const TextEditingValue(
          text: '20240403',
          selection: TextSelection.collapsed(offset: 8),
        ),
      );
      expect(value.text, '2024/04/03');
    });

    test('năm Phật lịch cho tiếng Thái', () {
      DateInputUtils.configureLocale(languageCode: 'th', countryCode: 'TH');
      expect(DateInputUtils.parse('14/02/2567'), DateTime(2024, 2, 14));
    });
  });

  group('câu trả lời khôi phục không phụ thuộc ngôn ngữ', () {
    test('băm cũ (dd/MM/yyyy) vẫn khớp khi người dùng đổi sang Mỹ', () {
      final legacy = DateInputUtils.canonicalRecoveryAnswer('05/03/1998');
      expect(legacy, '1998-03-05');
      DateInputUtils.order = DateFieldOrder.mdy;
      expect(
        DateInputUtils.recoveryAnswerCandidates('03/05/1998'),
        contains(legacy),
      );
      expect(
        DateInputUtils.recoveryAnswerCandidates('1998-03-05'),
        contains(legacy),
      );
    });

    test('ngày/tháng không năm luôn lưu dạng dd/MM', () {
      DateInputUtils.order = DateFieldOrder.mdy;
      expect(DateInputUtils.canonicalRecoveryAnswer('3/14'), '14/03');
      DateInputUtils.order = DateFieldOrder.dmy;
      expect(
        DateInputUtils.recoveryAnswerCandidates('14/3'),
        contains('14/03'),
      );
    });

    test('nhận diện câu hỏi ngày sinh ở nhiều ngôn ngữ', () {
      for (final question in [
        'Ngày sinh của bạn?',
        'Your date of birth?',
        'あなたの生年月日は?',
        'Tu fecha de nacimiento?',
        'Ваша дата рождения?',
      ]) {
        expect(DateInputUtils.looksLikeBirthQuestion(question), isTrue);
      }
      expect(
        DateInputUtils.looksLikeBirthQuestion('Your favorite food?'),
        isFalse,
      );
    });
  });
}
