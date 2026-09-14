import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/ai_model_manager.dart';
import '../core/ai_model_background_service.dart';

class AIPackagesWidget extends StatefulWidget {
  const AIPackagesWidget({super.key});

  @override
  State<AIPackagesWidget> createState() => _AIPackagesWidgetState();
}

class _AIPackagesWidgetState extends State<AIPackagesWidget> {
  final AIModelManager _modelManager = AIModelManager();
  final Map<String, bool> _isInstalled = {};
  final Map<String, bool> _isDownloading = {};
  final Map<String, bool> _isPaused = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadStatus = {};
  bool _isInitialized = false;
  StreamSubscription<Map<String, dynamic>>? _bgSub;
  String? _pendingModelId;

  @override
  void initState() {
    super.initState();
    _listenToBackground();
    _initializeModels();
  }

  @override
  void dispose() {
    _bgSub?.cancel();
    super.dispose();
  }

  void _listenToBackground() {
    _bgSub?.cancel();
    _bgSub = AIModelBackgroundService.progressStream.listen((data) {
      if (!mounted) return;
      final modelId = data['modelId'] as String?;
      final progress = (data['progress'] as num?)?.toDouble();
      final status = data['status'] as String?;
      if (modelId == null || modelId.isEmpty) return;
      setState(() {
        _isDownloading[modelId] = status == 'downloading';
        _isPaused[modelId] = status == 'Paused';
        if (progress != null) _downloadProgress[modelId] = progress;
        if (status != null) _downloadStatus[modelId] = status;
        if (status == 'Installed' || status == 'Cancelled' || status == 'Failed') {
          _isDownloading[modelId] = false;
          _isPaused[modelId] = false;
        }
      });
      if (status == 'Installed' || status == 'Cancelled' || status == 'Failed') {
        _refreshStatus();
      }
    });
  }

  Future<void> _initializeModels() async {
    await AIModelBackgroundService.initialize();
    await AIModelBackgroundService.checkAndResumePending();
    final pending = await _modelManager.getPendingDownload();
    if (mounted) setState(() => _pendingModelId = pending);
    if (pending != null) {
      final canResume = await _modelManager.canResumeDownload(pending);
      if (mounted) {
        setState(() {
          _isDownloading[pending] = false;
          _isPaused[pending] = true;
          _downloadStatus[pending] = 'Paused';
        });
      }
    }
    await _refreshStatus();
    if (mounted) setState(() => _isInitialized = true);
  }

  Future<void> _refreshStatus() async {
    for (final model in _modelManager.availableModels) {
      _isInstalled[model.id] = await _modelManager.isModelInstalled(model.id);
      if (!(_isDownloading[model.id] ?? false)) {
        _downloadProgress[model.id] = _modelManager.getDownloadProgress(model.id);
        _downloadStatus[model.id] = _modelManager.getDownloadStatus(model.id);
      }
    }
    setState(() {});
  }

  Future<void> _downloadModel(AIModel model) async {
    setState(() {
      _isDownloading[model.id] = true;
      _isPaused[model.id] = false;
      _downloadProgress[model.id] = 0.0;
      _downloadStatus[model.id] = 'Starting...';
    });
    await AIModelBackgroundService.startDownload(model.id);
  }

  Future<void> _pauseDownload(AIModel model) async {
    await AIModelBackgroundService.pauseDownload();
    setState(() {
      _isDownloading[model.id] = false;
      _isPaused[model.id] = true;
      _downloadStatus[model.id] = 'Paused';
    });
  }

  Future<void> _resumeDownload(AIModel model) async {
    setState(() {
      _isDownloading[model.id] = true;
      _isPaused[model.id] = false;
      _downloadStatus[model.id] = 'Resuming...';
    });
    await AIModelBackgroundService.startDownload(model.id);
  }

  Future<void> _cancelDownload(AIModel model) async {
    await AIModelBackgroundService.cancelDownload();
    await _modelManager.cancelDownload(model.id);
    setState(() {
      _isDownloading[model.id] = false;
      _isPaused[model.id] = false;
    });
    await _refreshStatus();
  }

  Future<void> _deleteModel(AIModel model) async {
    final confirmed = await _showDeleteConfirmation(model);
    if (confirmed == true) {
      await _modelManager.deleteModel(model.id);
      await _refreshStatus();
    }
  }

