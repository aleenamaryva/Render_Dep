import 'package:flutter/material.dart';

import '../../app.dart';
import '../../models/disaster_alert.dart';
import '../../models/disaster_response.dart';
import '../../services/app_session.dart';
import '../../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    if (AppSession.apiService.accessToken != null &&
        AppSession.apiService.accessToken!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refresh();
      });
    }
  }

  Future<void> _refresh() async {
    await AppSession.syncUserResponses();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = AppSession.currentUser ?? AppSession.authService.currentUser;
    final status = AppSession.currentStatus;
    final alert = AppSession.activeAlert ?? DisasterAlert.sample();
    final latestResponse = AppSession.responseService.getLatestResponse();

    final permissionStatus = AppSession.locationService.checkPermission();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.profile),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      const Text(
                        'Citizen Profile',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        user?.fullName ?? 'Citizen',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Current status: ${status.label}'),
                      const SizedBox(height: 6),
                      FutureBuilder<LocationPermissionStatus>(
                        future: permissionStatus,
                        builder: (context, snapshot) {
                          final permissionLabel = snapshot.data ?? LocationPermissionStatus.denied;
                          return Text(
                            'Location permission: ${permissionLabel.name.toUpperCase()}',
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 22),
              _LatestResponseSection(response: latestResponse),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pushNamed(AppRoutes.responseHistory),
                  icon: const Icon(Icons.history),
                  label: const Text('Response History'),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Disaster Alert',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              if (AppSession.activeAlert != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                            const SizedBox(width: 8),
                            Text(
                              alert.type,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(alert.description),
                        const SizedBox(height: 12),
                        _InfoRow(label: 'Location', value: alert.location),
                        _InfoRow(
                          label: 'Alert time',
                          value: '${alert.alertTime.day}/${alert.alertTime.month}/${alert.alertTime.year} ${alert.alertTime.hour}:${alert.alertTime.minute.toString().padLeft(2, '0')}',
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(alert.emergencyInstructions),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () => Navigator.of(context).pushNamed(AppRoutes.disasterAlert),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: const Text('View Alert Details'),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('No active disaster alert'),
                  ),
                ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class _LatestResponseSection extends StatelessWidget {
  final DisasterResponse? response;

  const _LatestResponseSection({required this.response});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: response == null
            ? const Text('No disaster responses yet.')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Latest Response',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Text('Current Response: ${response!.status.label}'),
                  Text('Last Response: ${_formatDateTime(response!.timestamp)}'),
                  Text('Latitude: ${response!.latitude.toStringAsFixed(6)}'),
                  Text('Longitude: ${response!.longitude.toStringAsFixed(6)}'),
                ],
              ),
      ),
    );
  }
}

String _formatDateTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '${dateTime.day} ${_monthName(dateTime.month)} ${dateTime.year}, $hour:$minute $period';
}

String _monthName(int month) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return months[month - 1];
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}
