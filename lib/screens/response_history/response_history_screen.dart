import 'package:flutter/material.dart';

import '../../models/disaster_response.dart';
import '../../services/app_session.dart';

class ResponseHistoryScreen extends StatefulWidget {
  const ResponseHistoryScreen({super.key});

  @override
  State<ResponseHistoryScreen> createState() => _ResponseHistoryScreenState();
}

class _ResponseHistoryScreenState extends State<ResponseHistoryScreen> {
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (AppSession.apiService.accessToken != null &&
        AppSession.apiService.accessToken!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadResponses();
      });
    }
  }

  Future<void> _loadResponses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    await AppSession.syncUserResponses();
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final responses = AppSession.responseService.getAllResponses();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Response History'),
      ),
      body: _isLoading && responses.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadResponses,
              child: responses.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('No disaster responses yet.')),
                      ],
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: responses.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _ResponseCard(response: responses[index]);
                      },
                    ),
            ),
    );
  }
}

class _ResponseCard extends StatelessWidget {
  final DisasterResponse response;

  const _ResponseCard({required this.response});

  @override
  Widget build(BuildContext context) {
    final isSafe = response.status == SafetyStatus.safe;
    final color = isSafe ? const Color(0xFF067647) : const Color(0xFFB42318);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isSafe ? Icons.check_circle_outline : Icons.medical_services_outlined,
                  color: color,
                ),
                const SizedBox(width: 8),
                Text(
                  response.status.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Date: ${_formatDate(response.timestamp)}'),
            Text('Time: ${_formatTime(response.timestamp)}'),
            Text('Latitude: ${response.latitude.toStringAsFixed(6)}'),
            Text('Longitude: ${response.longitude.toStringAsFixed(6)}'),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime dateTime) {
  return '${dateTime.day} ${_monthName(dateTime.month)} ${dateTime.year}';
}

String _formatTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final period = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
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
