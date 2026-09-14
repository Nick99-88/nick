import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/constants.dart';
import '../../services/social/browser_service.dart';

class VaultBrowserScreen extends StatefulWidget {
  final String? initialUrl;
  final String? initialHtml;

  const VaultBrowserScreen({
    super.key,
    this.initialUrl,
    this.initialHtml,
  });

  @override
  VaultBrowserScreenState createState() => VaultBrowserScreenState();
}

class BrowserTab {
  final String id;
  String title;
  String url;
  double progress;
  bool isLoading;

  BrowserTab({
    required this.id,
    this.title = 'New Tab',
    this.url = '',
    this.progress = 0.0,
    this.isLoading = false,
  });
}

class VaultBrowserScreenState extends State<VaultBrowserScreen>
    with TickerProviderStateMixin {
  InAppWebViewController? _controller;
  final TextEditingController _urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  final Dio _dio = Dio();
  final ScrollController _tabScrollController = ScrollController();

  // Tabs
  final List<BrowserTab> _tabs = [];
  int _activeTabIndex = 0;

  // WebView State
  double _progress = 0.0;
  bool _isLoading = false;
  bool _canGoBack = false;
  bool _canGoForward = false;
  double _downloadProgress = 0.0;
  String _currentUrl = '';
  String? _downloadFileName;
  String _pageTitle = '';
  bool _isBookmarked = false;
  bool _isUrlFocused = false;
  bool _desktopMode = false;
  bool _showFindInPage = false;
  final TextEditingController _findController = TextEditingController();
  String _findText = '';
  int _findResultCount = 0;
  int _findActiveMatch = 0;
  void Function(void Function())? _updateDownloadDialog;

  // Data
  List<Map<String, String>> _bookmarks = [];
  List<Map<String, String>> _history = [];
  final BrowserService _browserService = BrowserService();
  String? _pendingInitialUrl;

  // Find in Page
  late FindInteractionController _findInteractionController;

  // Animation
  late AnimationController _omniboxAnimController;

  @override
  void initState() {
    super.initState();
    _urlFocusNode.addListener(_onUrlFocusChange);
    _omniboxAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _findInteractionController = FindInteractionController();
    _createNewTab(url: widget.initialUrl ?? 'starlight.institution.site');
    _loadBookmarks();
    _loadHistory();
    if (widget.initialHtml != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        loadServerString(widget.initialHtml!);
      });
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _urlFocusNode.dispose();
    _findController.dispose();
    _tabScrollController.dispose();
    _omniboxAnimController.dispose();
    super.dispose();
  }

  void _onUrlFocusChange() {
    if (mounted) {
      setState(() => _isUrlFocused = _urlFocusNode.hasFocus);
      if (_urlFocusNode.hasFocus) {
        _omniboxAnimController.forward();
        _urlController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _urlController.text.length,
        );
      } else {
        _omniboxAnimController.reverse();
      }
    }
  }

  // ─── Tab Management ───────────────────────────────────────

  void _createNewTab({String url = ''}) {
    final tab = BrowserTab(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    _tabs.add(tab);
    setState(() {
      _activeTabIndex = _tabs.length - 1;
      _currentUrl = url;
      _urlController.text = url;
      _pageTitle = 'New Tab';
      _isLoading = false;
      _progress = 0.0;
    });
    if (url.isNotEmpty) {
      if (_controller != null) {
        navigateToUrl(url);
      } else if (widget.initialUrl == null && widget.initialHtml == null) {
        _pendingInitialUrl = url;
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToLastTab();
    });
  }

  void _closeTab(int index) {
    if (_tabs.length <= 1) {
      _createNewTab();
    }
    setState(() {
      _tabs.removeAt(index);
      if (_activeTabIndex >= _tabs.length) {
        _activeTabIndex = _tabs.length - 1;
      }
      final activeTab = _tabs[_activeTabIndex];
      if (activeTab.url.isNotEmpty) {
        navigateToUrl(activeTab.url);
      } else {
        _currentUrl = '';
        _urlController.clear();
        _pageTitle = 'New Tab';
      }
    });
  }

  void _switchTab(int index) {
    if (index == _activeTabIndex) return;
    setState(() {
      _activeTabIndex = index;
      final tab = _tabs[index];
      _currentUrl = tab.url;
      _urlController.text = tab.url;
      _pageTitle = tab.title;
      _isLoading = tab.isLoading;
      _progress = tab.progress;
      _isBookmarked = _bookmarks.any((b) => b['url'] == tab.url);
    });
    if (_tabs[index].url.isNotEmpty) {
      navigateToUrl(_tabs[index].url);
    }
  }

  void _scrollToLastTab() {
    if (_tabScrollController.hasClients) {
      _tabScrollController.animateTo(
        _tabScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  // ─── Bookmarks & History ──────────────────────────────────

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('browser_bookmarks');
    if (data != null) {
      setState(() {
        _bookmarks = List<Map<String, String>>.from(
          (jsonDecode(data) as List).map((e) => Map<String, String>.from(e)),
        );
        _checkBookmarkStatus();
      });
    }
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('browser_bookmarks', jsonEncode(_bookmarks));
    _checkBookmarkStatus();
  }

  void _checkBookmarkStatus() {
    if (mounted) {
      setState(() => _isBookmarked = _bookmarks.any((b) => b['url'] == _currentUrl));
    }
  }

  void _toggleBookmark() {
    if (_currentUrl.isEmpty) return;
    if (_isBookmarked) {
      _bookmarks.removeWhere((b) => b['url'] == _currentUrl);
    } else {
      _bookmarks.insert(0, {
        'title': _pageTitle.isNotEmpty ? _pageTitle : _currentUrl,
        'url': _currentUrl,
      });
    }
    _saveBookmarks();
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isBookmarked ? 'Bookmark added' : 'Bookmark removed'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
          width: 200,
        ),
      );
    }
  }

  Future<void> _loadHistory() async {
    final history = await _browserService.getHistory();
    if (mounted) {
      setState(() => _history = history);
    }
  }

  Future<void> _addToHistory(String url, String title) async {
    if (url.isEmpty || url == 'about:blank') return;
    if (url.contains('starlight.institution.site')) return;
    if (url.contains('google.com/search')) return;
    _browserService.addHistory(url, title);
    setState(() {
      _history.removeWhere((h) => h['url'] == url);
      _history.insert(0, {
        'title': title.isNotEmpty ? title : url,
        'url': url,
        'time': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<void> _clearHistory() async {
    await _browserService.clearHistory();
    setState(() => _history.clear());
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('History cleared'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
          width: 200,
        ),
      );
    }
  }

  // ─── Navigation ───────────────────────────────────────────

  Future<void> loadServerString(String htmlContent) async {
    await _controller?.loadData(
      data: htmlContent,
      mimeType: 'text/html',
      encoding: 'utf8',
    );
  }

  static String _resolveUrl(String url) {
    final pattern = RegExp(r'^starlight\.project\.(.+)\.html$');
    final match = pattern.firstMatch(url.trim().toLowerCase());
    if (match != null) {
      final name = match.group(1)!;
      return '${StarlightConstants.apiBaseUrl}/platform/websites/$name/render';
    }
    return url;
  }

  void navigateToUrl(String url) {
    _navigateToUrl(url);
  }

  void _navigateToUrl(String url) {
    if (url.isEmpty) return;
    url = _resolveUrl(url);
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      if (url.contains('.') && !url.contains(' ')) {
        url = 'https://$url';
      } else {
        url = 'https://www.google.com/search?q=${Uri.encodeComponent(url)}';
      }
    }
    _controller?.loadUrl(
      urlRequest: URLRequest(url: WebUri(url)),
    );
    FocusScope.of(context).unfocus();
  }

  void _updateNavState() async {
    if (_controller == null) return;
    final back = await _controller!.canGoBack();
    final forward = await _controller!.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
  }

  // ─── Downloads ────────────────────────────────────────────

  void _onDownloadStart(
      InAppWebViewController controller, DownloadStartRequest request) async {
    final fileName = request.suggestedFilename ??
        'download_${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _downloadProgress = 0.0;
      _downloadFileName = fileName;
    });

    if (!mounted) return;
    _showDownloadProgressDialog();

    var status = await Permission.storage.request();
    if (!status.isGranted && !status.isPermanentlyDenied) {
      status = await Permission.manageExternalStorage.request();
    }

    if (!status.isGranted) {
      if (mounted) {
        _updateDownloadDialog = null;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Storage permission denied. Cannot download file.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    try {
      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/$fileName';

      await _dio.download(
        request.url.toString(),
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1 && mounted) {
            setState(() => _downloadProgress = received / total);
            _updateDownloadDialog?.call(() {});
          }
        },
      );

      if (mounted) {
        _updateDownloadDialog = null;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download complete: $fileName'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        _updateDownloadDialog = null;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        _updateDownloadDialog = null;
      }
    }
  }

  void _showDownloadProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            _updateDownloadDialog = setDialogState;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _updateDownloadDialog ??= setDialogState;
            });
            return AlertDialog(
              backgroundColor: const Color(0xFF161B22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Downloading',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _downloadFileName ?? 'file',
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: _downloadProgress,
                      minHeight: 6,
                      backgroundColor: const Color(0xFF21262D),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF58A6FF)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF58A6FF),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── Find in Page ─────────────────────────────────────────

  void _toggleFindInPage() {
    setState(() {
      _showFindInPage = !_showFindInPage;
      if (!_showFindInPage) {
        _findController.clear();
        _findText = '';
        _findResultCount = 0;
        _findActiveMatch = 0;
        _findInteractionController.clearMatches();
      }
    });
    if (_showFindInPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_findFocusNode);
      });
    }
  }

  final FocusNode _findFocusNode = FocusNode();

  void _onFindTextChanged(String value) {
    _findText = value;
    if (value.isNotEmpty) {
      _findInteractionController.findAll(find: value);
    } else {
      _findInteractionController.clearMatches();
      setState(() {
        _findResultCount = 0;
        _findActiveMatch = 0;
      });
    }
  }

  void _findNext() {
    if (_findText.isNotEmpty) {
      _findInteractionController.findNext(forward: true);
    }
  }

  void _findPrevious() {
    if (_findText.isNotEmpty) {
      _findInteractionController.findNext(forward: false);
    }
  }

  // ─── Share ────────────────────────────────────────────────

  void _shareUrl() {
    if (_currentUrl.isNotEmpty) {
      SharePlus.instance.share(
        ShareParams(
          text: _pageTitle.isNotEmpty ? '$_pageTitle\n$_currentUrl' : _currentUrl,
        ),
      );
    }
  }

  // ─── Menus ────────────────────────────────────────────────

  void _showBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Bookmarks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_bookmarks.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _bookmarks.clear();
                            _saveBookmarks();
                            setSheetState(() {});
                          },
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Color(0xFF58A6FF)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _bookmarks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.bookmark_border,
                                    size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 12),
                                Text(
                                  'No bookmarks yet',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _bookmarks.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Color(0xFF21262D)),
                            itemBuilder: (_, i) {
                              final b = _bookmarks[i];
                              return ListTile(
                                leading: _bookmarkIcon(b['url'] ?? ''),
                                title: Text(
                                  b['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  b['url'] ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close,
                                      color: Colors.grey, size: 18),
                                  onPressed: () {
                                    _bookmarks.removeAt(i);
                                    _saveBookmarks();
                                    setSheetState(() {});
                                  },
                                ),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  final url = b['url'] ?? '';
                                  _urlController.text = url;
                                  navigateToUrl(url);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showHistorySheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.6,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'History',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_history.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            _clearHistory();
                            setSheetState(() {});
                          },
                          child: const Text(
                            'Clear All',
                            style: TextStyle(color: Color(0xFF58A6FF)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _history.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history,
                                    size: 48, color: Colors.grey[600]),
                                const SizedBox(height: 12),
                                Text(
                                  'No history yet',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _history.length,
                            separatorBuilder: (_, __) =>
                                const Divider(color: Color(0xFF21262D)),
                            itemBuilder: (_, i) {
                              final h = _history[i];
                              final time = h['time'] != null
                                  ? DateTime.tryParse(h['time']!)
                                  : null;
                              return ListTile(
                                leading: _bookmarkIcon(h['url'] ?? ''),
                                title: Text(
                                  h['title'] ?? '',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  h['url'] ?? '',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                trailing: time != null
                                    ? Text(
                                        '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                                        style:
                                            TextStyle(color: Colors.grey[600], fontSize: 11),
                                      )
                                    : null,
                                onTap: () {
                                  Navigator.pop(ctx);
                                  final url = h['url'] ?? '';
                                  _urlController.text = url;
                                  navigateToUrl(url);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _bookmarkIcon(String url) {
    final isHttps = url.startsWith('https');
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isHttps
            ? const Color(0xFF0D4429)
            : const Color(0xFF442D0D),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        isHttps ? Icons.lock : Icons.language,
        color: isHttps ? const Color(0xFF3FB950) : const Color(0xFFD29922),
        size: 16,
      ),
    );
  }

  void _showOverflowMenu() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(
          Offset(overlay.size.width - 220, button.size.height),
          Offset(overlay.size.width - 20, button.size.height),
        ),
        Offset.zero & overlay.size,
      ),
      color: const Color(0xFF161B22),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFF30363D)),
      ),
      items: [
        const PopupMenuItem(
          value: 'new_tab',
          child: _MenuItemRow(Icons.tab, 'New Tab'),
        ),
        const PopupMenuItem(
          value: 'incognito',
          child: _MenuItemRow(Icons.vpn_key, 'New Incognito Tab'),
        ),
        const PopupMenuDivider(height: 1,),
        const PopupMenuItem(
          value: 'bookmarks',
          child: _MenuItemRow(Icons.bookmarks, 'Bookmarks'),
        ),
        const PopupMenuItem(
          value: 'history',
          child: _MenuItemRow(Icons.history, 'History'),
        ),
        const PopupMenuItem(
          value: 'downloads',
          child: _MenuItemRow(Icons.download, 'Downloads'),
        ),
        const PopupMenuDivider(height: 1,),
        const PopupMenuItem(
          value: 'share',
          child: _MenuItemRow(Icons.share, 'Share'),
        ),
        const PopupMenuItem(
          value: 'find',
          child: _MenuItemRow(Icons.find_in_page, 'Find in Page'),
        ),
        PopupMenuItem(
          value: 'desktop',
          child: _MenuItemRow(
            Icons.desktop_windows,
            'Desktop Site',
            trailing: SizedBox(
              height: 20,
              width: 36,
              child: Switch.adaptive(
                value: _desktopMode,
                onChanged: (v) {
                  Navigator.pop(context);
                  _toggleDesktopMode();
                },
                activeTrackColor: const Color(0xFF58A6FF),
                inactiveTrackColor: const Color(0xFF30363D),
              ),
            ),
          ),
        ),
        const PopupMenuDivider(height: 1,),
        const PopupMenuItem(
          value: 'settings',
          child: _MenuItemRow(Icons.settings, 'Settings'),
        ),
      ],
      elevation: 4,
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'new_tab':
          _createNewTab();
          break;
        case 'incognito':
          _createNewTab();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incognito mode (visual only)'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 1),
              width: 250,
            ),
          );
          break;
        case 'bookmarks':
          _showBookmarksSheet();
          break;
        case 'history':
          _showHistorySheet();
          break;
        case 'downloads':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Downloads folder: App Documents'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          break;
        case 'share':
          _shareUrl();
          break;
        case 'find':
          _toggleFindInPage();
          break;
        case 'desktop':
          _toggleDesktopMode();
          break;
      }
    });
  }

  void _toggleDesktopMode() {
    setState(() => _desktopMode = !_desktopMode);
    _controller?.setSettings(
      settings: InAppWebViewSettings(
        preferredContentMode: _desktopMode
            ? UserPreferredContentMode.DESKTOP
            : UserPreferredContentMode.MOBILE,
      ),
    );
    if (_currentUrl.isNotEmpty) {
      _controller?.reload();
    }
  }

  // ─── Build ────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: Column(
          children: [
            _buildTabBar(),
            _buildOmnibox(),
            _buildProgressBar(),
            if (_showFindInPage) _buildFindInPageBar(),
            Expanded(child: _buildWebView()),
            _buildBottomToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      color: const Color(0xFF010409),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _tabScrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              itemBuilder: (_, i) => _buildTabChip(i),
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(color: Color(0xFF21262D), width: 0.5),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _createNewTab(),
                child: const Icon(
                  Icons.add,
                  color: Color(0xFF8B949E),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(int index) {
    final tab = _tabs[index];
    final isActive = index == _activeTabIndex;
    return GestureDetector(
      onTap: () => _switchTab(index),
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF0D1117) : const Color(0xFF010409),
          border: Border(
            right: const BorderSide(color: Color(0xFF21262D), width: 0.5),
            bottom: BorderSide(
              color: isActive
                  ? const Color(0xFF58A6FF)
                  : const Color(0xFF21262D),
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            if (tab.isLoading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor:
                      AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
                ),
              )
            else
              Icon(
                tab.url.startsWith('https')
                    ? Icons.lock_outline
                    : Icons.public,
                size: 12,
                color: tab.url.startsWith('https')
                    ? const Color(0xFF3FB950)
                    : const Color(0xFF8B949E),
              ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tab.title.isNotEmpty ? tab.title : 'New Tab',
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(0xFF8B949E),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: () => _closeTab(index),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: isActive
                      ? const Color(0xFF21262D)
                      : Colors.transparent,
                ),
                child: const Icon(
                  Icons.close,
                  size: 12,
                  color: Color(0xFF8B949E),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOmnibox() {
    final isSecure = _currentUrl.startsWith('https');
    final hasUrl = _currentUrl.isNotEmpty && !_isUrlFocused;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
      color: const Color(0xFF0D1117),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF21262D),
          borderRadius: BorderRadius.circular(19),
          border: Border.all(
            color: _isUrlFocused
                ? const Color(0xFF58A6FF)
                : const Color(0xFF30363D),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            if (hasUrl)
              GestureDetector(
                onTap: () {
                  _urlFocusNode.requestFocus();
                  _urlController.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: _urlController.text.length,
                  );
                },
                child: Icon(
                  isSecure
                      ? Icons.lock
                      : _currentUrl.startsWith('http')
                          ? Icons.warning_amber_rounded
                          : Icons.search,
                  size: 14,
                  color: isSecure
                      ? const Color(0xFF3FB950)
                      : _currentUrl.startsWith('http')
                          ? const Color(0xFFD29922)
                          : const Color(0xFF8B949E),
                ),
              )
            else
              const Icon(Icons.search, size: 16, color: Color(0xFF484F58)),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _urlController,
                focusNode: _urlFocusNode,
                style: const TextStyle(
                  color: Color(0xFFC9D1D9),
                  fontSize: 13,
                ),
                decoration: InputDecoration(
                  hintText: _isUrlFocused
                      ? 'Search or enter URL'
                      : _pageTitle.isNotEmpty
                          ? _pageTitle
                          : 'Search or enter URL',
                  hintStyle: TextStyle(
                    color: _isUrlFocused
                        ? const Color(0xFF484F58)
                        : const Color(0xFF8B949E),
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  suffixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                ),
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: _navigateToUrl,
              ),
            ),
            if (_urlController.text.isNotEmpty && _isUrlFocused)
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                color: const Color(0xFF8B949E),
                onPressed: () {
                  _urlController.clear();
                  _urlFocusNode.requestFocus();
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            if (!_isUrlFocused)
              GestureDetector(
                onTap: _currentUrl.isNotEmpty ? _toggleBookmark : null,
                child: Icon(
                  _isBookmarked
                      ? Icons.star
                      : Icons.star_border,
                  size: 18,
                  color: _isBookmarked
                      ? const Color(0xFFD29922)
                      : const Color(0xFF484F58),
                ),
              )
            else
              IconButton(
                icon: const Icon(Icons.arrow_circle_right, size: 20),
                color: const Color(0xFF58A6FF),
                onPressed: () {
                  _navigateToUrl(_urlController.text.trim());
                },
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 28, minHeight: 28),
              ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return AnimatedCrossFade(
      firstChild: const SizedBox(height: 2),
      secondChild: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: LinearProgressIndicator(
          value: _progress,
          minHeight: 2,
          backgroundColor: Colors.transparent,
          valueColor:
              const AlwaysStoppedAnimation<Color>(Color(0xFF58A6FF)),
        ),
      ),
      crossFadeState: _isLoading
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: const Duration(milliseconds: 200),
    );
  }

  Widget _buildFindInPageBar() {
    return Container(
      color: const Color(0xFF161B22),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.find_in_page, color: Color(0xFF8B949E), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 30,
              child: TextField(
                controller: _findController,
                focusNode: _findFocusNode,
                style: const TextStyle(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Find in page',
                  hintStyle:
                      const TextStyle(color: Color(0xFF484F58), fontSize: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF30363D)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(4),
                    borderSide: const BorderSide(color: Color(0xFF58A6FF)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  filled: false,
                ),
                onChanged: _onFindTextChanged,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _findNext(),
              ),
            ),
          ),
          if (_findText.isNotEmpty)
            Text(
              '$_findActiveMatch/$_findResultCount',
              style: const TextStyle(color: Color(0xFF8B949E), fontSize: 12),
            ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, size: 18),
            color: const Color(0xFF8B949E),
            onPressed: _findPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 18),
            color: const Color(0xFF8B949E),
            onPressed: _findNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            color: const Color(0xFF8B949E),
            onPressed: _toggleFindInPage,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomToolbar() {
    final tabCount = _tabs.length;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        border: const Border(
          top: BorderSide(color: Color(0xFF21262D)),
        ),
      ),
      child: Row(
        children: [
          _toolbarButton(
            icon: Icons.arrow_back_ios_new,
            size: 18,
            enabled: _canGoBack,
            onTap: () => _controller?.goBack(),
          ),
          _toolbarButton(
            icon: Icons.arrow_forward_ios,
            size: 18,
            enabled: _canGoForward,
            onTap: () => _controller?.goForward(),
          ),
          _toolbarButton(
            icon: _isLoading ? Icons.close : Icons.refresh,
            size: 20,
            enabled: true,
            onTap: () {
              if (_isLoading) {
                _controller?.stopLoading();
              } else {
                _controller?.reload();
              }
            },
          ),
          _toolbarButton(
            icon: Icons.home,
            size: 18,
            enabled: true,
            onTap: () {
              _urlController.text = 'starlight.institution.site';
              navigateToUrl('starlight.institution.site');
            },
          ),
          const Spacer(),
          _toolbarButton(
            icon: Icons.bookmark_border,
            size: 18,
            enabled: true,
            onTap: _showBookmarksSheet,
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF21262D),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.tab, color: Color(0xFF8B949E), size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$tabCount',
                    style: const TextStyle(
                      color: Color(0xFF8B949E),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          _toolbarButton(
            icon: Icons.more_vert,
            size: 20,
            enabled: true,
            onTap: _showOverflowMenu,
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _toolbarButton({
    required IconData icon,
    required double size,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return Container(
      width: 40,
      height: 40,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: enabled ? onTap : null,
          child: Icon(
            icon,
            size: size,
            color: enabled
                ? const Color(0xFFC9D1D9)
                : const Color(0xFF484F58),
          ),
        ),
      ),
    );
  }

  Widget _buildWebView() {
    final hasUrl = widget.initialUrl != null || _pendingInitialUrl != null;
    final initialUrl = widget.initialUrl ?? _pendingInitialUrl;
    final hasHtml = widget.initialHtml != null;
    return InAppWebView(
      initialUrlRequest: hasUrl && !hasHtml
          ? URLRequest(url: WebUri(_resolveUrl(initialUrl!)))
          : null,
      initialData: widget.initialHtml != null
          ? InAppWebViewInitialData(
              data: widget.initialHtml!,
              mimeType: 'text/html',
              encoding: 'utf8',
            )
          : null,
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        domStorageEnabled: true,
        allowsInlineMediaPlayback: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        allowFileAccess: true,
        allowContentAccess: true,
        mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
        cacheEnabled: true,
        useHybridComposition: true,
        mediaPlaybackRequiresUserGesture: false,
        preferredContentMode: _desktopMode
            ? UserPreferredContentMode.DESKTOP
            : UserPreferredContentMode.MOBILE,
      ),
      findInteractionController: _findInteractionController,
      onWebViewCreated: (controller) {
        _controller = controller;
        if (_pendingInitialUrl != null &&
            widget.initialUrl == null) {
          final url = _pendingInitialUrl!;
          _pendingInitialUrl = null;
          controller.loadUrl(
            urlRequest: URLRequest(url: WebUri(_resolveUrl(url))),
          );
        }
      },
      onLoadStart: (controller, url) {
        final urlStr = url?.toString() ?? '';
        if (mounted) {
          setState(() {
            _currentUrl = urlStr;
            _urlController.text = urlStr;
            _isLoading = true;
            _progress = 0.0;
            final activeTab = _tabs[_activeTabIndex];
            activeTab.url = urlStr;
            activeTab.isLoading = true;
            activeTab.progress = 0.0;
          });
        }
      },
      onLoadStop: (controller, url) {
        final urlStr = url?.toString() ?? '';
        controller.getTitle().then((title) {
          if (mounted) {
            setState(() {
              _currentUrl = urlStr;
              _urlController.text = urlStr;
              _pageTitle = title ?? '';
              _isLoading = false;
              _progress = 1.0;
              final activeTab = _tabs[_activeTabIndex];
              activeTab.url = urlStr;
              activeTab.title = title ?? '';
              activeTab.isLoading = false;
              activeTab.progress = 1.0;
              _checkBookmarkStatus();
            });
            _addToHistory(urlStr, title ?? '');
          }
        });
        _updateNavState();
      },
      onProgressChanged: (controller, progress) {
        if (mounted) {
          setState(() {
            _progress = progress / 100.0;
            final activeTab = _tabs[_activeTabIndex];
            activeTab.progress = progress / 100.0;
          });
        }
      },
      onDownloadStartRequest: (controller, request) {
        _onDownloadStart(controller, request);
      },
      onTitleChanged: (controller, title) {
        if (mounted) {
          setState(() {
            _pageTitle = title ?? '';
            final activeTab = _tabs[_activeTabIndex];
            activeTab.title = title ?? '';
          });
        }
      },
      onFindResultReceived: (controller, activeMatchOrdinal, numberOfMatches, isDoneCounting) {
        if (mounted) {
          setState(() {
            _findActiveMatch = activeMatchOrdinal;
            _findResultCount = numberOfMatches;
          });
        }
      },
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? trailing;

  const _MenuItemRow(this.icon, this.text, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFC9D1D9)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFC9D1D9),
              fontSize: 14,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
