part of '../../settings_tab.dart';

extension _CountdownModeEditorHelpersPart on _CountdownModeEditorScreenState {
  void _showMessageImpl(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _disposeTemporaryUrlImpl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty || !_temporaryUploadedUrls.remove(trimmed)) {
      return;
    }
    unawaited(_storageService.deleteImageByUrl(trimmed));
  }

  void _rememberUploadedUrlImpl({
    required String previousUrl,
    required String nextUrl,
  }) {
    final previous = previousUrl.trim();
    final next = nextUrl.trim();
    if (previous == next) {
      return;
    }
    _disposeTemporaryUrl(previous);
    if (next.isNotEmpty) {
      _temporaryUploadedUrls.add(next);
    }
  }

  void _preserveCurrentUploadsImpl() {
    _temporaryUploadedUrls.remove(_leftAvatarCtrl.text.trim());
    _temporaryUploadedUrls.remove(_rightAvatarCtrl.text.trim());
    _temporaryUploadedUrls.remove(_customBackgroundUrl.trim());
  }

  void _clearBackgroundImageImpl() {
    _disposeTemporaryUrl(_customBackgroundUrl);
    _safeSetState(() {
      _customBackgroundUrl = '';
    });
  }

  InputDecoration _fieldDecorationImpl({
    required String label,
    String? hint,
    bool dark = false,
  }) {
    final fillColor =
        dark ? const Color(0xFF162136) : Colors.white.withValues(alpha: 0.88);
    final labelColor = dark ? Colors.white70 : const Color(0xFF8A5B76);
    final hintColor = dark ? Colors.white38 : const Color(0xFFB9A6B3);
    final borderColor =
        dark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFF3CBDD);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: fillColor,
      labelStyle: SLTheme.quicksand(
        color: labelColor,
        fontWeight: FontWeight.w800,
      ),
      hintStyle: SLTheme.quicksand(
        color: hintColor,
        fontWeight: FontWeight.w700,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: Color(0xFFD81B60), width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _sectionCardImpl({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFFFFF),
            Color(0xFFFFF8FB),
            Color(0xFFFDF0F6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF8DBE8), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD81B60).withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFEC407A),
                      Color(0xFFD81B60),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD81B60).withValues(alpha: 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: SLTheme.quicksand(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFFD81B60),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: SLTheme.quicksand(
                        fontSize: 11.8,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF7C6D76),
                        height: 1.42,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _pickAnchorDateImpl() async {
    final now = DateTime.now();
    final firstDate = DateTime(1970, 1, 1);
    final lastDate = DateTime(now.year + 5, 12, 31);
    final initialDate = _anchorDate ?? now;
    final picked = await _showAnchorDateInputDialogImpl(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null && mounted) {
      _safeSetState(() {
        _anchorDate = picked;
      });
    }
  }

  Future<DateTime?> _showAnchorDateInputDialogImpl({
    required DateTime initialDate,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final dialogInitial = DateTime(
      initialDate.year,
      initialDate.month,
      initialDate.day,
    );
    final minDate = DateTime(firstDate.year, firstDate.month, firstDate.day);
    final maxDate = DateTime(lastDate.year, lastDate.month, lastDate.day);
    final inputCtrl = TextEditingController(
      text: DateInputUtils.formatDisplayDate(dialogInitial),
    );
    String? errorText;

    bool inRange(DateTime value) {
      return !(value.isBefore(minDate) || value.isAfter(maxDate));
    }

    DateTime? parseInput(String raw) {
      final parsed = DateInputUtils.parse(
        raw,
        firstYear: firstDate.year,
        lastYear: lastDate.year,
        allowMissingYear: true,
        fallbackYear: dialogInitial.year,
      );
      if (parsed == null) {
        return null;
      }
      return DateTime(parsed.year, parsed.month, parsed.day);
    }

    String explainError(String raw) {
      final validationError = DateInputUtils.validationError(
        raw,
        firstYear: firstDate.year,
        lastYear: lastDate.year,
        allowMissingYear: true,
        fallbackYear: dialogInitial.year,
      );
      if (validationError != null) return validationError;
      final parsed = parseInput(raw.trim());
      if (parsed == null) {
        return context.tr('home_ngykhnghpl_b660fe');
      }
      if (!inRange(parsed)) {
        return 'Ngày phải trong khoảng ${DateInputUtils.formatDisplayDate(minDate)} - ${DateInputUtils.formatDisplayDate(maxDate)}.';
      }
      return context.tr('home_nhdngchang_9fbba2');
    }

    try {
      return await showDialog<DateTime>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              Future<void> pickFromCalendar() async {
                final candidate = parseInput(inputCtrl.text);
                final calendarInitial = candidate != null && inRange(candidate)
                    ? candidate
                    : dialogInitial;
                final picked = await showDatePicker(
                  context: context,
                  initialDate: calendarInitial,
                  firstDate: firstDate,
                  lastDate: lastDate,
                );
                if (!context.mounted || !dialogContext.mounted) {
                  return;
                }
                if (picked == null) {
                  return;
                }
                setDialogState(() {
                  errorText = null;
                  inputCtrl.text = DateInputUtils.formatDisplayDate(picked);
                  inputCtrl.selection = TextSelection.collapsed(
                    offset: inputCtrl.text.length,
                  );
                });
              }

              void submit() {
                final parsed = parseInput(inputCtrl.text);
                if (parsed == null || !inRange(parsed)) {
                  setDialogState(() {
                    errorText = explainError(inputCtrl.text);
                  });
                  return;
                }
                inputCtrl.text = DateInputUtils.formatDisplayDate(parsed);
                Navigator.of(dialogContext).pop(parsed);
              }

              return AlertDialog(
                title: Text(
                  context.tr('home_chnngy_d2cce5'),
                  style: SLTheme.quicksand(
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFFD81B60),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: inputCtrl,
                      autofocus: true,
                      keyboardType: TextInputType.datetime,
                      inputFormatters: const [FlexibleDateInputFormatter()],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (errorText == null) {
                          return;
                        }
                        setDialogState(() => errorText = null);
                      },
                      onSubmitted: (_) => submit(),
                      onEditingComplete: () {
                        inputCtrl.text = DateInputUtils.normalizeForDisplay(
                          inputCtrl.text,
                          firstYear: firstDate.year,
                          lastYear: lastDate.year,
                          allowMissingYear: true,
                          fallbackYear: dialogInitial.year,
                        );
                        inputCtrl.selection = TextSelection.collapsed(
                          offset: inputCtrl.text.length,
                        );
                      },
                      decoration: InputDecoration(
                        labelText: context.tr('home_nhpngy_91932a'),
                        hintText: context.tr('home_ngythngnm_a697d0'),
                        helperText: context.tr('home_angnhpngyt_377d85'),
                        errorText: errorText,
                        prefixIcon: const Icon(
                          Icons.calendar_month_rounded,
                          color: Color(0xFFD81B60),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: Text(context.tr('home_hy_1e4050')),
                  ),
                  TextButton(
                    onPressed: () => unawaited(pickFromCalendar()),
                    child: Text(context.tr('home_chnlch_e1fe3f')),
                  ),
                  ElevatedButton(
                    onPressed: submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD81B60),
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      inputCtrl.dispose();
    }
  }

  _CountdownModeSettingsResult _buildResultImpl(
    _CountdownModeSettingsAction action,
  ) {
    if (action == _CountdownModeSettingsAction.save) {
      _preserveCurrentUploads();
    }
    return _CountdownModeSettingsResult(
      action: action,
      singleMode: _singleMode,
      anchorDate: _anchorDate,
      themeKey: _themeKey,
      styleKey: _styleKey,
      frameKey: _frameKey,
      fontKey: _fontKey,
      transparentMode: _transparentMode,
      sizePx: _sizePx,
      topLabel: _topCtrl.text.trim(),
      bottomLabel: _bottomCtrl.text.trim(),
      nameU1: _leftCtrl.text.trim(),
      nameU2: _rightCtrl.text.trim(),
      avatarUrl1: _leftAvatarCtrl.text.trim(),
      avatarUrl2: _rightAvatarCtrl.text.trim(),
      customBackgroundUrl: _customBackgroundUrl.trim(),
      centerIconType: _centerIconType,
    );
  }
}
