part of '../../settings_tab.dart';

class _CountdownSpaceRenameDialog extends StatefulWidget {
  const _CountdownSpaceRenameDialog({
    required this.initialName,
    required this.decorationBuilder,
  });

  final String initialName;
  final InputDecoration Function({
    required String label,
    String? hint,
  }) decorationBuilder;

  @override
  State<_CountdownSpaceRenameDialog> createState() =>
      _CountdownSpaceRenameDialogState();
}

class _CountdownSpaceRenameDialogState
    extends State<_CountdownSpaceRenameDialog> {
  late final TextEditingController _controller;
  bool _isClosing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close([String? value]) {
    if (!mounted || _isClosing) {
      return;
    }
    _isClosing = true;
    FocusScope.of(context).unfocus();
    Navigator.maybeOf(context)?.pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF101A2B),
      title: Text(
        context.tr('home_ttnkhnggia_9d2bdf'),
        style: SLTheme.quicksand(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 28,
        textInputAction: TextInputAction.done,
        style: SLTheme.quicksand(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        decoration: widget.decorationBuilder(
          label: context.tr('home_tnhinth_6cccad'),
          hint: context.tr('home_vdkhnggian_d6db2a'),
        ),
        onSubmitted: (_) => _close(_controller.text.trim()),
      ),
      actions: [
        TextButton(
          onPressed: _close,
          child: Text(context.tr('home_hy_1e4050')),
        ),
        ElevatedButton(
          onPressed: () => _close(_controller.text.trim()),
          child: Text(context.tr('home_lu_49fac1')),
        ),
      ],
    );
  }
}

class _CountdownSpaceAddDialog extends StatefulWidget {
  const _CountdownSpaceAddDialog({
    required this.decorationBuilder,
    required this.normalizeCode,
    required this.validateLocalCode,
    required this.onSubmitCode,
  });

  final InputDecoration Function({
    required String label,
    String? hint,
  }) decorationBuilder;
  final String Function(String rawCode) normalizeCode;
  final String? Function(String code) validateLocalCode;
  final Future<_CountdownSpaceAddResult> Function(String code) onSubmitCode;

  @override
  State<_CountdownSpaceAddDialog> createState() =>
      _CountdownSpaceAddDialogState();
}

class _CountdownSpaceAddDialogState extends State<_CountdownSpaceAddDialog> {
  late final TextEditingController _controller;
  String _errorText = '';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) {
      return;
    }

    final code = widget.normalizeCode(_controller.text);
    final localError = widget.validateLocalCode(code);
    if (localError != null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = localError;
      });
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSubmitting = true;
      _errorText = '';
    });

    final result = await widget.onSubmitCode(code);
    if (!mounted) {
      return;
    }

    if (result.success) {
      Navigator.of(context).pop(result.message);
      return;
    }

    setState(() {
      _isSubmitting = false;
      _errorText = result.message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF101A2B),
      title: Text(
        context.tr('home_ghpnikhngg_860e28'),
        style: SLTheme.quicksand(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.none,
        autocorrect: false,
        enableSuggestions: false,
        style: SLTheme.quicksand(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        decoration: widget
            .decorationBuilder(
              label: context.tr('home_mnhusernam_02a809'),
              hint: context.tr('home_nhpmnhuser_66bbe7'),
            )
            .copyWith(
              helperText: context.tr('home_vdnhabc123_4640df'),
              errorText: _errorText.isEmpty ? null : _errorText,
            ),
        onChanged: (_) {
          if (_errorText.isEmpty || !mounted) {
            return;
          }
          setState(() {
            _errorText = '';
          });
        },
        onSubmitted: (_) => unawaited(_submit()),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(context.tr('home_hy_1e4050')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : () => unawaited(_submit()),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(context.tr('home_giyucu_576885')),
        ),
      ],
    );
  }
}
