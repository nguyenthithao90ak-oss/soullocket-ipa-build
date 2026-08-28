part of '../l10n_service.dart';

abstract final class _L10nStaticData {
  static const Map<String, String> _vi = {
    'home_current_name_prefix': 'Tên đang dùng',
    'settings_role_swap_prefix': 'Đã đổi thành công sang vai',
    'Gửi thông báo thử đến điện thoại người ấy để kiểm tra xem thông báo có hiện ra ngoài màn hình không.': 'Gửi thông báo thử đến điện thoại người ấy để kiểm tra xem thông báo có hiện ra ngoài màn hình không.',
    'Đây là thông báo thử nghiệm loại Chat. Nếu bạn thấy tin này nghĩa là thông báo đang hoạt động! 🎉': 'Đây là thông báo thử nghiệm loại Chat. Nếu bạn thấy tin này nghĩa là thông báo đang hoạt động! 🎉',
    'Nếu bạn thấy tin này ngoài màn hình chính nghĩa là thông báo đang hoạt động bình thường! ✅': 'Nếu bạn thấy tin này ngoài màn hình chính nghĩa là thông báo đang hoạt động bình thường! ✅',
    'Tiện ích màn hình chỉ hỗ trợ trên thiết bị thật. Phần cấu hình này nên thao tác trên app cài đặt.': 'Tiện ích màn hình chỉ hỗ trợ trên thiết bị thật. Phần cấu hình này nên thao tác trên app cài đặt.',
    'Màu sắc và chủ đề của Tiện ích được lấy trực tiếp từ sự kiện bạn chọn ghim hoặc sự kiện gần nhất trong danh sách Sự Kiện & Kỷ Niệm.': 'Màu sắc và chủ đề của Tiện ích được lấy trực tiếp từ sự kiện bạn chọn ghim hoặc sự kiện gần nhất trong danh sách Sự Kiện & Kỷ Niệm.',
    'Hiển thị sự kiện tiếp theo (ví dụ: ngày sinh nhật, chuyến đi, ngày kỷ niệm yêu...) trực tiếp trên màn hình chính.': 'Hiển thị sự kiện tiếp theo (ví dụ: ngày sinh nhật, chuyến đi, ngày kỷ niệm yêu...) trực tiếp trên màn hình chính.',

    // === Quick Customize & Missing Keys ===

    // === Auth ===

    'auth_security_note':
        'Lưu ý: Có thể thêm trong Cài đặt sau khi tạo nhà. Cần thiết khi khôi phục tài khoản.',
    'auth_terms_confirm_prefix':
        'Tôi xác nhận đủ 13 tuổi trở lên và đồng ý với ',
    'auth_social_register_notice':
        'Việc đăng ký đồng nghĩa bạn xác nhận đủ 13 tuổi\nvà đồng ý với Điều khoản của chúng tôi.',
    'auth_social_login_notice':
        'Đăng nhập / Đăng ký qua Google hoặc Apple đồng nghĩa\nbạn xác nhận đủ 13 tuổi và đồng ý với Điều khoản.',
    'rel_change_anytime':
        'Bạn có thể thay đổi trạng thái bất kỳ lúc nào trong cài đặt',

    // === Settings UI ===
    'saved_local_sync_fail':
        'Đã lưu trên thiết bị này nhưng chưa đồng bộ cài đặt nâng cao: {error}',
    'name_change_notice':
        'Lưu ý: Tên nhà và Tên người dùng chỉ có thể thay đổi sau 7 ngày kể từ lần đổi cuối.',
    'settings_account_desc':
        'Chỉnh hồ sơ, email đăng nhập, ngôn ngữ, gói PRO và các thông tin tài khoản quan trọng.',
    'settings_security_desc':
        'Bật khóa ứng dụng, xác minh email, liên kết Google, PIN khôi phục và quản lý thiết bị đang đăng nhập.',
    'settings_theme_desc':
        'Đổi chủ đề, font chữ, ảnh nền, nhạc nền, hiệu ứng rơi, đồ họa.',
    'settings_widget_desc_web':
        'Xem trước đầy đủ giao diện widget, ảnh đôi, màu sắc và đồng bộ để mở tiếp trên điện thoại.',
    'settings_widget_desc_mobile':
        'Tạo widget đếm ngày yêu, ảnh kỷ niệm, kiểu tim, màu sắc, bố cục và ghim nhanh ra màn hình chính.',
    'settings_countdown_space_desc':
        'Mở một màn hình đếm ngày riêng, chỉ giữ lại khối đếm và tách khỏi giao diện home.',
    'settings_notifications_desc':
        'Chỉnh nhắc kỷ niệm, lời nhắc quan trọng, quyền thông báo và các cảnh báo cần thiết hằng ngày.',
    'settings_support_legal_desc':
        'Mở hướng dẫn sử dụng, trung tâm hỗ trợ, chính sách, điều khoản và các yêu cầu liên quan đến tài khoản.',
    'countdown_mode_no_date_desc':
        'Chưa có mốc ngày để hiển thị. Hãy đặt ngày bắt đầu trong thông tin nhà chung.',
    'settings_private_login_subtitle':
        'Sử dụng tài khoản Google hoặc email để đăng nhập an toàn.',
    'settings_secondary_email_enter_before_save':
        'Hãy nhập email phụ trước khi lưu',
    'settings_secondary_email_same_as_primary':
        'Email phụ không được trùng với email chính',
    'settings_secondary_email_sending_code':
        'Đang gửi mã xác nhận đến email phụ...',
    'settings_secondary_email_code_sent':
        'Đã gửi mã về email! Vui lòng kiểm tra.',
    'settings_secondary_email_verify_prompt':
        'Vui lòng nhập mã 6 số vừa được gửi đến {email}:',
    'settings_secondary_email_saved_success':
        'Đã xác thực và lưu email phụ thành công!',
    'settings_secondary_email_send_code_failed':
        'Không thể gửi mã xác nhận. Vui lòng thử lại sau.',
    'settings_secondary_email_send_network_error':
        'Lỗi mạng khi gửi email: {error}',
    'settings_supported_emails_only':
        'Hệ thống chỉ hỗ trợ đổi sang các loại email: {domains}',
    'settings_email_change_sent':
        'Đã gửi link xác nhận đổi email đến {email}. Hãy bấm vào link rồi quay lại đăng nhập.',
    'settings_email_requires_recent_login':
        'Phiên đăng nhập đã cũ. Hãy đăng xuất rồi đăng nhập lại trước khi đổi email.',
    'settings_email_daily_limit':
        'Bạn đã gửi quá 5 lần hôm nay. Vui lòng thử lại vào ngày mai.',
    'settings_email_wait_before_resend':
        'Vui lòng đợi {wait} nữa trước khi gửi lại.',
    'settings_email_pending_latest':
        'Mail xác thực mới nhất vẫn còn hiệu lực. Hãy mở email mới nhất rồi bấm "Tôi đã bấm link".',
    'settings_email_verification_sent':
        'Đã gửi email xác thực đến {email}. Hãy mở email mới nhất, đừng dùng mail cũ để tránh mã hết hiệu lực.',
    'settings_email_send_failed_with_error':
        'Không thể gửi email xác thực: {error}',
    'settings_email_not_verified_yet':
        'Chưa thấy email được xác thực. Hãy mở email mới nhất rồi bấm vào link xác minh.',
    'settings_email_check_failed':
        'Không thể kiểm tra trạng thái xác thực email.',
    'settings_email_check_failed_with_error':
        'Không thể kiểm tra trạng thái xác thực email: {error}',
    'settings_email_inbox_open_failed':
        'Không mở được hộp thư trên thiết bị này.',

    // === Tabs ===

    // === Finance ===

    // === Diary ===

    // === Secret Vault ===

    // === Time Capsule ===

    // === Export ===

    // === Media Cleanup ===

    // === Reward Store ===

    // === Community ===
    'community_compose_choose_desc':
        'Mỗi kiểu chia sẻ sẽ mở một khung soạn riêng để không còn cảm giác đăng status kiểu Facebook.',
    'community_compose_prepublish_note':
        'Ở màn tiếp theo bạn vẫn đổi được ảnh, vị trí, tâm trạng và quyền riêng tư trước khi đăng.',
    'community_compose_content_note':
        'Tối đa {count} ký tự. Hệ thống vẫn lọc spam và nội dung không an toàn trước khi đăng.',
    'community_compose_mode_confession_desc':
        'Viết điều bạn đang muốn nói ra, mềm hơn status và đúng chất app hơn.',
    'community_compose_hint_confession':
        'Hôm nay bạn muốn tâm sự điều gì với cộng đồng?',
    'community_compose_empty_message_confession':
        'Hãy viết vài dòng trước khi đăng tâm sự của bạn.',
    'community_compose_mode_photo_desc':
        'Đưa khoảnh khắc lên trước, cảm xúc và câu chuyện đi kèm sau.',
    'community_compose_hint_photo':
        'Viết vài dòng để kể cảm xúc phía sau bức ảnh này...',
    'community_compose_empty_message_photo':
        'Kiểu chia sẻ này cần có ít nhất một ảnh trước khi đăng.',
    'community_compose_mode_advice_desc':
        'Mô tả vấn đề rõ hơn để nhận góp ý đúng trúng tâm.',
    'community_compose_empty_message_advice':
        'Hãy viết vấn đề bạn cần xin lời khuyên trước khi gửi.',
    'community_compose_mode_signal_desc':
        'Giữ danh tính ẩn đi để chia sẻ một tín hiệu kín đáo hơn.',
    'community_compose_hint_signal':
        'Bạn muốn gửi tín hiệu nào mà chưa tiện lộ danh tính?',
    'community_compose_empty_message_signal':
        'Hãy viết nội dung trước khi gửi tín hiệu ẩn danh.',
    'community_post_type_mood_desc':
        'Kiểu chia sẻ theo cảm xúc, hướng tới câu chuyện và tâm trạng.',
    'community_post_type_photo_desc':
        'Bài ảnh ưu tiên hình ảnh và caption ngắn đi kèm.',
    'community_post_type_photo_hint':
        'Thêm caption ngắn cho bức ảnh bạn muốn chia sẻ...',
    'community_post_type_question_desc':
        'Phù hợp cho bài cần lời khuyên, gợi ý hoặc góc nhìn từ cộng đồng.',
    'community_post_type_question_hint':
        'Đặt câu hỏi hoặc xin lời khuyên từ cộng đồng...',
    'community_post_type_confession_desc':
        'Bài chia sẻ có sắc thái kín hơn và có thể tự động ẩn tên khi cần.',
    'community_post_type_confession_hint':
        'Viết điều bạn muốn tâm sự mà không cần lộ danh tính...',

    // === Chat ===

    // === Map ===

    // === Game ===

    // === Tarot ===
    'tarot_header_desc':
        'Tarot đọc theo người đang xem, nhịp nhắn tin, độ hợp cung và nhiều mặt cảm xúc thay vì chỉ nghĩa lá bài chung.',
    'tarot_empty_desc':
        'Mỗi mẫu sẽ đọc một khía cạnh khác nhau: nhịp hiện tại, gương cảm xúc, bản đồ mối quan hệ hoặc chương kế tiếp.',
    'tarot_reading_loading':
        'Tarot đang ghép tuổi, cung, nhịp kết nối và các lá bài để cho ra phần luận giải sát hơn.',
    'tarot_analysis_failed':
        'Chưa thể phân tích sâu lúc này. Tarot vẫn sẽ hiển thị phần ý nghĩa cơ bản của từng lá.',
    'tarot_spread_pulse_desc':
        'Đọc điều đang nổi lên, điều bạn đang giấu và hướng mở tim gần nhất.',
    'tarot_spread_mirror_desc':
        'Soi bạn, soi đối phương, điểm va chạm và cây cầu chữa lành.',
    'tarot_spread_map_desc':
        'Đi sâu vào gốc cảm xúc, nhu cầu thật, cách yêu, rào cản và hướng đi 7 ngày tới.',
    'tarot_spread_next_desc':
        'Đọc điều cần buông, điều nên mời vào, nhịp thời điểm và dấu hiệu sắp đến.',

    // === Love Tree / Garden ===

    // === Feedback ===

    // === Admin ===

    'countdown_unlock_ad':
        'Nhóm giao diện Quảng cáo chỉ cần xem 1 quảng cáo để mở toàn bộ trong 5 tiếng.',
    'countdown_unlock_pro':
        'Tài khoản Pro dùng mọi giao diện vòng đếm không cần xem quảng cáo.',
    'countdown_unlock_success':
        'Đã mở toàn bộ giao diện Quảng cáo trong 5 tiếng!',
    'theme_lite_mode_desc':
        'Tắt hiệu ứng, giảm lag cho máy yếu và ưu tiên khởi động nhanh.',
    'theme_graphics_desc':
        'Tự động tối ưu theo cấu hình máy và bạn có thể tự chỉnh lại bên dưới.',
    'theme_permission_desc':
        'Bấm nút dưới để cấp quyền GPS, Camera, Mic và Thông báo.',
    'theme_err_invalid_music_link':
        'Chỉ hỗ trợ file audio cục bộ hợp lệ trên thiết bị này (MP3, M4A, WAV, OGG, AAC, FLAC).',
    'theme_music_guide_desc':
        'Chỉ dùng file audio cục bộ trên thiết bị này. Nhạc sẽ không tự đồng bộ sang máy khác.',
    'theme_preview_desc':
        'Khung • nền • hiệu ứng • font sẽ cập nhật theo lựa chọn của bạn.',
    'theme_font_desc':
        'SoulLocket sẽ dùng font này cho khu Home và phần giao diện nổi bật.',
    'theme_event_empty_house':
        'Kỷ niệm mới sẽ xuất hiện ở đây sau khi bạn tạo nhà.',
    'theme_event_empty_list':
        'Chưa có kỷ niệm nào. Bạn có thể thêm ngay phía trên.',
    'theme_event_delete_message':
        'Kỷ niệm "{name}" sẽ bị xóa khỏi danh sách nhắc lịch.',
    'theme_event_description_hint':
        'Bên dưới đã tách rõ: khối hồng là kỷ niệm bạn thêm ở đây, khối xanh là lịch chung lấy từ mục Lịch.',
    'theme_event_anniversary_section_desc':
        'Các mốc riêng được thêm trong phần kỷ niệm',
    'theme_event_calendar_section_desc':
        'Các kế hoạch đang lấy từ mục Lịch chung',
    'theme_bg_in_use':
        'Bạn đang sử dụng nền tải lên, không thể sử dụng nền hệ thống',
    'widget_ios_guide':
        'Để thêm Widget trên iOS:\n1. Nhấn giữ vào màn hình chính\n2. Bấm nút dấu [+] ở góc màn hình\n3. Tìm "SoulLocket" và Thêm tiện ích',
    'account_err_email_domain':
        'Hệ thống chỉ hỗ trợ đổi sang các loại email: {domains}',
    'military_mode_desc':
        'Lưu ý: Chống nhìn trộm sẽ ẩn hoàn toàn màn hình đa nhiệm (App Switcher) để tránh bị nhìn trộm nội dung. Màn hình sẽ được che phủ khi bạn vuốt ra ngoài.',
    'backup_pin_desc':
        'Dùng PIN phụ để khôi phục và xác nhận một số thao tác bảo mật.',
    'vault_timeout_desc':
        'Thời gian yêu cầu nhập lại mật khẩu khi không dùng kho ảnh.',
    'err_security_q_locked':
        'Câu hỏi bảo mật đã được khóa. Không thể ghi đè nữa.',
    'widget_animated_heart_desc':
        'Bật để trái tim nhịp đập, tắt để trái tim cố định',
    'widget_home_desc':
        'Widget sẽ được đưa ra màn hình chính điện thoại để xem nhanh mỗi ngày.',
    'ios_widget_pending':
        'Chưa bật Widget Extension trên iOS (sẽ làm sau khi có Mac).',
    'err_no_vip_package':
        'Không tìm thấy gói PRO nào để khôi phục trên tài khoản này.',
    'restore_vip_desc':
        'Khôi phục mua hàng hữu ích khi bạn đổi máy hoặc vừa cài lại app.',
    'settings_locked_desc':
        'Bạn đã bật khóa cho khu bảo mật. Hãy xác thực lại để truy cập Cài đặt.',
    'auth_rate_limit_wait':
        'Bạn thao tác quá nhanh. Vui lòng chờ {seconds} giây rồi thử lại.',
    'auth_supported_domains_only':
        'Hệ thống chỉ hỗ trợ {action} bằng: {domains}!',
    'auth_reset_sending_code':
        'Đang gửi mã 6 số đến {email}...\nBảng nhập mã đã mở sẵn, bạn chỉ cần chờ email tới.',
    'auth_reset_code_sent':
        'Mã 6 số đã được gửi đến {email}. Nhập mã và mật khẩu mới để đổi ngay.',
    'auth_password_reset_success_login':
        'Mật khẩu đã được đặt lại thành công! Đang vào nhà...',
    'auth_recovery_email_prompt':
        'Gợi ý Email: {email}\nVui lòng nhập đầy đủ Email để nhận mã khôi phục:\n(Hoặc nhập Mã bảo mật/PIN nếu bạn không nhớ tên Email, hệ thống sẽ gửi mã khôi phục mà không hiện toàn bộ email)',
    'auth_provider_in_development':
        'Tính năng đăng nhập bằng {provider} đang được phát triển.',
    'auth_login_unavailable':
        'Không thể đăng nhập lúc này. Vui lòng thử lại sau.',
    'auth_signup_unavailable':
        'Không thể tạo tài khoản lúc này. Vui lòng thử lại sau.',
    'diary_memory_vault_full':
        'Kho kỷ niệm đã đầy ({current}/{limit} ảnh). Vui lòng xóa bớt ảnh cũ để đăng thêm!',
    'diary_partner_new_diary':
        '{author} vừa viết một tâm sự mới vào nhật ký chung. Vào đọc ngay nhé!',
    'diary_partner_new_memory':
        '{author} vừa thêm {count} ảnh kỷ niệm vào nhật ký chung. Vào xem ngay nhé!',
    'diary_added_memories_partial':
        'Đã thêm {uploaded}/{total} kỷ niệm. {failed} ảnh chưa tải được.',
    'diary_album_saved_photo_count':
        'Có {count} ảnh đang được lưu trong album này.',
    'diary_upload_permission_ios_desc':
        'SoulLocket cần quyền thêm ảnh vào thư viện để bạn có thể tải ảnh kỷ niệm về máy.',
    'diary_upload_permission_android_desc':
        'SoulLocket cần quyền truy cập bộ nhớ để tải ảnh kỷ niệm về thiết bị của bạn.',
    'diary_post_timeout':
        'Đăng bài quá thời gian. Vui lòng kiểm tra kết nối và thử lại.',
    'diary_write_permission_denied':
        'Không có quyền ghi dữ liệu. Vui lòng kiểm tra kết nối mạng hoặc thử lại sau.',

    'love_insight_suggest_single_slow_rhythm':
        'Nhịp lưu giữ của bạn đang chậm lại vài ngày gần đây. Chỉ cần viết vài dòng ngắn hoặc lưu một khoảnh khắc nhỏ hôm nay là chỉ số sẽ ấm lên rõ rệt.',
    'love_insight_suggest_single_need_self_care':
        'Dạo này bạn đang hơi thiếu nhịp chăm sóc bản thân. Mỗi tối viết vài dòng và lưu một điều vui trong ngày sẽ giúp tinh thần ấm lại rõ rệt.',
    'love_insight_suggest_couple_sparse_shared_marks':
        'Dấu ấn chung của hai bạn đang hơi thưa ở những ngày gần đây. Chỉ cần một cuộc trò chuyện thật lòng hoặc một kỷ niệm nhỏ hôm nay là nhịp yêu sẽ sáng lại nhanh.',
    'love_insight_suggest_couple_cool_connection':
        'Nhịp kết nối của hai bạn đang hơi nguội so với trước. Dành riêng vài phút mỗi ngày để hỏi han thật lòng sẽ giúp cảm xúc quay lại nhanh hơn.',
    'settings_privacy_center_desc':
        'Gom nhanh bảo mật, thiết bị đăng nhập và dữ liệu cá nhân ở một nơi.',
    'smart_reminders_anniversary_desc':
        'Nhắc trước và trong ngày đặc biệt của hai bạn.',
    'smart_reminders_love_note_desc':
        'Tự động gửi lời chúc sáng/tối ngọt ngào cho đối phương khi bạn mở app.',
    'smart_reminders_sleep_desc':
        'Nhắc nhở người thương đi ngủ đúng giờ vào mỗi tối.',
    'partner_location_not_enabled_map':
        '{partnerName} chưa bật vị trí nên bản đồ chưa thể đo khoảng cách của hai bạn.',
    'partner_gps_not_enabled_map':
        '{partnerName} chưa bật GPS. Chờ người ấy bật để xem khoảng cách.',
    'you_location_not_enabled_map':
        'Bạn chưa bật vị trí nên bản đồ chưa đủ dữ liệu để đo khoảng cách với {partnerName}.',
    'home_location_not_enabled_action':
        'Bạn chưa bật vị trí. Mở bản đồ và bấm {button} để chia sẻ.',
    'settings_need_house_to_manage_devices':
        'Bạn cần vào Nhà chung để quản lý thiết bị.',
    'settings_performance_mode_desc_smooth':
        'Đang ưu tiên mượt và tiết kiệm pin.',
    'settings_data_system_desc':
        'Quản lý thông báo, liên kết dữ liệu và các tích hợp hệ thống.',
    'settings_restore_message':
        'App sẽ khôi phục cài đặt đã đồng bộ từ cloud về máy này. Một số giao diện/cài đặt hiện tại trên máy có thể được thay bằng bản cloud.',
    'settings_restore_groups_desc':
        'App chỉ hiển thị trạng thái từng nhóm, không tự ghi đè dữ liệu cá nhân khi chưa xác nhận.',
    'settings_group_config_desc':
        'Có thể khôi phục theme, hiệu ứng, thông báo, widget và các lựa chọn giao diện đã đồng bộ.',
    'settings_group_house_desc':
        'Dùng house/couple hiện tại để đối chiếu dữ liệu chung. Không tạo house mới trong bước này.',
    'settings_group_diary_desc':
        'Cần bước đối chiếu riêng để tránh ghi đè nhật ký đang có trên máy.',
    'settings_group_media_desc':
        'Media cần kiểm tra link, quyền truy cập và cache trước khi khôi phục hàng loạt.',
    'settings_group_utilities_desc':
        'Sẽ tách thành từng nhóm nhỏ để người dùng chọn khôi phục khi mở rộng.',

    // === Notifications ===
    'milestone_empty_upcoming':
        'Không có sự kiện sắp tới nào.\nHãy lên kế hoạch hẹn hò mới nhé! ✨',
    'sec_screen_recording_subtitle':
        'Để bảo vệ quyền riêng tư, hoạt động ghi hoặc chụp màn hình đã bị hạn chế.',
    'sec_screen_recording_step1':
        'Bước 1: Tắt các ứng dụng quay màn hình đang chạy ngầm.',
    'sec_screen_recording_step2':
        'Bước 2: Dừng cuộc gọi video hoặc chia sẻ màn hình nếu có.',
    'sec_screen_recording_step3':
        'Bước 3: Khởi động lại ứng dụng nếu lỗi vẫn tiếp diễn.',
    'sec_faq_record_a':
        'Ứng dụng chứa các thông tin bảo mật, hình ảnh và nhật ký riêng tư của bạn. Việc chặn ghi màn hình giúp ngăn chặn các mã độc tự động đánh cắp dữ liệu.',
    'sec_faq_block_all_a':
        'Đây là tính năng bảo vệ bắt buộc để bảo vệ sự riêng tư và an toàn thông tin của bạn.',
    'sec_overlay_subtitle':
        'Một ứng dụng khác đang vẽ đè lên màn hình của bạn. Đây có thể là ứng dụng độc hại cố gắng đánh cắp thông tin.',
    'sec_overlay_step1':
        "Bước 1: Tắt quyền 'Hiển thị trên các ứng dụng khác' của các app lạ.",
    'sec_overlay_step2':
        'Bước 2: Đóng các bong bóng chat hoặc bộ lọc ánh sáng xanh.',
    'sec_faq_overlay_a':
        'Lớp phủ là giao diện do ứng dụng khác hiển thị đè lên màn hình (như bong bóng Messenger, app lọc màn hình). Kẻ xấu có thể lợi dụng để đánh lừa bạn chạm vào nút bấm ẩn.',
    'sec_faq_overlay_false_alarm_q':
        'Tại sao tôi bị cảnh báo dù không dùng app độc hại?',
    'sec_faq_overlay_false_alarm_a':
        'Một số ứng dụng an toàn như bộ lọc màn hình ban đêm cũng tạo ra lớp phủ. Bạn chỉ cần tạm thời tắt chúng khi sử dụng app.',
    'sec_unofficial_subtitle':
        'Bạn đang sử dụng phiên bản ứng dụng không chính thức hoặc đã bị sửa đổi. Phiên bản này không an toàn để sử dụng.',
    'sec_unofficial_step2':
        'Bước 2: Tải và cài đặt lại ứng dụng chính thức từ CH Play hoặc App Store.',
    'sec_faq_unofficial_a':
        'Có, các phiên bản đã qua chỉnh sửa có thể chứa mã độc đánh cắp tin nhắn, ảnh và mật khẩu của bạn.',
    'sec_unofficial_support_draft':
        'Yêu cầu hỗ trợ về lỗi phiên bản không chính thức.',
    'sec_malware_subtitle':
        'Thiết bị của bạn đang chạy một hoặc nhiều phần mềm có dấu hiệu độc hại nguy hiểm.',
    'sec_faq_malware_a':
        'Play Protect trong ứng dụng CH Play sẽ quét và thông báo cụ thể danh sách phần mềm độc hại trên máy của bạn.',
    'sec_faq_malware_support_a':
        'Vào Cài đặt của máy -> Ứng dụng -> Chọn ứng dụng nghi ngờ và nhấn Gỡ cài đặt.',
    'sec_root_subtitle':
        'Thiết bị của bạn đã bị Root hoặc Jailbreak. Hệ thống bảo mật đã bị bẻ khóa, không an toàn để chạy ứng dụng này.',
    'sec_faq_root_a':
        'Root làm mất đi lớp bảo vệ bảo mật của hệ điều hành, cho phép bất kỳ ứng dụng nào cũng có thể đọc trộm dữ liệu nhạy cảm.',
    'sec_faq_root_support_a':
        'Không, để đảm bảo an toàn tuyệt đối cho nhật ký của bạn, ứng dụng từ chối hoạt động trên mọi thiết bị thiếu tính toàn vẹn.',
    'home_activity_restored': 'Đã khôi phục {label}',
    'home_send_otp_failed': 'Gửi mã OTP thất bại: {error}',
    'home_otp_invalid_or_expired': 'Mã OTP không hợp lệ hoặc đã hết hạn: {error}',
    'home_otp_sent_to_email': 'Mã OTP đã được gửi đến {email}',
    'home_sending_reset_password_email': 'Đang gửi email đặt lại mật khẩu đến {email}...',
    'home_reset_password_failed': 'Đặt lại mật khẩu thất bại: {error}',
    'home_reset_otp_sent': 'Mã xác thực đặt lại mật khẩu đã được gửi đến {email}',
    'home_days_count': '{days} ngày',
    'home_autoclose_countdown': 'Ứng dụng sẽ tự động đóng sau {seconds} giây do không có hoạt động.',
    'home_tieptuc_inactivity': 'Tiếp tục ({seconds}s)',
    'home_thoat_inactivity': 'Thoát',
    'home_memory_remaining_upload': 'Đang chờ tải lên {count} kỷ niệm còn lại',
    'home_sending_otp_email': 'Đang gửi mã OTP đến {email}...',
    'auth_recovery_reset_device_hint': '\n\n[Thiết bị quen] Nếu bạn quên cả mã PIN, nhập "RESET" để yêu cầu đổi mới (xử lý sau 3 ngày).',
  };

