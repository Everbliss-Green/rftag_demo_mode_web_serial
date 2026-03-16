import 'package:flutter/material.dart';

import '../scenarios/base_scenario.dart';
import '../theme/app_theme.dart';

/// Card for displaying and running a demo scenario.
class ScenarioCard extends StatelessWidget {
  final BaseScenario scenario;
  final bool isRunning;
  final bool isDisabled;
  final ScenarioProgress? progress;
  final ScenarioResult? lastResult;
  final VoidCallback onRun;
  final VoidCallback onCancel;
  final VoidCallback? onShowDetails;

  const ScenarioCard({
    super.key,
    required this.scenario,
    this.isRunning = false,
    this.isDisabled = false,
    this.progress,
    this.lastResult,
    required this.onRun,
    required this.onCancel,
    this.onShowDetails,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(scenario.accentColor);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDisabled || isRunning ? null : onShowDetails,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Accent bar
            Container(height: 4, color: accentColor),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildIcon(accentColor),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scenario.name,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              scenario.description,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      _buildResultBadge(context),
                    ],
                  ),
                  if (isRunning && progress != null) ...[
                    const SizedBox(height: 16),
                    _buildProgress(context, accentColor),
                  ],
                  const SizedBox(height: 16),
                  _buildActionButton(context, accentColor),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(Color accentColor) {
    IconData iconData;
    switch (scenario.iconName) {
      case 'warning_amber':
        iconData = Icons.warning_amber;
        break;
      case 'explore':
        iconData = Icons.explore;
        break;
      case 'group_add':
        iconData = Icons.group_add;
        break;
      case 'chat_bubble':
        iconData = Icons.chat_bubble;
        break;
      default:
        iconData = Icons.play_arrow;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(iconData, color: accentColor, size: 24),
    );
  }

  Widget _buildResultBadge(BuildContext context) {
    if (lastResult == null || isRunning) return const SizedBox.shrink();

    final isSuccess = lastResult!.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isSuccess ? AppTheme.success : AppTheme.error).withValues(
          alpha: 0.15,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess ? Icons.check : Icons.close,
            size: 14,
            color: isSuccess ? AppTheme.success : AppTheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            isSuccess ? 'Done' : 'Failed',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isSuccess ? AppTheme.success : AppTheme.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress(BuildContext context, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress!.progress,
                  backgroundColor: AppTheme.surfaceVariant,
                  valueColor: AlwaysStoppedAnimation(accentColor),
                  minHeight: 6,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${progress!.currentStep}/${progress!.totalSteps}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            if (progress!.stepSuccess != null)
              Icon(
                progress!.stepSuccess! ? Icons.check_circle : Icons.error,
                size: 14,
                color: progress!.stepSuccess!
                    ? AppTheme.success
                    : AppTheme.error,
              ),
            if (progress!.stepSuccess == null)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                progress!.stepTitle,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, Color accentColor) {
    if (isRunning) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onCancel,
          icon: const Icon(Icons.stop, size: 18),
          label: const Text('Cancel'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error),
          ),
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isDisabled ? null : onRun,
        icon: const Icon(Icons.play_arrow, size: 18),
        label: const Text('Run Scenario'),
        style: ElevatedButton.styleFrom(
          backgroundColor: accentColor,
          disabledBackgroundColor: AppTheme.surfaceVariant,
        ),
      ),
    );
  }
}

/// Dialog showing scenario details before running.
class ScenarioDetailsDialog extends StatelessWidget {
  final BaseScenario scenario;
  final VoidCallback onRun;

  const ScenarioDetailsDialog({
    super.key,
    required this.scenario,
    required this.onRun,
  });

  @override
  Widget build(BuildContext context) {
    final accentColor = Color(scenario.accentColor);

    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_getIconData(), color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(scenario.name),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scenario.details,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppTheme.textMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Requires location permission for positioning.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            onRun();
          },
          icon: const Icon(Icons.play_arrow, size: 18),
          label: const Text('Run'),
          style: ElevatedButton.styleFrom(backgroundColor: accentColor),
        ),
      ],
    );
  }

  IconData _getIconData() {
    switch (scenario.iconName) {
      case 'warning_amber':
        return Icons.warning_amber;
      case 'explore':
        return Icons.explore;
      case 'group_add':
        return Icons.group_add;
      case 'chat_bubble':
        return Icons.chat_bubble;
      default:
        return Icons.play_arrow;
    }
  }
}
