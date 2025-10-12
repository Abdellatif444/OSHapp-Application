import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:provider/provider.dart';

class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key});

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  late final ApiService _apiService;
  final ScrollController _scrollController = ScrollController();

  List<dynamic> _logs = [];
  int _currentPage = 0;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _apiService = Provider.of<ApiService>(context, listen: false);
    _fetchLogs();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.95 &&
        !_isLoading) {
      _fetchLogs();
    }
  }

  Future<void> _fetchLogs() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
      if (_logs.isEmpty) _error = null; // Reset error on initial load
    });

    try {
      final newLogs = await _apiService.getAuditLogs(page: _currentPage);

      setState(() {
        if (newLogs.isNotEmpty) {
          _logs.addAll(newLogs);
          _currentPage++;
        } else {
          _hasMore = false; // No more logs to fetch
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Erreur de chargement des logs: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique des Actions'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_logs.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }

    if (_logs.isEmpty) {
      return const Center(child: Text('Aucun historique à afficher.'));
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {
          _logs = [];
          _currentPage = 0;
          _hasMore = true;
        });
        await _fetchLogs();
      },
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _logs.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _logs.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final logEntry = _logs[index];
          final timestamp = DateTime.parse(logEntry['timestamp']);
          final formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss', 'fr_FR').format(timestamp);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              leading: Icon(_getIconForAction(logEntry['action'])),
              title: Text(logEntry['action'] ?? 'Action inconnue'),
              subtitle: Text('Par ${logEntry['username'] ?? 'N/A'} le $formattedDate'),
              isThreeLine: (logEntry['details'] != null && logEntry['details'].isNotEmpty),
              dense: true,
            ),
          );
        },
      ),
    );
  }

  IconData _getIconForAction(String? action) {
    if (action == null) return Icons.help_outline;
    if (action.toLowerCase().contains('créé')) return Icons.add_circle_outline;
    if (action.toLowerCase().contains('supprimé')) return Icons.remove_circle_outline;
    if (action.toLowerCase().contains('modifié')) return Icons.edit_outlined;
    if (action.toLowerCase().contains('validé')) return Icons.check_circle_outline;
    if (action.toLowerCase().contains('login')) return Icons.login;
    if (action.toLowerCase().contains('logout')) return Icons.logout;
    return Icons.history;
  }
}