  static const Map<String, String> _en = {
    'home_current_name_prefix': 'Current name',
    'settings_role_swap_prefix': 'Successfully swapped role to',
    'Gửi thông báo thử đến điện thoại người ấy để kiểm tra xem thông báo có hiện ra ngoài màn hình không.': 'Send a test notification to partner\'s phone to check if it appears on screen.',
    'Đây là thông báo thử nghiệm loại Chat. Nếu bạn thấy tin này nghĩa là thông báo đang hoạt động! 🎉': 'This is a test Chat notification. If you see this, notifications are working! 🎉',
    'Nếu bạn thấy tin này ngoài màn hình chính nghĩa là thông báo đang hoạt động bình thường! ✅': 'If you see this on your home screen, notifications are working properly! ✅',
    'Tiện ích màn hình chỉ hỗ trợ trên thiết bị thật. Phần cấu hình này nên thao tác trên app cài đặt.': 'Home widgets are only supported on physical devices.',
    'Màu sắc và chủ đề của Tiện ích được lấy trực tiếp từ sự kiện bạn chọn ghim hoặc sự kiện gần nhất trong danh sách Sự Kiện & Kỷ Niệm.': 'Widget colors and theme are synced directly from your pinned event or upcoming anniversary.',
    'Hiển thị sự kiện tiếp theo (ví dụ: ngày sinh nhật, chuyến đi, ngày kỷ niệm yêu...) trực tiếp trên màn hình chính.': 'Show next event (birthday, trip, love anniversary...) directly on home screen.',

    // === Quick Customize & Missing Keys ===

    // === Auth ===
    'auth_security_note':
        'Note: You can add this in Settings after creating a house. It is needed for account recovery.',
    'auth_social_register_notice':
        'Registering means you confirm you are 13+\nand agree to our Terms.',
    'auth_social_login_notice':
        'By continuing with Google or Apple, you confirm\nyou are 13+ and agree to our Terms.',

    // === Settings UI ===
    'name_change_notice':
        'Note: House name and Usernames can only be changed after 7 days from the last update.',
    'settings_private_subtitle':
        'Use your Google account or Email for secure sign-in.',
    'settings_secondary_email_enter_before_save':
        'Please enter a secondary email before saving',
    'settings_secondary_email_same_as_primary':
        'The secondary email must be different from the primary email',
    'settings_secondary_email_sending_code':
        'Sending a verification code to the secondary email...',
    'settings_secondary_email_code_message':
        'Your verification code is: {code}',
    'settings_secondary_email_code_sent':
        'The code was sent by email. Please check your inbox.',
    'settings_secondary_email_verify_prompt':
        'Please enter the 6-digit code sent to {email}:',
    'settings_secondary_email_code_incorrect':
        'The verification code is incorrect!',
    'settings_secondary_email_saved_success':
        'The secondary email has been verified and saved successfully!',
    'settings_secondary_email_send_code_failed':
        'Unable to send the verification code. Please try again later.',
    'settings_secondary_email_send_network_error':
        'Network error while sending the email: {error}',
    'settings_google_already_linked':
        'This account is already linked to Google.',
    'settings_email_not_found_change':
        'Could not find the primary email to change',
    'settings_supported_emails_only':
        'Only the following email domains are supported: {domains}',
    'settings_email_change_sent':
        'A confirmation link to change your email was sent to {email}. Please tap the link and then sign in again.',
    'settings_email_requires_recent_login':
        'Your session is too old. Please sign out and sign in again before changing your email.',
    'settings_email_daily_limit':
        'You have sent more than 5 verification emails today. Please try again tomorrow.',
    'settings_email_wait_before_resend':
        'Please wait {wait} before sending again.',
    'settings_email_pending_latest':
        'The latest verification email is still valid. Please open the newest email and tap "I already tapped the link".',
    'settings_email_verification_sent':
        'A verification email was sent to {email}. Please open the newest email and avoid using older emails so the code does not expire.',
    'settings_email_send_failed_with_error':
        'Unable to send the verification email: {error}',
    'settings_email_verified_success':
        'The email has been verified successfully.',
    'settings_email_not_verified_yet':
        'The email is not verified yet. Please open the newest email and tap the verification link.',
    'settings_email_check_failed':
        'Unable to check the email verification status.',
    'settings_email_check_failed_with_error':
        'Unable to check the email verification status: {error}',
    'settings_email_inbox_open_failed':
        'Unable to open the mailbox on this device.',

    // === Tabs ===

    // === Finance ===

    // === Diary ===

    // === Secret Vault ===

    // === Time Capsule ===

    // === Export ===

    // === Media Cleanup ===

    // === Reward Store ===

    // === Community ===
    'write_post': "What's on your mind?",
    'community_compose_choose_desc':
        'Each share type opens its own composer so it no longer feels like posting a Facebook-style status.',
    'community_compose_prepublish_note':
        'In the next step you can still change the photo, location, mood, and privacy before posting.',
    'community_compose_location_hint':
        'Example: Hanoi, favorite cafe, Da Lat...',
    'community_compose_content_note':
        'Up to {count} characters. The system still filters spam and unsafe content before posting.',
    'community_compose_mode_confession_desc':
        'Say what is on your mind in a softer, more personal format.',
    'community_compose_hint_confession':
        'What would you like to open up about with the community today?',
    'community_compose_empty_message_confession':
        'Write a few lines before posting your thoughts.',
    'community_compose_mode_photo_desc':
        'Lead with a moment first, then add the feeling and story around it.',
    'community_compose_hint_photo':
        'Add a short caption to tell the feeling behind this photo...',
    'community_compose_empty_message_photo':
        'This share type needs at least one photo before posting.',
    'community_compose_seed_photo': "Today's moment for me is...",
    'community_compose_mode_advice_desc':
        'Describe the situation clearly so the community can give focused suggestions.',
    'community_compose_hint_advice':
        'What would you like the community to help with?',
    'community_compose_empty_message_advice':
        'Describe what you need advice on before sending.',
    'community_compose_mode_signal_desc':
        'Keep your identity hidden and send something more discreet.',
    'community_compose_hint_signal':
        'What signal do you want to send without revealing yourself yet?',
    'community_compose_empty_message_signal':
        'Write something before sending an anonymous signal.',
    'community_post_type_mood_desc':
        'A feeling-first share focused on your story and mood.',
    'community_post_type_mood_hint':
        'What do you want to share with the community?',
    'community_post_type_photo_desc':
        'A photo-led post with a short caption and visual focus.',
    'community_post_type_photo_hint':
        'Add a short caption for the photo you want to share...',
    'community_post_type_question_desc':
        'Best for posts that need suggestions, advice, or another point of view.',
    'community_post_type_question_hint':
        'Ask a question or request advice from the community...',
    'community_post_type_confession_desc':
        'A more private sharing style that can automatically hide your name.',
    'community_post_type_confession_hint':
        'Write what you want to say without revealing your identity...',

    // === Chat ===

    // === Map ===
    'partner_location': "Partner's location",

    // === Game ===

    // === Tarot ===
    'tarot_header_desc':
        'This tarot flow reads the viewer, recent connection rhythm, zodiac chemistry, and layered emotions instead of generic card meanings only.',
    'tarot_profile_loading':
        'Loading viewer profile to make the reading more precise...',
    'tarot_empty_title':
        'Pick a spread and draw cards to open your emotional map',
    'tarot_empty_desc':
        'Each spread reads a different layer: current pulse, emotional mirror, relationship map, or the next chapter.',
    'tarot_reading_loading':
        'Tarot is blending age, zodiac, connection rhythm, and the selected cards into a deeper reading.',
    'tarot_analysis_failed':
        'Deep analysis is not available right now. Tarot will still show the core meaning of each card.',
    'tarot_spread_pulse_desc':
        'Reads what is rising now, what is hidden, and the nearest heart-opening path.',
    'tarot_spread_mirror_desc':
        'Reflects you, the other side, the friction point, and the healing bridge.',
    'tarot_spread_map_desc':
        'Goes deep into emotional roots, true needs, love style, present blocks, and the next 7 days.',
    'tarot_spread_next_desc':
        'Reads what to release, what to invite in, timing, and the sign that is approaching.',

    // === Love Tree / Garden ===

    // === Feedback ===

    // === Admin ===

    'Bạn cần đồng ý với Điều khoản và Chính sách bảo mật để đăng ký.':
        'You need to agree to the Terms and Privacy Policy to register.',
    'Dữ liệu được đồng bộ theo thời gian thực để hai thiết bị luôn thấy cùng một trạng thái.':
        'Data is synchronized in real time so both devices always see the same state.',
    'Chia sẻ ảnh, video, status. Có thể chọn "Công khai" hoặc "Chỉ mình tôi".':
        'Share photos, videos, status. Can choose "Public" or "Only me".',
    'Bấm vào ảnh trên Feed để xem chế độ lướt dọc toàn màn hình, thả tim và bình luận mượt hơn.':
        'Tap on photo in Feed to view in full screen vertical mode, drop hearts and comment smoothly.',
    'Thiết bị khác đã xác nhận danh tính của bạn. Vui lòng nhập mật khẩu nhà để vào cửa!':
        'Another device has verified your identity. Please enter the house password to enter!',
    'Mẹo: Hãy thêm SoulLocket vào màn hình chính để dùng nhanh như một ứng dụng thực thụ, và nếu cần hỗ trợ thêm bạn có thể bấm mục Liên hệ ngay tại trang này.':
        'Tip: Add SoulLocket to the home screen for quick access like a native app, and if you need further support, you can click Contact right on this page.',
    'Chạm vào tim để tạo hiệu ứng. Bấm vào Avatar để thay đổi ảnh.':
        'Tap the heart to create effects. Tap Avatar to change photo.',
    'Bạn đang chạy app trong chế độ Debug mà chưa cấu hình dịch vụ mạng. Vui lòng tạo file env.local.json theo hướng dẫn để sử dụng tính năng Đăng nhập.':
        'You are running the app in Debug mode without Firebase configured. Please create env.local.json following the guide to use Login feature.',
    'Đã gửi email khôi phục mật khẩu. Vui lòng kiểm tra hộp thư.':
        'Password recovery email sent. Please check your inbox.',
    'Nhận thông báo nhắc nhở khi người ấy nhớ bạn, nhắc uống nước hoặc giữ ấm.':
        'Receive reminder notifications when your partner misses you, reminds to drink water or stay warm.',
    '\n\n[Thiết bị quen] Nếu bạn quên cả mã PIN, nhập "RESET" để yêu cầu đổi mới (xử lý sau 3 ngày).':
        '\n\n[Familiar Device] If you forget your PIN, type "RESET" to request a new one (processed after 3 days).',
    'Bấm nút "Lật giao diện" trong Cài đặt để xem góc nhìn của người kia.':
        'Click "Flip UI" in Settings to see your partner\'s perspective.',
    'Hệ thống sẽ đề xuất các chủ đề và lịch hẹn theo mức độ tương tác thực tế.':
        'System will suggest topics and dates based on actual interaction level.',
    'Không tìm thấy mã nhà hoặc không có kết nối.':
        'House code not found or no connection.',
    'Tên giáo viên chủ nhiệm lớp 1?':
        'Name of your 1st grade homeroom teacher?',
    'Câu hỏi bảo mật (Tuỳ chọn)  (ấn vào)':
        'Security Question (Optional) (tap)',
    'Điểm danh, đăng bài hoặc hoàn thành hoạt động để tích điểm sử dụng trong app.':
        'Check in, post or complete activities to earn points used in the app.',
    'Email hoặc Mã bảo mật không chính xác.':
        'Email or Security Code is incorrect.',
    'Nơi cất ảnh riêng tư hoặc nhạy cảm. Cần mật khẩu riêng để mở.':
        'Place to keep private or sensitive photos. Requires a separate password to open.',
    'Lựa chọn này chỉ dùng để xác định luồng tài khoản khi tạo nhà lần đầu.\nSau khi tạo nhà xong, chế độ sẽ cố định và không thể đổi lại trong Cài đặt.':
        'This choice is only used to determine the account flow when first creating the house.\nAfter creating the house, the mode will be fixed and cannot be changed in Settings.',
    'Câu hỏi bảo mật giúp bạn lấy lại Gmail.':
        'Security question helps you recover Gmail.',
    'Bạn nhập sai quá nhiều lần. Vui lòng chờ ít phút rồi thử lại.':
        'You entered incorrectly too many times. Please wait a few minutes and try again.',
    'Vui lòng mô tả vấn đề bạn đang gặp phải, chúng mình sẽ hỗ trợ sớm nhất có thể.':
        'Please describe the problem you are facing, we will support as soon as possible.',
    'Tick chọn "Đăng ẩn danh" khi viết bài để giấu tên, hiển thị là "Người lạ".':
        'Check "Post anonymously" when writing to hide name, displayed as "Stranger".',
    'Không gian riêng tư cho hành trình yêu đương hoặc sống độc thân chất lượng.':
        'Private space for your love journey or quality single life.',
    'Mật khẩu chính là mã PIN khóa nhà bạn đặt.':
        'The password is the PIN you set to lock the house.',
    'Đây là lớp mật khẩu ngoài cùng để vào ứng dụng và bảo vệ không gian riêng tư của bạn.':
        'This is the outermost password to enter the app and protect your private space.',
    'Lên lịch hẹn hò, nhắc việc và đếm ngược đến các sự kiện quan trọng.':
        'Schedule dates, reminders and countdown to important events.',
    'Xem vị trí trực tiếp và lịch sử di chuyển của nhau trên bản đồ khi tính năng được bật.':
        'View live location and movement history of each other on the map when the feature is enabled.',
    '4. Điểm, Cửa Hàng & Tính Năng Nâng Cao':
        '4. Points, Store & Advanced Features',
    'YÊU CẦU ĐỔI MỚI: Đã ghi nhận yêu cầu. Vì lý do bảo mật, yêu cầu này sẽ được xử lý sau 3 ngày làm việc đối với thiết bị này.':
        'NEW REQUEST: Request recorded. For security reasons, this request will be processed after 3 working days for this device.',
    'Đăng nhập thành công! Chào mừng bạn về nhà.':
        'Login successful! Welcome home.',
    'Dùng máy đã đăng nhập quét mã trên máy mới để vào nhanh mà không cần nhập lại nhiều bước.':
        'Use logged-in device to scan code on new device for quick access without re-entering steps.',
    'Tối ưu giao diện theo trạng thái bạn chọn khi vào app lần đầu.':
        'Optimize UI according to the status you choose when entering the app for the first time.',
    'Đã gửi yêu cầu hỗ trợ thành công. Chúng mình sẽ liên hệ lại qua email!':
        'Support request sent successfully. We will contact you back via email!',
    'Thả tim, bình luận và chia sẻ bài viết của các cặp đôi khác.':
        'Drop hearts, comment and share posts of other couples.',
    'Mật khẩu yếu: Cần ít nhất 6 ký tự và 1 số!':
        'Weak password: Needs at least 6 characters and 1 number!',
    'Bao gồm thời tiết, ghi chú chung, máy tính tình yêu, chỉ số BMI và các tiện ích nhỏ khác.':
        'Includes weather, shared notes, love calculator, BMI and other small utilities.',
    'Cho phép kiểm soát sâu hơn ai được xem bài viết, hồ sơ hoặc nội dung theo nhóm.':
        'Allows deeper control over who can view posts, profiles or content by group.',
    'Tài khoản sẽ đi theo luồng trải nghiệm một mình ✨':
        'Account will follow the solo experience flow ✨',
    'Tạo tài khoản thành công! Tiếp theo là thiết lập ngôi nhà.':
        'Account created successfully! Next is to set up the house.',
    'Chọn một lần để app xác định luồng tài khoản\nphù hợp nhất với bạn nhé!':
        'Choose once for the app to determine the most suitable\naccount flow for you!',
    'Có các hoạt động như vòng quay may mắn và nhiều mini game gắn kết.':
        'There are activities like lucky wheel and many bonding mini games.',
    'Vui lòng nhập kết quả để chứng minh bạn không phải robot:':
        'Please enter the result to prove you are not a robot:',
    'Vui lòng nhập đầy đủ Email và Mật khẩu.':
        'Please enter both Email and Password.',
    'Lưu ý: Có thể thêm trong Cài đặt sau khi tạo nhà. Cần thiết khi khôi phục tài khoản.':
        'Note: Can be added in Settings after creating house. Necessary for account recovery.',
    'Dùng đúng Gmail để khôi phục khi quên.':
        'Use correct Gmail to recover when forgotten.',
    'Thiết bị khác đã xác nhận danh tính của bạn. Vui lòng nhập email đã liên kết với ngôi nhà và mật khẩu nhà để vào cửa!':
        'Another device has verified your identity. Please enter the email linked to the house and the house password to enter!',
    'Mật khẩu không chính xác. Vui lòng kiểm tra lại.':
        'Incorrect password. Please check again.',
    'Bấm biểu tượng đĩa nhạc ở góc phải để bật hoặc tắt nhạc lãng mạn.':
        'Tap the music disc icon in the right corner to turn on or off romantic music.',
    'Nếu cần giúp đỡ thêm, vui lòng bấm Liên hệ.':
        'If you need further help, please click Contact.',
    'Nơi ghi lại tâm tư thầm kín, chỉ hai người trong nhà mới xem được.':
        'Place to record secret thoughts, only the two of you in the house can see.',
    'Tài khoản sẽ đi theo luồng couple sau khi tạo nhà ♥':
        'Account will follow the couple flow after creating house ♥',
    'Trong Cài đặt > Bảo mật, bạn có thể đặt thêm mật khẩu lớp trong cùng để tự động khóa lại sau thời gian không dùng.':
        'In Settings > Security, you can set an innermost password layer to automatically lock after a period of inactivity.',
    'Nhà này chưa cài đặt câu hỏi bảo mật để khôi phục.':
        'This house has not set up a security question for recovery.',
    'Dùng điểm đổi quà như voucher, hẹn hò hoặc phần thưởng do chính hai bạn tạo ra.':
        'Use points to redeem gifts like vouchers, dates or rewards created by yourselves.',
    'Quy trình ghép đôi mới giúp kết nối nhanh hơn và giảm nhầm lẫn vai trò khi bắt đầu.':
        'New pairing process helps connect faster and reduces role confusion when starting.',
    'Hiển thị số ngày bên nhau. Bấm vào số ngày để xem chi tiết các mốc kỷ niệm.':
        'Display days together. Tap on the number of days to view details of milestones.',

    'Nơi lưu giữ những khoảnh khắc hạnh phúc của hai bạn.':
        'A place to keep your happy moments together.',
    'Chưa có bài đăng ảnh\nHãy là người đầu tiên!':
        'No photo posts yet\nBe the first!',
    'Viết dòng cảm xúc đầu tiên của bạn ở khung phía trên nhé.':
        'Write your first feeling in the box above.',
    'Hôm nay mình muốn lưu lại một kỷ niệm nhỏ...':
        'Today I want to save a small memory...',
    'Điều mình thấy biết ơn nhất hôm nay là...':
        'The thing I am most grateful for today is...',
    'Hôm nay bạn cảm thấy thế nào? Kể nghe đi...':
        'How are you feeling today? Tell me...',
    'Phiên đăng nhập chưa sẵn sàng. Vui lòng thử lại.':
        'Login session not ready. Please try again.',
    'Chưa tìm thấy mã nhà để lưu bài viết.':
        'House code not found to save post.',
    'Bạn có chắc muốn chuyển ảnh này vào thùng rác?':
        'Are you sure you want to move this photo to trash?',
    'Vui lòng mở khóa để xem tâm sự của hai bạn.':
        'Please unlock to view your diaries.',
    'Bắt đầu lưu giữ khoảnh khắc đầu tiên của hai bạn.':
        'Start keeping your first moments together.',
    'Vui lòng chọn ảnh trước khi đăng bài!':
        'Please select a photo before posting!',
    'countdown_unlock_ad':
        'Ad styles need only one rewarded ad to unlock the whole group for 7 days.',
    'countdown_unlock_pro':
        'Pro accounts can use every countdown style without ads.',
    'theme_lite_mode_desc':
        'Disable effects to reduce lag and speed up startup.',
    'theme_graphics_desc':
        'Automatically optimize based on device performance.',
    'theme_permission_desc':
        'Click below to grant GPS, Camera, Mic, and Notification access.',
    'theme_err_need_house_for_bg':
        'Please enter a house before uploading background.',
    'theme_err_ad_for_bg':
        'You must watch an ad completely to upload background.',
    'theme_err_invalid_music_link':
        'Only valid local audio files on this device are supported (MP3, M4A, WAV, OGG, AAC, FLAC).',
    'theme_music_guide_desc':
        'Use only local audio files on this device. Music will not sync automatically to other devices.',
    'theme_preview_desc':
        'Frame • background • effect • font will update based on your selection.',
    'theme_event_empty_house':
        'New memories will appear here after you create a house.',
    'theme_event_delete_message':
        'The memory "{name}" will be removed from the reminder list.',
    'theme_event_description_hint':
        'Separated below: Pink blocks are anniversaries added here, Blue blocks are shared plans from Calendar.',
    'theme_event_anniversary_section_desc':
        'Custom dates added in the anniversary section',
    'theme_event_calendar_section_desc':
        'Plans fetched from the shared Calendar tab',
    'theme_bg_effect_desc':
        'Falling effects, color theme and custom background',
    'theme_bg_in_use':
        'You are using a custom uploaded background, cannot use system backgrounds',
    'theme_applied_msg':
        'Custom background was disabled to apply the new theme.',
    'widget_ios_guide':
        'To add a Widget on iOS:\n1. Long press on the home screen\n2. Tap the [+] button in the corner\n3. Search "SoulLocket" and add the widget',
    'account_err_email_domain':
        'Only the following email types are supported: {domains}',
    'military_mode_desc':
        'Note: Military Mode will completely hide the App Switcher to prevent peeking. The screen will turn black when you swipe out.',
    'backup_pin_desc':
        'Use backup PIN to recover and confirm some security actions.',
    'vault_timeout_desc':
        'Time before requiring password again when not using vault.',
    'err_house_pwd_format':
        'Password must be at least 4 characters and contain a number',
    'widget_animated_heart_desc':
        'Enable for beating heart, disable for static',
    'widget_home_desc':
        'Widget will be added to your home screen for quick viewing.',
    'ios_widget_pending':
        'Widget Extension not yet enabled on iOS (pending Mac).',
    'restore_vip_desc':
        'Restoring purchases is useful when you change devices or reinstall the app.',
    'settings_account_desc':
        'Manage your profile, sign-in email, language, PRO plan, and the most important account details.',
    'settings_security_desc':
        'Turn on app lock, verify email, link Google, manage recovery PIN, and review signed-in devices.',
    'settings_theme_desc':
        'Customize themes, fonts, wallpapers, background music, falling effects, graphics, and AI personalization tools.',
    'settings_widget_desc_web':
        'Preview the full widget layout, couple photos, colors, and sync it to continue later on your phone.',
    'settings_widget_desc_mobile':
        'Build a home-screen widget with love-day counter, memory photos, heart style, colors, layout, and quick pin actions.',
    'settings_countdown_space_desc':
        'Open a separate day-counter screen that keeps only the countdown block and stays detached from the home layout.',
    'settings_notifications_desc':
        'Control anniversary reminders, important nudges, notification permission, and the daily alerts that matter most.',
    'settings_support_legal_desc':
        'Open user guides, support center, legal policies, terms, and important account-related request flows.',
    'settings_sign_in_required_to_restore':
        'Sign in required to restore settings.',
    'settings_cloud_backup_not_found_to_restore':
        'Cloud backup not found to restore.',
    'settings_restore_from_cloud_failed':
        'Failed to restore settings from cloud.',
    'countdown_mode_no_date_desc':
        'No anchor date is available yet. Set a start date in your shared home information first.',
    'upload_background_interrupted':
        'Previous wallpaper upload was interrupted',
    'settings_locked_desc':
        'You have locked the security zone. Please authenticate to access Settings.',
    'Để ứng dụng hiển thị đúng giao diện\nmà không cần lật lại sau nhé!':
        'So the app shows the right layout\nwithout needing to flip it later!',
    'Bạn có chắc muốn xóa những ảnh đã chọn?':
        'Are you sure you want to delete the selected photos?',
    'Bạn có chắc muốn xóa tâm sự này không?':
        'Are you sure you want to delete this diary?',
    'Chưa có quyền lưu ảnh vào album.':
        'No permission to save photos to the album.',
    'Một góc riêng để giữ lại những khoảnh khắc đáng nhớ.':
        'A special place to keep your memorable moments.',
    'Không thể kết nối mạng. Vui lòng kiểm tra Wi‑Fi hoặc dữ liệu di động rồi thử lại.':
        'Cannot connect to the internet. Please check Wi-Fi or mobile data and try again.',
    'Máy chủ đang bận hoặc gặp sự cố. Vui lòng thử lại sau.':
        'The server is busy or having an issue. Please try again later.',
    'Kết nối mạng quá chậm hoặc đã hết thời gian chờ. Vui lòng kiểm tra mạng rồi thử lại.':
        'The network is too slow or timed out. Please check your connection and try again.',
    'Kết nối mạng quá chậm hoặc bị gián đoạn. Vui lòng kiểm tra mạng rồi thử lại.':
        'The network is too slow or was interrupted. Please check your connection and try again.',
    'Bạn đã thử quá nhiều lần. Vui lòng chờ một lúc rồi thử lại.':
        'You have tried too many times. Please wait a moment and try again.',
    'Tài khoản không tồn tại. Vui lòng kiểm tra lại email hoặc tạo tài khoản mới.':
        'Account does not exist. Please check the email again or create a new account.',
    'Tài khoản chưa được đăng ký hoặc mật khẩu không chính xác. Nếu chưa có tài khoản, vui lòng chuyển qua tab Đăng Ký.':
        'The account is not registered or the password is incorrect. If you do not have an account yet, switch to the Sign Up tab.',
    'Mật khẩu quá yếu. Vui lòng nhập ít nhất 6 ký tự.':
        'Password is too weak. Please enter at least 6 characters.',
    'Trình duyệt đang chặn cửa sổ đăng nhập. Vui lòng cho phép popup rồi thử lại.':
        'The browser is blocking the login window. Please allow popups and try again.',
    'Máy chủ xác thực đang bận hoặc gặp sự cố. Vui lòng thử lại sau.':
        'The authentication server is busy or having an issue. Please try again later.',
    'Thông tin bạn nhập chưa hợp lệ. Vui lòng kiểm tra lại.':
        'The information you entered is invalid. Please check again.',
    'Dịch vụ đăng nhập đang gặp sự cố hệ thống. Vui lòng thử lại sau.':
        'The login service is having a system issue. Please try again later.',
    'auth_rate_limit_wait':
        'You are acting too quickly. Please wait {seconds} seconds and try again.',
    'auth_supported_domains_only':
        'The system only supports {action} using: {domains}!',
    'auth_reset_sending_code':
        'Sending a 6-digit code to {email}...\nThe code form is already open, you just need to wait for the email.',
    'auth_reset_checking_code':
        'Checking the code and changing the password...',
    'auth_reset_code_sent':
        'A 6-digit code has been sent to {email}. Enter the code and your new password to change it now.',
    'auth_password_reset_success_login':
        'Password reset successfully! Entering the house...',
    'auth_recovery_email_prompt':
        'Email hint: {email}\nPlease enter the full Email to receive the recovery code:\n(Or enter your Security Code/PIN if you do not remember the Email name; the system will send the recovery code without showing the full email)',
    'auth_provider_in_development':
        'Login with {provider} is still under development.',
    'auth_login_unavailable':
        'Cannot log in right now. Please try again later.',
    'auth_signup_unavailable':
        'Cannot create an account right now. Please try again later.',
    'diary_memory_vault_full':
        'Your memories vault is full ({current}/{limit} photos). Please delete some old photos to add more.',
    'diary_partner_new_diary':
        '{author} just wrote a new diary entry in your shared diary. Go read it now!',
    'diary_partner_new_memory':
        '{author} just added {count} memory photos to your shared diary. Go see them now!',
    'diary_added_memories_partial':
        'Added {uploaded}/{total} memories. {failed} photos could not be uploaded.',
    'diary_upload_permission_ios_desc':
        'SoulLocket needs permission to add photos to your library so you can save memory photos to your device.',
    'diary_upload_permission_android_desc':
        'SoulLocket needs storage access so you can save memory photos to your device.',
    'diary_post_timeout':
        'Posting took too long. Please check your connection and try again.',
    'diary_write_permission_denied':
        'You do not have permission to write data. Please check your network connection or try again later.',

    'love_insight_suggest_single_slow_rhythm':
        'Your journaling rhythm has slowed down over the past few days. A short note or a small moment saved today can warm the score up quickly.',
    'love_insight_suggest_single_need_self_care':
        'Lately you have been a bit out of sync with self-care. Writing a few lines each night and saving one good thing from the day can lift your spirit noticeably.',
    'love_insight_suggest_couple_sparse_shared_marks':
        'Your shared moments have been a bit sparse recently. One heartfelt talk or a small memory today can quickly bring your love rhythm back to life.',
    'love_insight_suggest_couple_cool_connection':
        'Your connection rhythm feels a bit cooler than before. Setting aside a few honest minutes each day to check in can bring the feelings back faster.',
    'settings_privacy_center_desc':
        'Quickly manage security, signed-in devices, and personal data in one place.',
    'settings_need_house_to_manage_devices':
        'You need to enter your Shared House to manage devices.',
    'settings_performance_mode_desc_smooth':
        'Prioritizing smoothness and saving battery.',
    'settings_data_system_desc':
        'Manage notifications, data links and system integrations.',
    'settings_restore_message':
        'The app will restore synced settings from the cloud to this device. Some current configurations on the device may be replaced by the cloud version.',
    'settings_restore_groups_desc':
        'The app only displays the status of each group, it will not overwrite personal data without your confirmation.',
    'settings_group_config_desc':
        'Can restore themes, effects, notifications, widgets and other synced configurations.',
    'settings_group_house_desc':
        'Uses the current house/couple profile to cross-reference data. Does not create a new house in this step.',
    'settings_group_diary_desc':
        'Requires a separate check to avoid overwriting existing diaries on this device.',
    'settings_group_media_desc':
        'Media needs to check links, access permissions, and cache before bulk restoration.',
    'settings_group_utilities_desc':
        'Will be separated into smaller groups for individual restoration choice in future updates.',

    // === Notifications ===
    'sec_screen_recording_subtitle':
        'To protect your privacy, screen recording or capturing has been restricted.',
    'sec_screen_recording_step1':
        'Step 1: Turn off screen recording apps running in the background.',
    'sec_screen_recording_step2':
        'Step 2: Stop video calls or screen sharing if active.',
    'sec_screen_recording_step3':
        'Step 3: Restart the app if the error persists.',
    'sec_faq_record_a':
        'The app contains secure, private photos and diaries. Blocking screen recording prevents malicious software from stealing your data.',
    'sec_faq_block_all_a':
        'This is a mandatory security feature to ensure your privacy and data security.',
    'sec_overlay_subtitle':
        'Another app is displaying over your screen. This could be a malicious app attempting to steal information.',
    'sec_overlay_step1':
        "Step 1: Turn off 'Display over other apps' permission for suspicious apps.",
    'sec_faq_overlay_a':
        'An overlay is an interface displayed on top of the screen by another app (like Messenger bubbles, filter apps). Attackers can abuse it to trick you into tapping hidden buttons.',
    'sec_faq_overlay_false_alarm_q':
        'Why am I warned when not using malicious apps?',
    'sec_faq_overlay_false_alarm_a':
        'Some safe apps like night screen filters also create overlays. You just need to temporarily disable them while using the app.',
    'sec_support_draft_overlay':
        'Support request regarding screen overlay error.',
    'sec_unofficial_subtitle':
        'You are using an unofficial or modified version of the app. This version is unsafe to use.',
    'sec_unofficial_step2':
        'Step 2: Download and install the official app from Google Play or App Store.',
    'sec_faq_unofficial_a':
        'Yes, modified versions can contain malware designed to steal your messages, photos, and passwords.',
    'sec_unofficial_support_draft':
        'Support request regarding unofficial version error.',
    'sec_malware_subtitle':
        'Your device is running one or more apps displaying dangerous malicious behavior.',
    'sec_faq_malware_a':
        'Play Protect inside Google Play app will scan and notify you of the specific malware on your device.',
    'sec_faq_malware_support_a':
        'Go to device Settings -> Apps -> Select suspicious app and tap Uninstall.',
    'sec_root_subtitle':
        'Your device has been Rooted or Jailbroken. The security system has been bypassed, making it unsafe to run this app.',
    'sec_root_step2':
        'Step 2: Restore your device to the stock operating system.',
    'sec_faq_root_a':
        'Rooting removes the operating system\'s built-in security layers, allowing any app to read your sensitive data.',
    'sec_faq_root_support_a':
        'No, to ensure absolute security for your diary, the app refuses to run on any device lacking integrity.',
    'home_activity_restored': 'Restored {label}',
    'home_send_otp_failed': 'Failed to send OTP: {error}',
    'home_otp_invalid_or_expired': 'OTP is invalid or has expired: {error}',
    'home_otp_sent_to_email': 'OTP has been sent to {email}',
    'home_sending_reset_password_email': 'Sending password reset email to {email}...',
    'home_reset_password_failed': 'Password reset failed: {error}',
    'home_reset_otp_sent': 'Password reset code has been sent to {email}',
    'home_days_count': '{days} days',
    'home_autoclose_countdown': 'The app will automatically close in {seconds} seconds due to inactivity.',
    'home_tieptuc_inactivity': 'Continue ({seconds}s)',
    'home_thoat_inactivity': 'Exit',
    'home_memory_remaining_upload': 'Pending upload for {count} remaining memories',
    'home_sending_otp_email': 'Sending OTP code to {email}...',
    'auth_recovery_reset_device_hint': '\n\n[Familiar Device] If you also forgot your PIN, enter "RESET" to request a new one (processed in 3 days).',
  };

  static const Map<String, String> _viWebParity = _L10nWebParityTranslations.vi;

  static const Map<String, String> _enWebParity = _L10nWebParityTranslations.en;
}
