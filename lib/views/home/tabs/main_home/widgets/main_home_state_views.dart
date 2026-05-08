// ignore_for_file: unused_element

part of '../../main_home_tab.dart';

const Color _mainHomeAccentColor = Color(0xFFD81B60);
const Color _mainHomeOverlayColor = Color(0x52FFF7FA);
const Color _mainHomeErrorTextColor = Color(0xFF6B7280);

class _MainHomeStateView extends StatelessWidget {
  final bool isLoading;
  final bool hasVisibleContent;
  final Widget? child;

  const _MainHomeStateView({
    required this.isLoading,
    required this.hasVisibleContent,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasVisibleContent && isLoading) {
      return const _MainHomeLoadingView();
    }
    if (child == null) {
      return const _MainHomeEmptyView();
    }
    if (!isLoading) {
      return child!;
    }
    if (!hasVisibleContent) {
      return const _MainHomeLoadingView();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        child!,
        const _MainHomeLoadingOverlay(),
      ],
    );
  }
}

class _MainHomeLoadingView extends StatelessWidget {
  const _MainHomeLoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: _mainHomeAccentColor),
    );
  }
}

class _MainHomeLoadingOverlay extends StatelessWidget {
  const _MainHomeLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ColoredBox(
        color: _mainHomeOverlayColor,
        child: Center(
          child: CircularProgressIndicator(color: _mainHomeAccentColor),
        ),
      ),
    );
  }
}

class _MainHomeEmptyView extends StatelessWidget {
  const _MainHomeEmptyView();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _MainHomeErrorView extends StatelessWidget {
  final String message;

  const _MainHomeErrorView({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: SLTheme.quicksand(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: _mainHomeErrorTextColor,
        ),
      ),
    );
  }
}
