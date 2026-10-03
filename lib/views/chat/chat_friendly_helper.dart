import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'dart:math';

class ChatFriendlyHelper {
  static List<String> get greetings => [
        L10nService().translate('ui_chat_ch_o_b_n_nha_h_m_751ce9'),
        L10nService().translate('ui_chat_xin_ch_o_c_n_t_m_08b8ea'),
        L10nService().translate('ui_chat_hi_b_n_m_nh_lu_n_eb632c'),
      ];

  static List<String> get wishes => [
        L10nService().translate('ui_chat_ch_c_b_n_m_t_ng_5e10d6'),
        L10nService().translate('ui_chat_ng_ngon_v_c_nh_ng_gi_5cafcb'),
      ];

  static List<String> get encouragements => [
        L10nService().translate('ui_chat_ng_bu_n_nh_m_i_chuy_54e270'),
        L10nService().translate('ui_chat_b_n_l_m_t_t_l_c57d27'),
        L10nService().translate('ui_chat_c_l_n_b_n_nh_m_945257'),
      ];

  static List<String> get offlineResponses => [
        L10nService().translate('ui_chat_m_ng_c_v_y_u_qu_d71e7b'),
        L10nService().translate('ui_chat_h_nh_nh_m_t_k_t_15fe35'),
        L10nService().translate('ui_chat_m_nh_ang_b_r_t_m_80d3bd'),
      ];

  static Map<String, List<String>> get qaPairs => {
        'mật khẩu|pass': [
          L10nService().translate('ui_chat_n_u_b_n_qu_n_m_ec0154'),
        ],
        'buồn|chán|mệt': [
          L10nService().translate('ui_chat_th_ng_qu_ng_bu_n_n_d2bed0'),
          L10nService().translate('ui_chat_m_i_chuy_n_r_i_s_079e84'),
        ],
        'yêu|thích': [
          L10nService().translate('ui_chat_y_u_th_ng_lu_n_l_84971f'),
          L10nService().translate('ui_chat_nghe_l_ng_m_n_qu_ch_d3f63e'),
        ],
        'tên|là ai': [
          L10nService().translate('ui_chat_m_nh_l_tr_l_ai_c_de4aaa'),
        ],
      };

  static String getRandom(List<String> list) {
    return list[Random().nextInt(list.length)];
  }

  static String findPredefinedResponse(String text) {
    final lowerText = text.toLowerCase();
    for (final entry in qaPairs.entries) {
      final keys = entry.key.split('|');
      if (keys.any((k) => lowerText.contains(k))) {
        return getRandom(entry.value);
      }
    }
    return '';
  }

  static String getFriendlyResponse({
    String? userText,
    bool isOffline = false,
  }) {
    // 1. Ưu tiên tìm trong danh sách thiết lập nếu có text
    if (userText != null && userText.isNotEmpty) {
      final predefined = findPredefinedResponse(userText);
      if (predefined.isNotEmpty) return predefined;
    }

    // 2. Nếu offline và không khớp câu hỏi, dùng câu offline ngẫu nhiên
    if (isOffline) {
      return getRandom(offlineResponses);
    }

    // 3. Mặc định trả về câu ngẫu nhiên vui vẻ
    final all = [...greetings, ...wishes, ...encouragements];
    return getRandom(all);
  }
}
