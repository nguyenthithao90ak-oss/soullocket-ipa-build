// ignore_for_file: invalid_use_of_protected_member
part of '../creative_diary_screen.dart';

extension _CreativeDiaryCreateSheetPart on _CreativeDiaryScreenState {
  Future<void> _showCreateSheet() async {
    final titleCtrl = TextEditingController();
    final memoryCtrl = TextEditingController();
    final promptCtrl = TextEditingController();
    XFile? selectedImage;

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
            child: StatefulBuilder(
              builder: (sheetContext, setSheetState) => SingleChildScrollView(
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
                    _DiaryImagePickerTile(
                      image: selectedImage,
                      onPick: () async {
                        final image =
                            await ImagePickerRecoveryService.instance.pickImage(
                          source: ImageSource.gallery,
                          maxWidth: 1800,
                          maxHeight: 1800,
                          imageQuality: 88,
                        );
                        if (image == null) return;
                        setSheetState(() => selectedImage = image);
                      },
                      onRemove: () => setSheetState(() => selectedImage = null),
                    ),
                    SLSpacing.h16,
                    Text(
                      context.tr('util_thmtrangkn_d61f27'),
                      style: SLTheme.quicksand(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: SLColors.textPrimary,
                      ),
                    ),
                    SLSpacing.h16,
                    _DiaryInput(
                      controller: titleCtrl,
                      label: context.tr('util_tiu_ae4b89'),
                      hintText: context.tr('util_vdbuitixem_e09d54'),
                    ),
                    SLSpacing.h12,
                    _DiaryInput(
                      controller: memoryCtrl,
                      label: context.tr('util_knim_4f6aeb'),
                      hintText: context.tr('util_vitvidngng_a01427'),
                      maxLines: 4,
                    ),
                    SLSpacing.h12,
                    _DiaryInput(
                      controller: promptCtrl,
                      label: 'Prompt',
                      hintText: context.tr('util_mtcuhiginh_cd66f6'),
                      maxLines: 2,
                    ),
                    SLSpacing.h16,
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving
                            ? null
                            : () async {
                                final fallbackPrompt =
                                    context.tr('util_hythmmtchi_6eddec');
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
                                  var imageUrl = '';
                                  final image = selectedImage;
                                  if (image != null) {
                                    final upload =
                                        await _storageService.uploadGiftImage(
                                      _houseId!,
                                      image,
                                      minWidth: 1440,
                                      minHeight: 1440,
                                      quality: 82,
                                    );
                                    imageUrl = upload?.downloadUrl ?? '';
                                  }
                                  await _creativeDiaryService.saveCreativePage(
                                    houseId: _houseId!,
                                    content: memory,
                                    metadata: {
                                      'title': title,
                                      if (imageUrl.isNotEmpty)
                                        'imageUrl': imageUrl,
                                      'prompt': prompt.isEmpty
                                          ? fallbackPrompt
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
                          _isSaving
                              ? context.tr('util_anglu_4d30b6')
                              : context.tr('util_luvostay_0f0952'),
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
          ),
        );
      },
    );
  }
}

class _DiaryImagePickerTile extends StatelessWidget {
  final XFile? image;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _DiaryImagePickerTile({
    required this.image,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPick,
      borderRadius: SLRadius.lgAll,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: SLColors.bgSubtle,
          borderRadius: SLRadius.lgAll,
          border: Border.all(color: SLColors.border),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 54,
                height: 54,
                color: Colors.white,
                child: image == null
                    ? const Icon(
                        Icons.add_photo_alternate_rounded,
                        color: SLColors.primaryActive,
                      )
                    : Image.file(
                        File(image!.path),
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
              ),
            ),
            SLSpacing.w12,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    image == null
                        ? context.tr('util_nhnhkm_035065')
                        : context.tr('util_chnnh_d05e7e'),
                    style: SLTheme.quicksand(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: SLColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    image == null
                        ? context.tr('util_chnnhtmyap_ffd3d5')
                        : context.tr('util_nhshinnhtr_778db1'),
                    style: SLTheme.quicksand(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: SLColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (image == null)
              const Icon(Icons.chevron_right_rounded,
                  color: SLColors.textTertiary)
            else
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.close_rounded),
                color: SLColors.primaryActive,
              ),
          ],
        ),
      ),
    );
  }
}
