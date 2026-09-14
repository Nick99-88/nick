import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/storage.dart';
import 'blueprint_editor.dart';
import 'fee_voucher_editor.dart';

class BlueprintOverlay extends StatefulWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final Function(Map<String, dynamic>)? onSelected;
  final String? blueprintType;

  const BlueprintOverlay({
    super.key, 
    required this.isOpen, 
    required this.onClose,
    this.onSelected,
    this.blueprintType,
  });

  @override
  State<BlueprintOverlay> createState() => _BlueprintOverlayState();
}

class _BlueprintOverlayState extends State<BlueprintOverlay> {
  final String apiBase = "https://api.institution.site";
  final Color primaryColor = const Color(0xFF0288D1);
  
  List<Map<String, dynamic>> blueprints = [];
  bool isLoading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    fetchBlueprints();
  }

  @override
  void didUpdateWidget(BlueprintOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Refresh when overlay opens
    if (widget.isOpen && !oldWidget.isOpen) {
      fetchBlueprints();
    }
  }

  Future<void> deleteBlueprint(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF263238),
        title: const Text("Delete Blueprint?", style: TextStyle(color: Colors.white)),
        content: const Text(
          "This action cannot be undone. The blueprint will be permanently removed.",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("CANCEL", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("DELETE", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.delete(
        Uri.parse('$apiBase/document/blueprint/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success') {
          _showNotify("Blueprint deleted", true);
          fetchBlueprints(); // Refresh list
        } else {
          _showNotify("Error: ${data['message'] ?? 'Failed to delete'}", false);
        }
      } else {
        _showNotify("Server error: ${res.statusCode}", false);
      }
    } catch (e) {
      _showNotify("Network error: $e", false);
    }
  }

  void _showNotify(String msg, bool success) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: success ? Colors.green : Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(20),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> fetchBlueprints() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final token = await StarlightStorage.getUserToken();
      final res = await http.get(
        Uri.parse('$apiBase/document/blueprint/list'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['status'] == 'success' && data['blueprints'] != null) {
          final List<dynamic> rawList = data['blueprints'] as List;
          final List<Map<String, dynamic>> filteredList = [];
          
          print("📡 [BLUEPRINT OVERLAY] Raw blueprints from server: $rawList");
          print("📡 [BLUEPRINT OVERLAY] Filtering for type: ${widget.blueprintType}");
          
          for (var item in rawList) {
            if (item is Map) {
              final bp = Map<String, dynamic>.from(item);
              final String type = bp['type'] ?? '';
              
              if (widget.blueprintType != null) {
                if (type == widget.blueprintType) {
                  filteredList.add(bp);
                }
              } else {
                if (type != 'fee_voucher_blueprint') {
                  filteredList.add(bp);
                }
              }
            }
          }

          print("📡 [BLUEPRINT OVERLAY] Filtered list count: ${filteredList.length}");

          setState(() {
            blueprints = filteredList;
            isLoading = false;
          });
        } else {
          setState(() {
            blueprints = [];
            isLoading = false;
          });
        }
      } else {
        setState(() {
          errorMessage = "Failed to load: ${res.statusCode}";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Network error: $e";
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // sidebar width set to 75% for an professional architectural feel
    double width = MediaQuery.of(context).size.width * 0.75;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 400),
      curve: Curves.fastOutSlowIn,
      top: 0,
      bottom: 0,
      right: widget.isOpen ? 0 : -width, 
      child: Container(
        width: width,
        decoration: const BoxDecoration(
          color: Color(0xFF263238),
          boxShadow: [
            BoxShadow(
              color: Colors.black54, 
              blurRadius: 30, 
              offset: Offset(-5, 0)
            )
          ],
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Title and Close Button
              ListTile(
                title: const Text("BLUEPRINT DIRECTORY", 
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.bold, 
                    fontSize: 13, 
                    letterSpacing: 1.1
                  )
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: fetchBlueprints,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, thickness: 1),
              
              // Loading State
              if (isLoading)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.white54),
                        SizedBox(height: 16),
                        Text("Loading Blueprints...", style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                )
              else if (errorMessage != null)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: fetchBlueprints,
                          icon: const Icon(Icons.refresh),
                          label: const Text("Retry"),
                        ),
                      ],
                    ),
                  ),
                )
              // Empty State
              else if (blueprints.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.folder_open, color: Colors.white24, size: 64),
                        const SizedBox(height: 16),
                        const Text(
                          "No Blueprints Yet",
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "Create your first blueprint",
                          style: TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
              // List of Existing Blueprint Structures
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: blueprints.length,
                    itemBuilder: (context, i) {
                      final bp = blueprints[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ListTile(
                          leading: Icon(Icons.table_chart_outlined, color: primaryColor, size: 20),
                          title: Text(bp['title'] ?? 'Untitled Blueprint', 
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 13, 
                              fontWeight: FontWeight.w500
                            )
                          ),
                          subtitle: Text(
                            "Created: ${bp['created_at']?.toString().split('T').first ?? 'Unknown'}",
                            style: const TextStyle(color: Colors.white38, fontSize: 10),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit Button
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white54, size: 18),
                                onPressed: () {
                                  widget.onClose();
                                  final bool isFeeBp = widget.blueprintType == 'fee_voucher_blueprint';
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => isFeeBp 
                                          ? FeeVoucherEditor(
                                              blueprintId: bp['id'],
                                              existingBlueprint: bp,
                                            )
                                          : BlueprintEditor(
                                              blueprintId: bp['id'],
                                              existingBlueprint: bp,
                                              blueprintType: widget.blueprintType,
                                            ),
                                    ),
                                  );
                                },
                                tooltip: "Edit Blueprint",
                              ),
                              // Delete Button
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.redAccent, size: 18),
                                onPressed: () => deleteBlueprint(bp['id']),
                                tooltip: "Delete Blueprint",
                              ),
                            ],
                          ),
                          onTap: () {
                            if (widget.onSelected != null) {
                              widget.onSelected!(bp);
                            }
                            widget.onClose();
                          },
                        ),
                      );
                    },
                  ),
                ),

              // 🏛️ Stylish "Add Blueprint" Button
              // This triggers the transition to the professional Architect
              Padding(
                padding: const EdgeInsets.all(15.0),
                child: ElevatedButton.icon(
                  onPressed: () {
                    widget.onClose(); // Close overlay before navigating
                    final bool isFeeBp = widget.blueprintType == 'fee_voucher_blueprint';
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => isFeeBp 
                            ? const FeeVoucherEditor() 
                            : BlueprintEditor(blueprintType: widget.blueprintType),
                      ),
                    );
                  },
                  icon: Icon(
                    widget.blueprintType == 'fee_voucher_blueprint' ? Icons.add_circle_outline_rounded : Icons.add_rounded, 
                    size: 20
                  ),
                  label: Text(
                    widget.blueprintType == 'fee_voucher_blueprint' ? "CREATE BLUEPRINT" : "NEW STRUCTURE", 
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)
                    ),
                    elevation: 8,
                  ),
                ),
              ),

              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text("STALLIGHT SYSTEM v1.0", 
                    style: TextStyle(
                      color: Colors.white24, 
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5
                    )
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}