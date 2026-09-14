import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../core/theme.dart';
import '../models/book_models.dart';
import '../services/library_service.dart';
import '../services/library_download_service.dart';
import '../services/library_ad_service.dart';
import '../widgets/library_ad_overlay.dart';
import 'book_comments_screen.dart';
import 'channel_profile_screen.dart';

class LibraryTiktokPlayerScreen extends StatefulWidget {
  final Book book;

  const LibraryTiktokPlayerScreen({super.key, required this.book});

  @override
  State<LibraryTiktokPlayerScreen> createState() => _LibraryTiktokPlayerScreenState();
}

class _LibraryTiktokPlayerScreenState extends State<LibraryTiktokPlayerScreen> {
  late Book _book;
  String? _localPath;
  bool _loadingFile = true;
  bool _fullScreen = false;
  bool _isDownloaded = false;
  bool _isDownloading = false;

  @override
  void initState() {
    super.initState();
    _book = widget.book;
    _checkDownloaded();
    _initialize();
  }

  Future<void> _checkDownloaded() async {
    final downloaded = await LibraryDownloadService.isBookDownloaded(_book.id);
    if (mounted) setState(() => _isDownloaded = downloaded);
  }

  @override
  void dispose() {
    LibraryAdService.cancelDwellTimer();
    super.dispose();
  }

