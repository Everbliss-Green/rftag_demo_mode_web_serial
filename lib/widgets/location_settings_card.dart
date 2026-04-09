import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:js_interop';

import '../services/geo_service.dart';
import '../theme/app_theme.dart';

// JS interop for window.open
@JS('window.open')
external void _jsWindowOpen(JSString url, JSString target);

/// Card for displaying and configuring location settings.
///
/// Shows current location (auto-detected or manual) and allows
/// users to manually enter coordinates if geolocation is unavailable.
class LocationSettingsCard extends StatefulWidget {
  final GeoPosition? currentPosition;
  final bool isAutoDetected;
  final bool isLoading;
  final VoidCallback onDetectLocation;
  final ValueChanged<GeoPosition> onLocationChanged;

  const LocationSettingsCard({
    super.key,
    this.currentPosition,
    this.isAutoDetected = false,
    this.isLoading = false,
    required this.onDetectLocation,
    required this.onLocationChanged,
  });

  @override
  State<LocationSettingsCard> createState() => _LocationSettingsCardState();
}

class _LocationSettingsCardState extends State<LocationSettingsCard> {
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  String? _latError;
  String? _lonError;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  @override
  void didUpdateWidget(LocationSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPosition != oldWidget.currentPosition && !_isEditing) {
      _updateControllers();
    }
  }

  void _updateControllers() {
    if (widget.currentPosition != null) {
      _latController.text = widget.currentPosition!.latitude.toStringAsFixed(6);
      _lonController.text = widget.currentPosition!.longitude.toStringAsFixed(
        6,
      );
    }
  }

  void _validateAndApply() {
    setState(() {
      _latError = null;
      _lonError = null;
    });

    final latText = _latController.text.trim();
    final lonText = _lonController.text.trim();

    // Check if empty
    if (latText.isEmpty) {
      setState(() => _latError = 'Required');
      return;
    }
    if (lonText.isEmpty) {
      setState(() => _lonError = 'Required');
      return;
    }

    // Parse values
    final lat = double.tryParse(latText);
    final lon = double.tryParse(lonText);

    if (lat == null) {
      setState(() => _latError = 'Invalid number');
      return;
    }
    if (lon == null) {
      setState(() => _lonError = 'Invalid number');
      return;
    }

    // Validate ranges
    if (lat < -90 || lat > 90) {
      setState(() => _latError = 'Must be -90 to 90');
      return;
    }
    if (lon < -180 || lon > 180) {
      setState(() => _lonError = 'Must be -180 to 180');
      return;
    }

    // Valid! Apply the location
    _isEditing = false;
    widget.onLocationChanged(GeoPosition(latitude: lat, longitude: lon));
  }

  void _openGoogleMaps() {
    final uri = 'https://www.google.com/maps';
    _jsWindowOpen(uri.toJS, '_blank'.toJS);
  }

  String get _statusText {
    if (widget.isLoading) return 'Detecting...';
    if (widget.currentPosition == null) return 'Not set';
    if (widget.isAutoDetected) return 'Auto-detected';
    return 'Manual';
  }

  Color get _statusColor {
    if (widget.isLoading) return AppTheme.warning;
    if (widget.currentPosition == null) return AppTheme.error;
    if (widget.isAutoDetected) return AppTheme.success;
    return AppTheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                _buildStatusIndicator(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _statusColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: _statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildDetectButton(),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),

            // Current coordinates display
            if (widget.currentPosition != null && !_isEditing)
              _buildCoordinatesDisplay(),

            // Manual entry fields
            if (widget.currentPosition == null || _isEditing)
              _buildManualEntry(),

            // Help text with Google Maps link
            const SizedBox(height: 12),
            _buildHelpSection(),
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
        color: _statusColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: widget.isLoading
          ? const Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(
              widget.currentPosition != null
                  ? Icons.location_on
                  : Icons.location_off,
              color: _statusColor,
              size: 24,
            ),
    );
  }

  Widget _buildDetectButton() {
    return OutlinedButton.icon(
      onPressed: widget.isLoading ? null : widget.onDetectLocation,
      icon: const Icon(Icons.my_location, size: 18),
      label: const Text('Detect'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: const BorderSide(color: AppTheme.primary),
      ),
    );
  }

  Widget _buildCoordinatesDisplay() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoChip(
                Icons.north,
                'Lat: ${widget.currentPosition!.latitude.toStringAsFixed(6)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoChip(
                Icons.east,
                'Lon: ${widget.currentPosition!.longitude.toStringAsFixed(6)}',
              ),
            ),
            const SizedBox(width: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _isEditing = true;
                  _updateControllers();
                });
              },
              icon: const Icon(Icons.edit, size: 16),
              label: const Text('Edit'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManualEntry() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter coordinates manually:',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                decoration: InputDecoration(
                  labelText: 'Latitude',
                  hintText: '37.7749',
                  errorText: _latError,
                  prefixIcon: const Icon(Icons.north, size: 20),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                onChanged: (_) {
                  _isEditing = true;
                  if (_latError != null) setState(() => _latError = null);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _lonController,
                decoration: InputDecoration(
                  labelText: 'Longitude',
                  hintText: '-122.4194',
                  errorText: _lonError,
                  prefixIcon: const Icon(Icons.east, size: 20),
                  isDense: true,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                ],
                onChanged: (_) {
                  _isEditing = true;
                  if (_lonError != null) setState(() => _lonError = null);
                },
              ),
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ElevatedButton(
                onPressed: _validateAndApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                child: const Text('Apply'),
              ),
            ),
          ],
        ),
        if (_isEditing && widget.currentPosition != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isEditing = false;
                _updateControllers();
                _latError = null;
                _lonError = null;
              });
            },
            child: const Text('Cancel'),
          ),
        ],
      ],
    );
  }

  Widget _buildHelpSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
                children: [
                  const TextSpan(text: "To find your coordinates, open "),
                  WidgetSpan(
                    child: InkWell(
                      onTap: _openGoogleMaps,
                      child: const Text(
                        'Google Maps',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(
                    text:
                        ", right-click your location, and click the coordinates to copy them.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _latController.dispose();
    _lonController.dispose();
    super.dispose();
  }
}
