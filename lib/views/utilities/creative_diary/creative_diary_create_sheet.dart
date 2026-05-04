part of '../creative_diary_screen.dart';
// ignore_for_file: invalid_use_of_protected_member

extension _CreativeDiaryCreateSheetPart on _CreativeDiaryScreenState {
  Future<void> _showCreateSheet() async {
    final titleCtrl = TextEditingController();
    final memoryCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    final imageCtrl = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            ),
            decoration: const BoxDecoration(
              color: SLColors.bgCard,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(SLRadius.xl)),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: SLColors.border,
                        borderRadius: SLRadius.pillAll,
                      ),
                    ),
                  ),
                  SLSpacing.h12,
                  _DiaryInput(
                    controller: imageCtrl,
                    label: 'Ảnh đính kèm',
                    hintText: 'Dán link ảnh nếu muốn trang có ảnh riêng',
                  ),
                  SLSpacing.h16,
                  Text(
                    'Thêm trang kỷ niệm mới',
                    style: SLTheme.quicksand(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: SLColors.textPrimary,
                    ),
                  ),
                  SLSpacing.h16,
                  _DiaryInput(
                    controller: titleCtrl,
                    label: 'Tiêu đề',
                    hintText: 'Ví dụ: Buổi tối xem phim cùng nhau',
                  ),
                  SLSpacing.h12,
                  _DiaryInput(
                    controller: memoryCtrl,
                    label: 'Kỷ niệm',
                    hintText: 'Viết vài dòng đáng nhớ...',
                    maxLines: 4,
                  ),
                  SLSpacing.h12,
                  _DiaryInput(
                    controller: promptCtrl,
                    label: 'Prompt',
                    hintText: 'Một câu hỏi để gợi nhớ sâu hơn',
                    maxLines: 2,
                  ),
                  SLSpacing.h16,
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                              final navigator = Navigator.of(sheetContext);
                              final title = titleCtrl.text.trim();
                              final memory = memoryCtrl.text.trim();
                              final prompt = promptCtrl.text.trim();

                              if (title.isEmpty || memory.isEmpty) {
                                return;
                              }
                              if (_houseId == null || _houseId!.isEmpty) {
                                return;
                              }

                              setState(() => _isSaving = true);
                              try {
                                await _creativeDiaryService.saveCreativePage(
                                  houseId: _houseId!,
                                  content: memory,
                                  metadata: {
                                    'title': title,
                                    'prompt': prompt.isEmpty
                                        ? 'Hãy thêm một chi tiết nhỏ để ghi nhớ lâu hơn.'
                                        : prompt,
                                  },
                                );

                                if (!mounted) {
                                  return;
                                }
                                navigator.pop();
                                Future<void>.delayed(
                                  const Duration(milliseconds: 250),
                                  () {
                                    if (!mounted || _pages.isEmpty) {
                                      return;
                                    }
                                    _pageController.animateToPage(
                                      0,
                                      duration:
                                          const Duration(milliseconds: 260),
                                      curve: Curves.easeOut,
                                    );
                                  },
                                );
                              } finally {
                                if (mounted) {
                                  setState(() => _isSaving = false);
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SLColors.primaryActive,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: SLRadius.lgAll,
                        ),
                      ),
                      child: Text(
                        _isSaving ? 'Đang lưu...' : 'Lưu vào sổ tay',
                        style: SLTheme.quicksand(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