  Future<void> _initialize() async {
    if (_book.fileUrl.isNotEmpty) {
      final file = File(_book.fileUrl);
      if (await file.exists()) {
        setState(() { _localPath = _book.fileUrl; _loadingFile = false; });
        return;
      }
    }

    if (_book.monetizationType == 'ads_only' || _book.monetizationType == 'user_decision') {
      await LibraryAdService.showRewardAd(context);
    }

    LibraryAdService.startDwellTimer(_book.id, (views) {
      if (mounted) setState(() => _book = _book.copyWith(viewsCount: views));
    });

    try {
      final downloadUrl = _book.absoluteFileUrl;
      if (downloadUrl.startsWith("http://") || downloadUrl.startsWith("https://")) {
        final response = await http.get(Uri.parse(downloadUrl));
        if (response.statusCode == 200) {
          final ext = _book.resolvedExt.isNotEmpty ? _book.resolvedExt : 'pdf';
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/${_book.id}.$ext');
          await tempFile.writeAsBytes(response.bodyBytes);
          if (!mounted) return;
          setState(() { _localPath = tempFile.path; _loadingFile = false; });
          return;
        }
      }
      if (!mounted) return;
      setState(() { _localPath = downloadUrl; _loadingFile = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingFile = false);
    }
  }

  Future<void> _handleLike() async {
    try {
      final res = await LibraryService.toggleLike(_book.id);
      setState(() => _book = _book.copyWith(likesCount: res['likes'], dislikesCount: res['dislikes'], userLiked: res['user_liked'], userDisliked: false));
    } catch (_) {}
  }

  Future<void> _handleDislike() async {
    try {
      final res = await LibraryService.toggleDislike(_book.id);
      setState(() => _book = _book.copyWith(likesCount: res['likes'], dislikesCount: res['dislikes'], userLiked: false, userDisliked: res['user_disliked']));
    } catch (_) {}
  }

  Future<void> _handleSave() async {
    try {
      final res = await LibraryService.toggleSave(_book.id);
      setState(() => _book = _book.copyWith(userSaved: res['saved']));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(res['saved'] ? "Saved to bookmarks" : "Removed from bookmarks"),
          duration: const Duration(seconds: 1), behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {}
  }

  Future<void> _handleReport() async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Report Content", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: TextField(controller: reasonCtrl, decoration: const InputDecoration(hintText: "Reason for report...")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Report")),
        ],
      ),
    );
    if (confirm == true && reasonCtrl.text.trim().isNotEmpty) {
      try {
        final res = await LibraryService.reportBook(_book.id, reasonCtrl.text.trim());
        setState(() => _book = _book.copyWith(reportsCount: res['reports_count'], userReported: true));
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Content reported")));
      } catch (_) {}
    }
  }

  Future<void> _handleDownload() async {
    try {
      final access = await LibraryService.getBookAccess(_book.id);
      if (access['can_download'] != true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Download not allowed for this document"),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Could not verify download permissions"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
      return;
    }

    setState(() => _isDownloading = true);
    try {
      await LibraryDownloadService.downloadAndSaveBook(_book);
      if (!mounted) return;
      setState(() { _isDownloading = false; _isDownloaded = true; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Downloaded '${_book.title}' successfully! Available offline."),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDownloading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Download failed: $e"),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Widget _buildContent() {
    if (_loadingFile) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }
    if (_localPath == null) {
      return const Center(child: Text("Could not load content", style: TextStyle(color: Colors.white)));
    }

    if (_book.fileKind == 'image') {
      return InteractiveViewer(
        child: Center(
          child: Image.file(File(_localPath!), fit: BoxFit.contain, errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white54, size: 64)),
        ),
      );
    }

    if (_book.resolvedExt == 'pdf') {
      return SfPdfViewer.file(File(_localPath!), enableDoubleTapZooming: true);
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_fileKindIcon, color: Colors.white54, size: 80),
          const SizedBox(height: 16),
          Text(_book.fileName, style: const TextStyle(color: Colors.white70, fontSize: 13), textAlign: TextAlign.center),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _openInBrowser(),
            icon: const Icon(Icons.open_in_browser, size: 16),
            label: const Text("Open in Browser"),
            style: ElevatedButton.styleFrom(backgroundColor: StarlightTheme.primaryBlue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  IconData get _fileKindIcon {
    switch (_book.fileKind) {
      case 'spreadsheet': return Icons.table_chart_rounded;
      case 'presentation': return Icons.slideshow_rounded;
      case 'audio': return Icons.audiotrack_rounded;
      case 'archive': return Icons.folder_zip_rounded;
      case 'document': return _book.resolvedExt == 'pdf' ? Icons.picture_as_pdf_rounded : Icons.article_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  Future<void> _openInBrowser() async {
    final url = _book.absoluteFileUrl;
    if (url.startsWith("http://") || url.startsWith("https://")) {
      try {
        final uri = Uri.parse(url);
        final process = await Process.run('start', [uri.toString()], runInShell: true);
        if (process.exitCode != 0) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not open in browser")));
        }
      } catch (_) {}
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("File URL not available")));
    }
  }

  String get _docTypeLabel {
    if (_book.docType == 'note') return 'NOTE';
    switch (_book.fileKind) {
      case 'image': return 'IMAGE';
      case 'spreadsheet': return 'SHEET';
      case 'presentation': return 'SLIDES';
      case 'audio': return 'AUDIO';
      case 'archive': return 'ARCHIVE';
      default: return 'DOCUMENT';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LibraryAdOverlay(
        bookId: _book.id,
        showAds: _book.monetizationType == 'ads_only' || _book.monetizationType == 'user_decision',
        child: Stack(
          children: [
            _buildContent(),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 8,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
                onPressed: () => Navigator.pop(context, _book),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 8,
              child: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: Icon(_fullScreen ? Icons.fullscreen_exit : Icons.fullscreen, color: Colors.white, size: 22),
                ),
                onPressed: () => setState(() => _fullScreen = !_fullScreen),
              ),
            ),
            Positioned(
              bottom: 40,
              right: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChannelProfileScreen(channelId: _book.channelId))),
                    child: Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white, width: 2), shape: BoxShape.circle),
                      child: CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.orange,
                        child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _actionBtn(Icons.thumb_up_rounded, Icons.thumb_up_outlined, _book.userLiked, "${_book.likesCount}", _book.userLiked ? Colors.orange : Colors.white, _handleLike),
                  _actionBtn(Icons.thumb_down_rounded, Icons.thumb_down_alt_outlined, _book.userDisliked, "${_book.dislikesCount}", _book.userDisliked ? Colors.red : Colors.white, _handleDislike),
                  _actionBtn(Icons.bookmark_rounded, Icons.bookmark_outline_rounded, _book.userSaved, _book.userSaved ? "Saved" : "Save", _book.userSaved ? Colors.orange : Colors.white, _handleSave),
                  _actionBtn(Icons.download_rounded, Icons.download_outlined, _isDownloaded, _isDownloaded ? "Got it" : (_isDownloading ? "..." : "Save"), _isDownloaded ? Colors.green : Colors.white, _isDownloading ? null : (_isDownloaded ? null : _handleDownload)),
                  _actionBtn(Icons.comment_rounded, Icons.comment_rounded, false, "Review", Colors.white, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => BookCommentsScreen(book: _book)));
                  }),
                  _actionBtn(Icons.flag_rounded, Icons.flag_outlined, _book.userReported, "Report", _book.userReported ? Colors.red : Colors.white, _book.userReported ? null : _handleReport),
                ],
              ),
            ),
            Positioned(
              bottom: 40,
              left: 16,
              right: 80,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.black.withOpacity(0.5), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(8)),
                          child: Text(_docTypeLabel, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        Text("👁️ ${_book.viewsCount} views", style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(_book.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white), maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Text("Topic: ${_book.topic} | By ${_book.author}", style: const TextStyle(fontSize: 10, color: Colors.white70)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(IconData filledIcon, IconData outlinedIcon, bool active, String label, Color color, VoidCallback? onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: Colors.black.withOpacity(0.6),
              child: Icon(active ? filledIcon : outlinedIcon, color: color, size: 20),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 4)])),
          ],
        ),
      ),
    );
  }
}
