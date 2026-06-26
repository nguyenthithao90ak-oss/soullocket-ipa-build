import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soullocket_app/core/sl_theme.dart';
import 'package:soullocket_app/utils/services/l10n_service.dart';
import 'package:soullocket_app/utils/services/pet_garden_service.dart';
import 'package:soullocket_app/models/pet_virtual.dart';
import 'package:soullocket_app/utils/sl_notice.dart';

class PetGardenScreen extends StatefulWidget {
  final String houseId;
  final String myName;

  const PetGardenScreen({
    super.key,
    required this.houseId,
    required this.myName,
  });

  @override
  State<PetGardenScreen> createState() => _PetGardenScreenState();
}

class _PetGardenScreenState extends State<PetGardenScreen> with SingleTickerProviderStateMixin {
  final _petService = PetGardenService();
  final _nameController = TextEditingController();
  String _selectedType = 'dog'; // 'dog', 'cat', 'tree'
  bool _isAdopting = false;
  bool _isInteracting = false;
  late AnimationController _bounceController;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    // Tự động kích hoạt thở nhẹ/bập bênh
    _bounceController.repeat(reverse: true);
    unawaited(_decayStatusOnEntry());
  }

  Future<void> _decayStatusOnEntry() async {
    try {
      await _petService.decayPetStatus(widget.houseId);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bounceController.dispose();
    super.dispose();
  }

  Future<void> _adoptPet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      SLNotice.showError(context, 'Vui lòng nhập tên cho thú cưng!');
      return;
    }
    setState(() => _isAdopting = true);
    try {
      await _petService.adoptPet(widget.houseId, _selectedType, name);
      if (mounted) {
        SLNotice.showSuccess(context, 'Nhận nuôi thành công! Chào đón $name về nhà mới 🥳');
        _nameController.clear();
      }
    } catch (e) {
      if (mounted) {
        SLNotice.showError(context, 'Không thể nhận nuôi lúc này. Vui lòng thử lại!');
      }
    } finally {
      if (mounted) setState(() => _isAdopting = false);
    }
  }

  Future<void> _feedPet(PetVirtual pet) async {
    if (_isInteracting) return;
    setState(() => _isInteracting = true);
    try {
      await _petService.feedPet(widget.houseId);
      if (mounted) {
        SLNotice.showSuccess(context, 'Đã cho ${pet.name} ăn! +10 EXP 🍖');
      }
    } catch (e) {
      if (mounted) {
        SLNotice.showError(context, 'Không thể cho ăn lúc này.');
      }
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
  }

  Future<void> _playPet(PetVirtual pet) async {
    if (_isInteracting) return;
    setState(() => _isInteracting = true);
    try {
      await _petService.playWithPet(widget.houseId);
      if (mounted) {
        SLNotice.showSuccess(context, 'Đã chơi đùa với ${pet.name}! ❤️🧸');
      }
    } catch (e) {
      if (mounted) {
        SLNotice.showError(context, 'Không thể chơi lúc này.');
      }
    } finally {
      if (mounted) setState(() => _isInteracting = false);
    }
  }

  String _formatTime(int ms) {
    if (ms <= 0) return 'Chưa rõ';
    final date = DateTime.fromMillisecondsSinceEpoch(ms);
    return DateFormat('HH:mm dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: SLTheme.appBar(
        context,
        L10nService().translate('utility_title_pet'),
      ),
      body: SLTheme.softCanvasBackdrop(
        baseColor: SLColors.bgMain,
        accentColor: SLColors.accentPink,
        secondaryAccent: SLColors.secondary,
        motif: SLCanvasBackdropMotif.sparkles,
        child: SafeArea(
          child: StreamBuilder<PetVirtual?>(
            stream: _petService.petStream(widget.houseId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: SLColors.primary),
                );
              }

              final pet = snapshot.data;
              if (pet == null) {
                return _buildAdoptView();
              }

              return _buildPetDetailView(pet);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildAdoptView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SLSpacing.h24,
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: SLColors.primary.withValues(alpha: 0.1),
            ),
            child: const Icon(
              Icons.pets_rounded,
              size: 72,
              color: SLColors.primary,
            ),
          ),
          SLSpacing.h20,
          Text(
            'Nhận Nuôi Thú Cưng / Trồng Cây Chung',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: SLColors.textPrimary,
            ),
          ),
          SLSpacing.h8,
          Text(
            'Nuôi dưỡng một bé thú cưng hoặc chăm sóc cây ma thuật cùng người ấy. Chỉ số No và Vui vẻ sẽ giảm dần theo thời gian nếu không được chăm sóc!',
            textAlign: TextAlign.center,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: SLColors.textSecond,
            ),
          ),
          SLSpacing.h32,
          Text(
            'CHỌN LOẠI THÚ CƯNG',
            style: SLTheme.quicksand(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: SLColors.primary,
              letterSpacing: 1.1,
            ),
          ),
          SLSpacing.h16,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTypeCard('dog', '🐶', 'Cún Cưng'),
              SLSpacing.w16,
              _buildTypeCard('cat', '🐱', 'Mèo Ngoan'),
              SLSpacing.w16,
              _buildTypeCard('tree', '🌲', 'Cây Phép'),
            ],
          ),
          SLSpacing.h32,
          SLTheme.softPanel(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameController,
              cursorColor: SLColors.primary,
              maxLength: 15,
              style: SLTheme.quicksand(
                fontWeight: FontWeight.w800,
                color: SLColors.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: 'Đặt tên cho thú cưng...',
                hintStyle: SLTheme.quicksand(
                  color: SLColors.textSecond.withValues(alpha: 0.6),
                  fontWeight: FontWeight.w700,
                ),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
          ),
          SLSpacing.h32,
          _isAdopting
              ? const CircularProgressIndicator(color: SLColors.primary)
              : SizedBox(
                  width: double.infinity,
                  child: SLTheme.primaryButton(
                    text: 'NHẬN NUÔI NGAY',
                    onPressed: _adoptPet,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTypeCard(String type, String emoji, String label) {
    final isSelected = _selectedType == type;
    return GestureDetector(
      onTap: () => setState(() => _selectedType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: 96,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? SLColors.primary.withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? SLColors.primary : SLColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? SLShadow.primary : SLShadow.subtle,
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            SLSpacing.h8,
            Text(
              label,
              style: SLTheme.quicksand(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isSelected ? SLColors.primary : SLColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetDetailView(PetVirtual pet) {
    // Chọn màu nền và biểu tượng theo loại
    String petEmoji = '🐶';
    List<Color> gradientColors = [const Color(0xFFFFF9C4), const Color(0xFFFFB300)];
    String petTypeName = 'Cún cưng';
    if (pet.type == 'cat') {
      petEmoji = '🐱';
      gradientColors = [const Color(0xFFFFE0B2), const Color(0xFFFF7043)];
      petTypeName = 'Mèo ngoan';
    } else if (pet.type == 'tree') {
      petEmoji = '🌲';
      gradientColors = [const Color(0xFFC8E6C9), const Color(0xFF4CAF50)];
      petTypeName = 'Cây phép';
    }

    // Trạng thái cảm xúc
    String moodText = 'Đang khỏe mạnh và vui tươi 🥰';
    if (pet.hunger < 35) {
      moodText = '${pet.name} đang rất đói bụng! 🍖';
    } else if (pet.happiness < 35) {
      moodText = '${pet.name} đang buồn chán và cần chơi đùa! 🥺';
    }

    // EXP cần cho level tiếp theo
    final expNeeded = pet.level * 100;
    final expProgress = (pet.exp / expNeeded).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        children: [
          // Thẻ Nhân Vật Thú Cưng
          Center(
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                CurvedAnimation(parent: _bounceController, curve: Curves.easeInOutSine),
              ),
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[1].withValues(alpha: 0.35),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    petEmoji,
                    style: const TextStyle(fontSize: 88),
                  ),
                ),
              ),
            ),
          ),
          SLSpacing.h24,

          // Tên và Level
          Text(
            pet.name,
            style: SLTheme.quicksand(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: SLColors.textPrimary,
            ),
          ),
          SLSpacing.h4,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              gradient: SLColors.goldGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: SLShadow.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Colors.orange, size: 16),
                SLSpacing.w4,
                Text(
                  'CẤP ĐỘ ${pet.level}',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.orange.shade900,
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h8,
          Text(
            moodText,
            style: SLTheme.quicksand(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: SLColors.primary,
            ),
          ),
          SLSpacing.h24,

          // EXP Progress Bar
          SLTheme.softPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Kinh nghiệm (EXP)',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: SLColors.textSecond,
                      ),
                    ),
                    Text(
                      '${pet.exp} / $expNeeded',
                      style: SLTheme.quicksand(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SLSpacing.h8,
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: expProgress,
                    minHeight: 8,
                    backgroundColor: SLColors.borderLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.orange),
                  ),
                ),
              ],
            ),
          ),
          SLSpacing.h16,

          // Chỉ số Độ no & Vui vẻ
          Row(
            children: [
              Expanded(
                child: _buildStatPanel(
                  title: 'Độ no',
                  value: pet.hunger,
                  icon: Icons.restaurant_rounded,
                  color: Colors.green,
                  bgColor: Colors.green.shade50,
                ),
              ),
              SLSpacing.w16,
              Expanded(
                child: _buildStatPanel(
                  title: 'Vui vẻ',
                  value: pet.happiness,
                  icon: Icons.toys_rounded,
                  color: Colors.pink,
                  bgColor: Colors.pink.shade50,
                ),
              ),
            ],
          ),
          SLSpacing.h24,

          // Nút hành động
          Row(
            children: [
              Expanded(
                child: SLTheme.primaryButton(
                  text: 'CHO ĂN 🍖',
                  onPressed: _isInteracting ? null : () => _feedPet(pet),
                ),
              ),
              SLSpacing.w16,
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(SLRadius.lg),
                    boxShadow: SLShadow.subtle,
                  ),
                  child: TextButton(
                    onPressed: _isInteracting ? null : () => _playPet(pet),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: SLRadius.lgAll,
                        side: const BorderSide(color: SLColors.primary, width: 1.5),
                      ),
                    ),
                    child: Text(
                      'CHƠI ĐÙA 🧸',
                      style: SLTheme.quicksand(
                        color: SLColors.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SLSpacing.h24,

          // Lịch sử / Thông tin
          SLTheme.softPanel(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'THÔNG TIN CHĂM SÓC',
                  style: SLTheme.quicksand(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: SLColors.textSecond,
                    letterSpacing: 1.0,
                  ),
                ),
                SLSpacing.h12,
                _buildInfoRow('Loại sinh vật', petTypeName),
                const Divider(color: SLColors.borderLight),
                _buildInfoRow('Lần ăn cuối', _formatTime(pet.lastFedAt)),
                const Divider(color: SLColors.borderLight),
                _buildInfoRow('Lần chơi cuối', _formatTime(pet.lastPlayedAt)),
              ],
            ),
          ),
          SLSpacing.h24,
        ],
      ),
    );
  }

  Widget _buildStatPanel({
    required String title,
    required int value,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: SLShadow.subtle,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              SLSpacing.w8,
              Text(
                title,
                style: SLTheme.quicksand(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: SLColors.textSecond,
                ),
              ),
            ],
          ),
          SLSpacing.h16,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$value%',
                style: SLTheme.quicksand(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: SLColors.textPrimary,
                ),
              ),
              Icon(
                value > 50 ? Icons.sentiment_very_satisfied_rounded : Icons.sentiment_very_dissatisfied_rounded,
                color: color,
                size: 24,
              ),
            ],
          ),
          SLSpacing.h8,
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: value / 100.0,
              minHeight: 6,
              backgroundColor: SLColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: SLColors.textSecond,
          ),
        ),
        Text(
          value,
          style: SLTheme.quicksand(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: SLColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
