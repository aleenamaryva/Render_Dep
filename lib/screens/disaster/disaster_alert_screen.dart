import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/disaster_alert.dart';
import '../../models/disaster_response.dart';
import '../../services/app_session.dart';

class DisasterAlertScreen extends StatefulWidget {
  const DisasterAlertScreen({super.key});

  @override
  State<DisasterAlertScreen> createState() => _DisasterAlertScreenState();
}

class _DisasterAlertScreenState extends State<DisasterAlertScreen> {
  bool _isSubmitting = false;
  String? _locationError;

  Future<void> _handleResponse(SafetyStatus status) async {
    if (AppSession.currentUser == null) {
      if (!mounted) return;
      Navigator.of(context).pushNamed(AppRoutes.login);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _locationError = null;
    });

    final result = await AppSession.locationService.requestCurrentLocation();
    if (!mounted) return;

    if (!result.success || result.location == null) {
      setState(() {
        _isSubmitting = false;
        _locationError = result.message ?? 'Location unavailable.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_locationError!)),
      );
      return;
    }

    final response = DisasterResponse(
      userId: AppSession.currentUser!.id,
      disasterId: AppSession.activeAlert?.id ?? 'disaster-fallback',
      status: status,
      latitude: result.location!.latitude,
      longitude: result.location!.longitude,
      timestamp: DateTime.now(),
    );

    try {
      await AppSession.apiService.post('/responses', {
        'disaster_id': AppSession.activeAlert?.id,
        'response_type': status == SafetyStatus.safe ? 'SAFE' : 'NEED_HELP',
        'latitude': response.latitude,
        'longitude': response.longitude,
      });
      await AppSession.responseService.saveResponse(response);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _locationError = error.toString().replaceFirst('Exception: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_locationError!)),
      );
      return;
    }
    if (!mounted) return;
    AppSession.currentStatus = status;
    setState(() => _isSubmitting = false);

    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.home,
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final alert = AppSession.activeAlert ?? DisasterAlert.sample();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Disaster Alert'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alert.type,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(alert.description),
                      const SizedBox(height: 16),
                      _InfoRow(label: 'Location', value: alert.location),
                      _InfoRow(
                        label: 'Alert time',
                        value: '${alert.alertTime.day}/${alert.alertTime.month}/${alert.alertTime.year} ${alert.alertTime.hour}:${alert.alertTime.minute.toString().padLeft(2, '0')}',
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Emergency instructions',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(alert.emergencyInstructions),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const Text(
                'How are you?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : () => _handleResponse(SafetyStatus.safe),
                  icon: const Icon(Icons.check_circle_outline, size: 28),
                  label: const Text('I\'M SAFE', style: TextStyle(fontSize: 18)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    backgroundColor: const Color(0xFF067647),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSubmitting ? null : () => _handleResponse(SafetyStatus.needHelp),
                  icon: const Icon(Icons.medical_services_outlined, size: 28),
                  label: const Text('I NEED HELP', style: TextStyle(fontSize: 18)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    backgroundColor: const Color(0xFFB42318),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
              if (_isSubmitting)
                const Padding(
                  padding: EdgeInsets.only(top: 18),
                  child: Center(
                    child: Column(
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text('Getting your current location...'),
                      ],
                    ),
                  ),
                ),
              if (_locationError != null && !_isSubmitting)
                Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: Text(
                    _locationError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
