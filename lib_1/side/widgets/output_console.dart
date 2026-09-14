import 'package:flutter/material.dart';
import '../models/execution_result.dart';
import '../theme/editor_theme.dart';

class SideOutputConsole extends StatefulWidget {
  final ExecutionResult? result;
  final bool isRunning;

  const SideOutputConsole({
    super.key,
    this.result,
    this.isRunning = false,
  });

  @override
  State<SideOutputConsole> createState() => _SideOutputConsoleState();
}

class _SideOutputConsoleState extends State<SideOutputConsole> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(SideOutputConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.result != oldWidget.result) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: SideEditorTheme.backgroundDark,
        borderRadius: BorderRadius.circular(SideEditorTheme.borderRadius),
        boxShadow: SideEditorTheme.consoleShadow,
      ),
      child: Column(
        children: [
          _buildConsoleHeader(),
          Expanded(child: _buildConsoleBody()),
        ],
      ),
    );
  }

  Widget _buildConsoleHeader() {
    final statusColor = widget.isRunning
        ? SideEditorTheme.accentOrange
        : widget.result?.isSuccess == true
            ? SideEditorTheme.successGreen
            : widget.result?.hasError == true
                ? SideEditorTheme.errorRed
                : SideEditorTheme.lineNumberColor;

    final statusText = widget.isRunning
        ? 'Running...'
        : widget.result?.isSuccess == true
            ? 'Success'
            : widget.result?.hasError == true
                ? 'Error'
                : 'Output';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SideEditorTheme.surfaceDark,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SideEditorTheme.borderRadius),
        ),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.06),
            width: SideEditorTheme.borderWidth,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            widget.isRunning ? Icons.hourglass_empty : Icons.terminal,
            size: 14,
            color: SideEditorTheme.lineNumberColor,
          ),
          const SizedBox(width: 8),
          const Text(
            'Console',
            style: TextStyle(
              color: SideEditorTheme.textDark,
              fontSize: SideEditorTheme.tabBarFontSize,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
          if (widget.result != null) ...[
            const SizedBox(width: 8),
            Text(
              widget.result!.formattedTime,
              style: const TextStyle(
                color: SideEditorTheme.lineNumberColor,
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConsoleBody() {
    if (widget.isRunning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: SideEditorTheme.accentGreen,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Executing code...',
              style: TextStyle(
                color: SideEditorTheme.lineNumberColor,
                fontSize: SideEditorTheme.outputFontSize,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      );
    }

    if (widget.result == null) {
      return const Center(
        child: Text(
          'Run your code to see output here',
          style: TextStyle(
            color: SideEditorTheme.lineNumberColor,
            fontSize: SideEditorTheme.outputFontSize,
            fontFamily: 'monospace',
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(SideEditorTheme.consolePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.result!.output.isNotEmpty) ...[
            _buildStatusBanner(isError: false),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SelectableText(
                  widget.result!.output,
                  style: const TextStyle(
                    color: SideEditorTheme.textDark,
                    fontSize: SideEditorTheme.outputFontSize,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
          if (widget.result!.hasError && widget.result!.error != null) ...[
            if (widget.result!.output.isEmpty) _buildStatusBanner(isError: true),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: SelectableText(
                  widget.result!.error!.isNotEmpty ? widget.result!.error! : 'Unknown error (empty response from server)',
                  style: const TextStyle(
                    color: SideEditorTheme.errorRed,
                    fontSize: SideEditorTheme.outputFontSize,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
          if (widget.result!.output.isEmpty && !widget.result!.hasError)
            const Center(
              child: Text(
                'No output',
                style: TextStyle(
                  color: SideEditorTheme.lineNumberColor,
                  fontSize: SideEditorTheme.outputFontSize,
                  fontFamily: 'monospace',
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner({required bool isError}) {
    final color = isError ? SideEditorTheme.errorRed : SideEditorTheme.successGreen;
    final icon = isError ? Icons.error_outline : Icons.check_circle_outline;
    final text = isError ? 'Error' : 'Program Output';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
