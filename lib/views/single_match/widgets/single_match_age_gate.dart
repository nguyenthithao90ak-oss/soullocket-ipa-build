import 'package:flutter/material.dart';

import '../../../utils/services/l10n_service.dart';

class SingleMatchAgeGate extends StatelessWidget {
  const SingleMatchAgeGate({
    super.key,
    required this.dob,
    required this.onPickDob,
    this.onSave,
    this.saving = false,
  });

  final String dob;
  final VoidCallback onPickDob;
  final VoidCallback? onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_outline_rounded, size: 40),
        const SizedBox(height: 16),
        Text(
          context.tr('single_match_adult_required'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Text(
          dob.isEmpty ? context.tr('match_bnchathmng_98f34a') : dob,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: saving ? null : onPickDob,
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
          icon: const Icon(Icons.cake_outlined),
          label: Text(context.tr('match_cpnht_3b7db4')),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: saving ? null : onSave,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: Text(context.tr(saving ? 'match_anglu_4d30b6' : 'p3_save')),
        ),
      ],
    ),
  );
}