  Future<bool?> _showDeleteConfirmation(AIModel model) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${model.name}?'),
        content: Text('This will free up ${model.sizeFormatted} of storage. Are you sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E17),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF1A2332),
                      const Color(0xFF0A0E17),
                    ],
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.psychology,
                        size: 64,
                        color: Colors.amber.withOpacity(0.9),
                      ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
                      const SizedBox(height: 16),
                      Text(
                        'AI PACKAGES',
                        style: GoogleFonts.orbitron(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.3),
                      const SizedBox(height: 8),
                      Text(
                        'Download AI models for offline features',
                        style: GoogleFonts.roboto(
                          fontSize: 14,
                          color: Colors.grey[400],
                        ),
                      ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: FutureBuilder(
              future: Future.wait([
                _modelManager.getTotalInstalledSize(),
                _modelManager.getTotalDownloadableSize(),
              ]),
              builder: (context, snapshot) {
                final installed = snapshot.data?[0] ?? 0;
                final downloadable = snapshot.data?[1] ?? 0;
                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF1A2332).withOpacity(0.8),
                        const Color(0xFF2D3A4A).withOpacity(0.6),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.amber.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        icon: Icons.check_circle,
                        label: 'Installed',
                        value: '$installed MB',
                        color: Colors.green,
                      ),
                      _buildStatItem(
                        icon: Icons.download,
                        label: 'Available',
                        value: '$downloadable MB',
                        color: Colors.amber,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: _isInitialized
                ? SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final model = _modelManager.availableModels[index];
                        return _ModelCard(
                          model: model,
                          isInstalled: _isInstalled[model.id] ?? false,
                          isDownloading: _isDownloading[model.id] ?? false,
                          isPaused: _isPaused[model.id] ?? false,
                          downloadProgress: _downloadProgress[model.id] ?? 0.0,
                          downloadStatus: _downloadStatus[model.id] ?? 'Not started',
                          onDownload: () => _downloadModel(model),
                          onPause: () => _pauseDownload(model),
                          onResume: () => _resumeDownload(model),
                          onCancel: () => _cancelDownload(model),
                          onDelete: () => _deleteModel(model),
                        ).animate().fadeIn(delay: (index * 100).ms, duration: 400.ms).slideX();
                      },
                      childCount: _modelManager.availableModels.length,
                    ),
                  )
                : SliverToBoxAdapter(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: Colors.amber),
                          const SizedBox(height: 16),
                          Text(
                            'Checking model status...',
                            style: GoogleFonts.roboto(color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(value, style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[400])),
      ],
    );
  }
}

class _ModelCard extends StatelessWidget {
  final AIModel model;
  final bool isInstalled;
  final bool isDownloading;
  final bool isPaused;
  final double downloadProgress;
  final String downloadStatus;
  final VoidCallback onDownload;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _ModelCard({
    required this.model,
    required this.isInstalled,
    required this.isDownloading,
    required this.isPaused,
    required this.downloadProgress,
    required this.downloadStatus,
    required this.onDownload,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A2332).withOpacity(0.9),
            const Color(0xFF0F1623).withOpacity(0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: model.isMandatory
              ? Colors.amber.withOpacity(0.5)
              : Colors.blue.withOpacity(0.3),
          width: model.isMandatory ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (model.isMandatory ? Colors.amber : Colors.blue).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: model.isMandatory
                          ? [Colors.amber.withOpacity(0.3), Colors.orange.withOpacity(0.2)]
                          : [Colors.blue.withOpacity(0.3), Colors.cyan.withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(child: Text(model.iconEmoji, style: const TextStyle(fontSize: 28))),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(model.name,
                                style: GoogleFonts.roboto(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                overflow: TextOverflow.ellipsis),
                          ),
                          if (model.isMandatory) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.amber.withOpacity(0.5)),
                              ),
                              child: Text('REQUIRED',
                                  style: GoogleFonts.roboto(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber, letterSpacing: 1)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(model.description,
                          style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[400]),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.storage, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(model.sizeFormatted,
                              style: GoogleFonts.roboto(fontSize: 12, color: Colors.grey[500])),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (isDownloading) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: downloadProgress,
                      backgroundColor: Colors.grey[800],
                      valueColor: AlwaysStoppedAnimation<Color>(
                        model.isMandatory ? Colors.amber : Colors.blue,
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(downloadStatus,
                          style: GoogleFonts.roboto(fontSize: 11, color: Colors.grey[400])),
                      Text('${(downloadProgress * 100).toStringAsFixed(1)}%',
                          style: GoogleFonts.roboto(fontSize: 12, fontWeight: FontWeight.bold,
                              color: model.isMandatory ? Colors.amber : Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildActionButton(),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildActionButton() {
    if (isDownloading) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onPause,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.withOpacity(0.2),
                  foregroundColor: Colors.orange,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pause, size: 20),
                    const SizedBox(width: 8),
                    Text('PAUSE', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48, height: 48,
            child: ElevatedButton(
              onPressed: onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.red.withOpacity(0.5)),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.close, size: 20),
            ),
          ),
        ],
      );
    }

    if (isPaused) {
      return Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onResume,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.2),
                  foregroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.green.withOpacity(0.5)),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.play_arrow, size: 20),
                    const SizedBox(width: 8),
                    Text('RESUME', style: GoogleFonts.roboto(fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 48, height: 48,
            child: ElevatedButton(
              onPressed: onCancel,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.withOpacity(0.2),
                foregroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: Colors.red.withOpacity(0.5)),
                ),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.delete_outline, size: 20),
            ),
          ),
        ],
      );
    }

    if (isInstalled) {
      return Row(
        children: [
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text('INSTALLED',
                      style: GoogleFonts.roboto(fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1)),
                ],
              ),
            ),
          ),
          if (!model.isMandatory) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: 48, height: 48,
              child: ElevatedButton(
                onPressed: onDelete,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.2),
                  foregroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.red.withOpacity(0.5)),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.delete_outline),
              ),
            ),
          ],
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onDownload,
        style: ElevatedButton.styleFrom(
          backgroundColor: model.isMandatory
              ? Colors.amber.withOpacity(0.2)
              : Colors.blue.withOpacity(0.2),
          foregroundColor: model.isMandatory ? Colors.amber : Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: model.isMandatory
                  ? Colors.amber.withOpacity(0.5)
                  : Colors.blue.withOpacity(0.5),
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(model.isMandatory ? Icons.download : Icons.add_circle_outline, size: 20),
            const SizedBox(width: 8),
            Text(model.isMandatory ? 'INSTALL NOW' : 'DOWNLOAD',
                style: GoogleFonts.roboto(fontWeight: FontWeight.bold, letterSpacing: 1)),
          ],
        ),
      ),
    );
  }
}
