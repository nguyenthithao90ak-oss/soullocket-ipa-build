// ignore_for_file: unused_element

part of '../../main_home_tab.dart';

class _MainHomeStateView extends StatelessWidget {
  final bool isLoading;
  final bool hasVisibleContent;
  final String? errorMessage;
  final Widget? child;

  const _MainHomeStateView({
    required this.isLoading,
    required this.hasVisibleContent,
    this.errorMessage,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasVisibleContent && isLoading) {
      return const _MainHomeLoadingView();
    }
    if (!hasVisibleContent && errorMessage != null) {
      return _MainHomeErrorView(message: errorMessage!);
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
      child: CircularProgressIndicator(color: Color(0xFFD81B60)),
    );
  }
}

class _MainHomeLoadingOverlay extends StatelessWidget {
  const _MainHomeLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: ColoredBox(
        color: Color(0x52FFF7FA),
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFD81B60)),
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
          color: const Color(0xFF6B7280),
        ),
      ),
    );
  }
}
