import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:starlight_flutter/core/theme.dart';
import '../models/ingestion_models.dart';
import '../services/ingestion_service.dart';
import '../widgets/common.dart';
import 'sources_tab.dart';
import 'events_tab.dart';
import 'subscribers_tab.dart';
import 'status_tab.dart';
import 'cloud_sources_screen.dart';

/// 🏛️ Top-level screen for the External Event-Stream Ingestion console.
///
/// A gradient header summarizes live system stats; the tab bar switches
/// between Sources, Events, Subscribers and System Status.
class IngestionDashboardScreen extends StatefulWidget {
  const IngestionDashboardScreen({super.key});

  @override
  State<IngestionDashboardScreen> createState() =>
      _IngestionDashboardScreenState();
}

class _IngestionDashboardScreenState extends State<IngestionDashboardScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final _svc = IngestionService.instance;
  IngestionStatus? _status;
  int _sourceCount = 0;
  int _subscriberCount = 0;
  bool _loadingHeader = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _loadHeader();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHeader() async {
    try {
      final results = await Future.wait([
        _svc.getStatus(),
        _svc.listSources(),
        _svc.listSubscribers(),
      ]);
      _status = results[0] as IngestionStatus;
      _sourceCount = (results[1] as List<IngestionSource>).length;
      _subscriberCount = (results[2] as List<AlertSubscriber>).length;
    } catch (_) {
      _status = null;
    } finally {
      if (mounted) setState(() => _loadingHeader = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                SourcesTab(),
                EventsTab(),
                SubscribersTab(),
                StatusTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final st = _status;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [StarlightTheme.primaryBlue, StarlightTheme.secondaryBlack],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.sensors_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Event Ingestion',
                      style: GoogleFonts.poppins(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      'External stream & webhook console',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.78),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.cloud_rounded, color: Colors.white),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CloudSourcesScreen()),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                onPressed: () {
                  _loadHeader();
                  showIngestionToast(context, 'Refreshing…');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          _loadingHeader
              ? const SizedBox(
                  height: 54,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
                  : Row(
                      children: [
                        _MiniStat(
                          label: 'Sources',
                          value: '$_sourceCount',
                        ),
                        _MiniStat(
                          label: 'Events',
                          value: '${st?.storedEvents ?? 0}',
                        ),
                        _MiniStat(
                          label: 'Workers',
                          value: '${st?.activeWorkers ?? 0}',
                          danger: true,
                        ),
                        _MiniStat(
                          label: 'Alerts',
                          value: '$_subscriberCount',
                        ),
                      ],
                    ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFECEEF2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        indicatorColor: const Color(0xFF1A237E),
        indicatorWeight: 3,
        labelColor: const Color(0xFF1A237E),
        unselectedLabelColor: const Color(0xFF8A8F98),
        labelStyle:
            GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600),
        tabs: const [
          Tab(text: 'Sources'),
          Tab(text: 'Events'),
          Tab(text: 'Subscribers'),
          Tab(text: 'Status'),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final bool danger;
  const _MiniStat({
    required this.label,
    required this.value,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: danger ? const Color(0xFFFFCDD2) : Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
