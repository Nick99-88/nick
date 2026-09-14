import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';
import '../../services/qr/qr_service.dart';
import 'qr_content_display_screen.dart';

class QRLinkSearchScreen extends StatefulWidget {
  const QRLinkSearchScreen({super.key});

  @override
  State<QRLinkSearchScreen> createState() => _QRLinkSearchScreenState();
}

class _QRLinkSearchScreenState extends State<QRLinkSearchScreen> {
  final TextEditingController _linkController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _linkController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _linkController.removeListener(_onTextChanged);
    _linkController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (_error != null) setState(() => _error = null);
  }

  String? _validateUrl(String url) {
    if (url.isEmpty) return 'Please enter a URL';
    final trimmed = url.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return 'URL must start with http:// or https://';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty) return 'Please enter a valid URL';
    return null;
  }

  Future<void> _fetchContent() async {
    final link = _linkController.text.trim();
    final validationError = _validateUrl(link);
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    _focusNode.unfocus();

    try {
      final data = await QRService.fetchQRLinkData(link);
      if (!mounted) return;

      if (data != null && data['success'] == true) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => QRContentDisplayScreen(link: link, data: data),
          ),
        );
      } else {
        final message = data?['message'] ?? 'No content found for this link';
        setState(() => _error = message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Failed to fetch content. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && mounted) {
      _linkController.text = data!.text!;
      _linkController.selection = TextSelection.fromPosition(
        TextPosition(offset: data.text!.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'Search Content',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: StarlightTheme.primaryBlue,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GestureDetector(
        onTap: () => _focusNode.unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 28),
                _buildInputCard(),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _buildErrorBanner(),
                ],
                const SizedBox(height: 24),
                _buildFetchButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: StarlightTheme.primaryBlue.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.link_rounded,
              size: 36,
              color: StarlightTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Enter a QR Link',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paste or type a link to fetch its content',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Link URL',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _linkController,
            focusNode: _focusNode,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _fetchContent(),
            decoration: InputDecoration(
              hintText: 'https://example.com/scan/...',
              prefixIcon: const Icon(Icons.link, color: Colors.grey),
              suffixIcon: _linkController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => _linkController.clear(),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _pasteFromClipboard,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: Text(
                'Paste from Clipboard',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.grey[700],
                side: BorderSide(color: Colors.grey[300]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[600], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _error!,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.red[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFetchButton() {
    final hasText = _linkController.text.trim().isNotEmpty;
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: (_isLoading || !hasText) ? null : _fetchContent,
        style: ElevatedButton.styleFrom(
          backgroundColor: StarlightTheme.primaryBlue,
          disabledBackgroundColor: Colors.grey[300],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                'Search',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}
