part of '../../main_home_tab.dart';

extension _MainHomeQuoteActivityCard on _MainHomeTabState {
  Widget _buildQuoteActivityCard() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchQuoteAndActivity(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;
        final quote = data['quote'] as Map<String, String>?;
        final activity = data['activity'] as Map<String, dynamic>?;

        return SLTheme.glassCard(
          margin: EdgeInsets.zero,
          padding: SLSpacing.all16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quote section
              if (quote != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.format_quote_rounded,
                        color: Color(0xFFE8829A), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quote['content'] ?? '',
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF263242),
                              height: 1.5,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          if ((quote['author'] ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                '— ${quote['author']}',
                                style: SLTheme.quicksand(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
              if (quote != null && activity != null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: Color(0xFFF0F0F0)),
                ),
              // Activity section
              if (activity != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_rounded,
                        color: Color(0xFFFFB74D), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gợi ý: ${activity['activity'] ?? ''}',
                            style: SLTheme.quicksand(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF263242),
                              height: 1.5,
                            ),
                          ),
                          if ((activity['type'] ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                ActivityService.translateType(
                                    activity['type']?.toString()),
                                style: SLTheme.quicksand(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF9E9E9E),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _fetchQuoteAndActivity() async {
    final results = await Future.wait([
      QuoteService().fetchQuote(),
      ActivityService().fetchActivity(),
    ]);
    final quote = results[0] as Map<String, String>?;
    final activity = results[1] as Map<String, dynamic>?;
    if (quote == null && activity == null) return null;
    return {
      'quote': quote,
      'activity': activity,
    };
  }
}
