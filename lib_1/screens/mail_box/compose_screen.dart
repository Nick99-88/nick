import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
  final _recipientController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedPriority = 'normal';
  bool _isSending = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'COMPOSE',
          style: GoogleFonts.poppins(
            color: const Color(0xFF263238),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSending ? null : _sendDraft,
            child: Text(
              'Save Draft',
              style: GoogleFonts.poppins(
                color: _isSending ? Colors.grey : StarlightTheme.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildRecipientField(),
            const SizedBox(height: 16),
            _buildSubjectField(),
            const SizedBox(height: 16),
            _buildPrioritySelector(),
            const SizedBox(height: 16),
            _buildMessageField(),
            const Spacer(),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipientField() {
    return TextField(
      controller: _recipientController,
      decoration: InputDecoration(
        labelText: 'To',
        hintText: 'Enter recipient name or email',
        prefixIcon: const Icon(Icons.person_outline),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StarlightTheme.primaryBlue),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildSubjectField() {
    return TextField(
      controller: _subjectController,
      decoration: InputDecoration(
        labelText: 'Subject',
        hintText: 'Enter message subject',
        prefixIcon: const Icon(Icons.subject),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: StarlightTheme.primaryBlue),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPrioritySelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Priority',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF263238),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _priorityOption('low', 'Low', Colors.green),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _priorityOption('normal', 'Normal', Colors.blue),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _priorityOption('high', 'High', Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priorityOption(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPriority = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          border: Border.all(
            color: isSelected ? color : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: isSelected ? color : Colors.grey[600],
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageField() {
    return Expanded(
      child: TextField(
        controller: _messageController,
        maxLines: null,
        expands: true,
        decoration: InputDecoration(
          labelText: 'Message',
          hintText: 'Type your message here...',
          alignLabelWithHint: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: StarlightTheme.primaryBlue),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return Container(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSending ? null : _sendMessage,
        style: ElevatedButton.styleFrom(
          backgroundColor: _isSending ? Colors.grey : StarlightTheme.primaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isSending
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Sending...',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
            : Text(
                'Send Message',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }

  void _sendDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Message saved to drafts'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _sendMessage() async {
    if (_recipientController.text.trim().isEmpty ||
        _subjectController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    // Simulate sending message
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _isSending = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message sent successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    }
  }
}
