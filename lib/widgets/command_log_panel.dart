import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/device_service.dart';
import '../theme/app_theme.dart';

/// Terminal-style log panel for displaying serial communication.
class CommandLogPanel extends StatefulWidget {
  final List<LogEntry> logs;
  final VoidCallback onClear;
  final bool isExpanded;
  final VoidCallback onToggleExpand;

  const CommandLogPanel({
    super.key,
    required this.logs,
    required this.onClear,
    this.isExpanded = true,
    required this.onToggleExpand,
  });

  @override
  State<CommandLogPanel> createState() => _CommandLogPanelState();
}

class _CommandLogPanelState extends State<CommandLogPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(CommandLogPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.logs.length > oldWidget.logs.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _copyLogs() {
    final text = widget.logs
        .map((e) => '[${e.timestampStr}] ${e.message}')
        .join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.terminalBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          if (widget.isExpanded) ...[
            const Divider(height: 1, color: AppTheme.surfaceVariant),
            Expanded(child: _buildLogList()),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Icon(Icons.terminal, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Text(
            'Serial Log',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '${widget.logs.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textMuted,
                fontFamily: 'monospace',
                fontSize: 11,
              ),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.copy, size: 18),
            onPressed: widget.logs.isEmpty ? null : _copyLogs,
            tooltip: 'Copy logs',
            color: AppTheme.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 18),
            onPressed: widget.logs.isEmpty ? null : widget.onClear,
            tooltip: 'Clear logs',
            color: AppTheme.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: Icon(
              widget.isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            onPressed: widget.onToggleExpand,
            tooltip: widget.isExpanded ? 'Collapse' : 'Expand',
            color: AppTheme.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildLogList() {
    if (widget.logs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.terminal, size: 48, color: AppTheme.textMuted),
              const SizedBox(height: 12),
              Text(
                'No logs yet',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
              ),
              const SizedBox(height: 4),
              Text(
                'Connect to device and run a scenario',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(12),
      itemCount: widget.logs.length,
      itemBuilder: (context, index) {
        final log = widget.logs[index];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.timestampStr,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  color: AppTheme.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              _buildLogIcon(log.type),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  log.message,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: _getLogColor(log.type),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogIcon(LogType type) {
    IconData icon;
    Color color;

    switch (type) {
      case LogType.tx:
        icon = Icons.arrow_upward;
        color = AppTheme.terminalTx;
        break;
      case LogType.rx:
        icon = Icons.arrow_downward;
        color = AppTheme.terminalRx;
        break;
      case LogType.success:
        icon = Icons.check_circle;
        color = AppTheme.success;
        break;
      case LogType.error:
        icon = Icons.error;
        color = AppTheme.terminalError;
        break;
      case LogType.warning:
        icon = Icons.warning;
        color = AppTheme.warning;
        break;
      case LogType.info:
        icon = Icons.info_outline;
        color = AppTheme.terminalInfo;
    }

    return Icon(icon, size: 12, color: color);
  }

  Color _getLogColor(LogType type) {
    switch (type) {
      case LogType.tx:
        return AppTheme.terminalTx;
      case LogType.rx:
        return AppTheme.terminalRx;
      case LogType.success:
        return AppTheme.success;
      case LogType.error:
        return AppTheme.terminalError;
      case LogType.warning:
        return AppTheme.warning;
      case LogType.info:
        return AppTheme.terminalInfo;
    }
  }
}
