import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme.dart';
import '../../../services/institution/dashboard_service.dart';
import '../../../core/utils.dart';
import '../../../core/storage.dart';
import '../../../l10n/strings.dart';
import 'package:flutter/material.dart' as material;
import 'database/dashboard_cache_service.dart';

class StudentAdmissionScreen extends StatefulWidget {
  const StudentAdmissionScreen({super.key});

  @override
  State<StudentAdmissionScreen> createState() => _StudentAdmissionScreenState();
}

class _StudentAdmissionScreenState extends State<StudentAdmissionScreen> {
  final DashboardService _dashboardService = DashboardService();
  final DashboardCacheService _cache = DashboardCacheService.instance;
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _fatherController = TextEditingController();
  final _feeController = TextEditingController(text: "0");
  final _newSectionController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  final _dobController = TextEditingController();
  String? _selectedGender;

  String? _selectedSection;
  List<String> _sections = [];
  bool _isCustomSection = false;
  bool _isLoading = false;
  File? _attachedDocument;

  List<Map<String, TextEditingController>> _extraFields = [];

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    try {
      final sections = await _cache.getSections();
      if (mounted) {
        setState(() {
          _sections = sections;
          if (_sections.isNotEmpty) {
            _selectedSection = _sections.first;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        StarlightUtils.showInfoBox(context, tr('loadSectionsFailed'));
      }
    }
  }

  void _addExtraField() {
    setState(() {
      _extraFields.add({
        "key": TextEditingController(),
        "val": TextEditingController(),
      });
    });
  }

  Future<void> _pickUniversalFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'png', 'pdf', 'doc', 'docx'],
    );

