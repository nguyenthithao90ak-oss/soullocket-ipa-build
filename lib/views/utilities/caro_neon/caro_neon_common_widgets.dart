part of '../caro_neon_screen.dart';

class _UnavailableState extends StatelessWidget {
  const _UnavailableState({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Chưa xác định được ngôi nhà để mở game Caro.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Hãy mở lại sau khi app đã vào đúng không gian riêng, hoặc thử tải lại dữ liệu.',
              textAlign: TextAlign.center,
              style: SLTheme.quicksand(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFC2BCD8),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4EDBFF),
                foregroundColor: const Color(0xFF120519),
              ),
              child: const Text('Tải lại'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: const Color(0x1CF6E7FF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x4D78F5FF)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x40000000),
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 18),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.06,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8D5A2),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
          border: Border.all(color: const Color(0xFFFFF1D9), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x332B0700),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Text(
          label,
          style: SLTheme.quicksand(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
            color: const Color(0xFF472400),
          ),
        ),
      ),
    );
  }
}
