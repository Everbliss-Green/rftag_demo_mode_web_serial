import 'package:flutter/material.dart';

import '../services/device_service.dart';
import '../theme/app_theme.dart';

/// Card displaying device connection status and controls.
class ConnectionCard extends StatelessWidget {
  final DeviceService deviceService;
  final bool isConnected;
  final DeviceInfo? deviceInfo;
  final bool isConnecting;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;

  const ConnectionCard({
    super.key,
    required this.deviceService,
    required this.isConnected,
    this.deviceInfo,
    this.isConnecting = false,
    required this.onConnect,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'Connected' : 'Disconnected',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isConnected
                            ? 'RFTag device ready'
                            : 'Connect your RFTag via USB',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildConnectionButton(),
              ],
            ),
            if (isConnected && deviceInfo != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _buildDeviceInfo(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isConnected
            ? AppTheme.success.withValues(alpha: 0.15)
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isConnecting
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              isConnected ? Icons.usb : Icons.usb_off,
              color: isConnected ? AppTheme.success : AppTheme.textSecondary,
              size: 24,
            ),
    );
  }

  Widget _buildConnectionButton() {
    if (isConnecting) {
      return OutlinedButton(
        onPressed: null,
        child: const Text('Connecting...'),
      );
    }

    if (isConnected) {
      return OutlinedButton.icon(
        onPressed: onDisconnect,
        icon: const Icon(Icons.link_off, size: 18),
        label: const Text('Disconnect'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.error,
          side: const BorderSide(color: AppTheme.error),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: onConnect,
      icon: const Icon(Icons.link, size: 18),
      label: const Text('Connect'),
      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success),
    );
  }

  Widget _buildDeviceInfo(BuildContext context) {
    return Row(
      children: [
        _buildInfoChip(
          context,
          Icons.memory,
          deviceInfo!.version.split('\n').first,
        ),
        const SizedBox(width: 12),
        _buildInfoChip(context, Icons.bluetooth, deviceInfo!.mac),
        if (deviceInfo!.battery != null) ...[
          const SizedBox(width: 12),
          _buildInfoChip(
            context,
            Icons.battery_charging_full,
            deviceInfo!.battery!,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoChip(BuildContext context, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