    if (result != null) {
      setState(() {
        _attachedDocument = File(result.files.single.path!);
      });
      StarlightUtils.showSuccessBox(context, tr('fileAttached', {'fileName': result.files.single.name}));
    }
  }

  Future<void> _initiateAIScan() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.image,
    );

    if (result == null || result.files.single.path == null) return;

    _showScanningOverlay();

    try {
      File imageFile = File(result.files.single.path!);
      final response = await _dashboardService.processAIScan(imageFile);

      if (!mounted) return;
      Navigator.pop(context);

      if (response != null && response['data'] != null) {
        _showReviewOverlay(response['data']);
        StarlightUtils.showSuccessBox(context, tr('scanComplete'));
      } else {
        StarlightUtils.showErrorBox(context, tr('scanRejected'));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      StarlightUtils.showErrorBox(context, tr('scanFailed'));
    }
  }

  void _showReviewOverlay(dynamic data) {
    List records = data is List ? data : [data];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        height: MediaQuery.of(context).size.height * 0.7,
        child: material.Column(
          children: [
            Text(tr('aiExtractedData'), style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (context, index) {
                  final student = records[index];
                  return Card(
                    color: Colors.grey.shade50,
                    child: ListTile(
                      title: Text(student['name'] ?? tr('unknownStudent'), style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(tr('fatherSectionInfo', {
                        'father': student['father_name'] ?? "",
                        'section': student['section'] ?? "",
                      })),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit, color: StarlightTheme.primaryBlue),
                        onPressed: () {
                          setState(() {
                            _nameController.text = student['name'] ?? "";
                            _fatherController.text = student['father_name'] ?? "";
                            _feeController.text = student['fee']?.toString() ?? "0";
                            _selectedSection = student['section'];
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScanningOverlay() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: material.Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: StarlightTheme.primaryBlue),
            const SizedBox(height: 20),
            Text(tr('starlightAiEngine'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 10),
            Text(tr('readingRegister'), style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAdmission() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // 1. Fetch Session Identity from Storage Vault
      final int? activeUserId = await StarlightStorage.getUserId();
      final String? activeInstIdString = await StarlightStorage.getAppId();
      final int? activeInstId = int.tryParse(activeInstIdString ?? "");

      // 2. Prepare Extra Details (Packaging non-main fields into JSON)
      // We include standard fields + user-added custom fields
      Map<String, dynamic> extraMap = {
        'phone_number': _phoneController.text.trim(),
        'national_id': _nationalIdController.text.trim(),
        'address': _addressController.text.trim(),
        'bio': _bioController.text.trim(),
        'gender': _selectedGender ?? 'other',
        'dob': _dobController.text.trim(),
      };

      // Add user-defined dynamic fields
      for (var field in _extraFields) {
        String key = field["key"]!.text.trim();
        String val = field["val"]!.text.trim();
        if (key.isNotEmpty) extraMap[key] = val;
      }

      // 3. Construct Data Package for Cloud (Matching SQLAlchemy model)
      final String finalSection = _isCustomSection
          ? _newSectionController.text.trim()
          : (_selectedSection ?? "");

      final Map<String, dynamic> studentData = {
        "name": _nameController.text.trim(),
        "father_name": _fatherController.text.trim(),
        "fee": double.tryParse(_feeController.text) ?? 0.0,
        "section_name": finalSection,
        "extra_details": extraMap, // JSON object for server
        "user_id": activeUserId,
        "institution_id": activeInstId,
      };

      // 4. PRIMARY ACTION: Submit to Cloud or Local Cache
      final result = await _cache.admitStudent(studentData);

      if (mounted) {
        final isPending = result['pending'] == true;
        if (isPending) {
          StarlightUtils.showInfoBox(context, tr('studentSavedLocally'));
        } else {
          StarlightUtils.showSuccessBox(context, tr('studentAdmitted'));
        }
        _resetForm();
      }
    } catch (e) {
      // 6. ERROR HANDLING
      // As per your "simple logic": if cloud fails, we do not save to keep it clean.
      if (mounted) {
        StarlightUtils.showErrorBox(context, tr('admissionFailedCloud'));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _nameController.clear();
    _fatherController.clear();
    _feeController.text = "0";
    _newSectionController.clear();
    _phoneController.clear();
    _nationalIdController.clear();
    _addressController.clear();
    _bioController.clear();
    _dobController.clear();
    setState(() {
      _extraFields.clear();
      _selectedSection = null;
      _selectedGender = null;
      _isCustomSection = false;
      _attachedDocument = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          tr('studentAdmission'),
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: StarlightTheme.primaryBlue),
        ),
        centerTitle: false,
        actions: [
          TextButton.icon(
            onPressed: _initiateAIScan,
            icon: Icon(Icons.auto_awesome, size: 18, color: Colors.amber[700]),
            label: Text(tr('aiScan'), style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.amber[700], fontSize: 13)),
          )
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[100], height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: material.Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(tr('basicInformation')),
              _customField(_nameController, tr('fullName'), Icons.person, isRequired: true),
              _customField(_fatherController, tr('fathersName'), Icons.family_restroom, isRequired: true),
              _customField(_phoneController, tr('phoneNumber'), Icons.phone),
              _customField(_nationalIdController, tr('nationalId'), Icons.badge),
              _customField(_addressController, tr('address'), Icons.location_on),
              _customField(_dobController, tr('dateOfBirth'), Icons.calendar_today, kbType: TextInputType.datetime),

              const SizedBox(height: 10),
              _buildGenderDropdown(),
              _buildSectionDropdown(),

              if (_isCustomSection)
                _customField(_newSectionController, tr('newSectionName'), Icons.add_business, isRequired: true),

              _customField(_feeController, tr('admissionFee'), Icons.payments, kbType: TextInputType.number, isRequired: true),

              const SizedBox(height: 20),
              _buildSectionTitle(tr('documentation')),
              if (_attachedDocument != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(tr('attached', {'name': _attachedDocument!.path.split('/').last}), style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              OutlinedButton.icon(
                onPressed: _pickUniversalFile,
                icon: const Icon(Icons.attach_file),
                label: Text(tr('pickDocPdfImage')),
              ),

              const SizedBox(height: 20),
              _buildSectionTitle(tr('extraDataFields')),
              ..._extraFields.map((field) => _buildExtraFieldRow(field)).toList(),

              TextButton.icon(
                onPressed: _addExtraField,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(tr('addCustomField')),
              ),

              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: StarlightTheme.primaryBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _handleAdmission,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(tr('confirmAdmission'), style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.5)),
    );
  }

  String _genderLabel(String gender) {
    switch (gender) {
      case 'male':
        return tr('genderMale');
      case 'female':
        return tr('genderFemale');
      default:
        return tr('genderOther');
    }
  }

  Widget _buildSectionDropdown() {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedSection,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr('sectionClassReq'),
            border: InputBorder.none,
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return tr('selectSectionRequired');
            }
            if (value == "CUSTOM" && (_newSectionController.text.trim().isEmpty)) {
              return tr('enterSectionName');
            }
            return null;
          },
          items: [
            ..._sections.map((s) => DropdownMenuItem(value: s, child: Text(s))),
            DropdownMenuItem(value: "CUSTOM", child: Text(tr('addNewSection'), style: const TextStyle(fontWeight: FontWeight.bold, color: StarlightTheme.primaryBlue))),
          ],
          onChanged: (val) {
            setState(() {
              if (val == "CUSTOM") {
                _isCustomSection = true;
                _selectedSection = "CUSTOM";
              } else {
                _isCustomSection = false;
                _selectedSection = val;
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildGenderDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          value: _selectedGender,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: tr('gender'),
            prefixIcon: const Icon(Icons.wc_rounded, size: 18),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
          items: [
            DropdownMenuItem(value: "male", child: Text(_genderLabel('male'))),
            DropdownMenuItem(value: "female", child: Text(_genderLabel('female'))),
            DropdownMenuItem(value: "other", child: Text(_genderLabel('other'))),
          ],
          onChanged: (val) {
            setState(() {
              _selectedGender = val;
            });
          },
        ),
      ),
    );
  }

  Widget _buildExtraFieldRow(Map<String, TextEditingController> field) {
    return Row(
      children: [
        Expanded(child: _customField(field["key"]!, tr('fieldExampleAge'), Icons.label_outline)),
        const SizedBox(width: 10),
        Expanded(child: _customField(field["val"]!, tr('value'), Icons.edit_note)),
        IconButton(onPressed: () => setState(() => _extraFields.remove(field)), icon: const Icon(Icons.remove_circle_outline, color: Colors.red)),
      ],
    );
  }

  Widget _customField(TextEditingController controller, String label, IconData icon, {TextInputType kbType = TextInputType.text, bool isRequired = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: kbType,
        validator: (v) {
          if (isRequired && (v == null || v.trim().isEmpty)) {
            return tr('required');
          }
          return null;
        },
        style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18),
          labelText: isRequired ? "$label *" : label,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}