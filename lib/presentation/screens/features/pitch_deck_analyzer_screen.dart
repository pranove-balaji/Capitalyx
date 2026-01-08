import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:startup_application/core/theme/app_theme.dart';
import 'package:startup_application/presentation/controllers/feature_controller.dart';
import 'package:startup_application/presentation/providers/auth_provider.dart';
import 'package:startup_application/presentation/widgets/language_selector.dart';
import 'package:startup_application/presentation/widgets/translated_text.dart';
import 'package:startup_application/presentation/providers/language_provider.dart';
import 'package:startup_application/presentation/widgets/pitch_deck_analysis_view.dart';
// import 'package:startup_application/core/services/glossary_service.dart';

class PitchDeckAnalyzerScreen extends ConsumerStatefulWidget {
  const PitchDeckAnalyzerScreen({super.key});

  @override
  ConsumerState<PitchDeckAnalyzerScreen> createState() =>
      _PitchDeckAnalyzerScreenState();
}

class _PitchDeckAnalyzerScreenState
    extends ConsumerState<PitchDeckAnalyzerScreen> {
  bool _isLoading = false;
  File? _selectedFile;
  String? _fileName;
  String? _analysisResult;

  String _targetStage = 'Seed';
  String _investorType = 'VC';

  final List<String> _stages = ['Pre-seed', 'Seed', 'Series A', 'Series B'];
  final List<String> _investorTypes = [
    'Angel',
    'VC',
    'Accelerator',
    'Bank',
    'Grant'
  ];

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
        _fileName = result.files.single.name;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a file first')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final extension = _fileName!.split('.').last;

      // Controller uses named parameters and returns Future<String?>
      final result = await ref.read(featureControllerProvider).uploadPitchDeck(
            file: _selectedFile!,
            fileExtension: extension,
            targetStage: _targetStage,
            investorType: _investorType,
          );

      if (mounted) {
        setState(() {
          _analysisResult = result;
        });
      }

      if (mounted) {
        // Success Feedback
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pitch deck uploaded for analysis!')),
        );
        setState(() {
          _selectedFile = null;
          _fileName = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final sector = authState.profile?.startupSector ?? 'Other';
    final secondaryColor = AppTheme.getSecondaryColorForSector(sector);
    // Access language state for dynamic string lookup inside build
    // Note: for SnackBar we need to look it up at event time.

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const TranslatedText('Pitch Deck Analyzer',
              style: TextStyle(color: Colors.white)),
          actions: const [
            LanguageSelector(), // Use common selector
            SizedBox(width: 8),
          ]),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: secondaryColor))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // File Picker Area
                  GestureDetector(
                    onTap: _pickFile,
                    child: Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _selectedFile != null
                              ? secondaryColor
                              : Colors.white.withValues(alpha: 0.2),
                          width: 2,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _selectedFile != null
                                ? Icons.check_circle
                                : Icons.cloud_upload_outlined,
                            size: 48,
                            color: _selectedFile != null
                                ? secondaryColor
                                : Colors.white.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          _selectedFile != null
                              ? Text(
                                  _fileName!,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 16,
                                  ),
                                )
                              : TranslatedText(
                                  'Tap to upload PDF',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 16,
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Context Fields
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    value: _targetStage,
                    decoration: _inputDecoration(
                        'Target Funding Stage', secondaryColor),
                    items: _stages
                        .map((e) => DropdownMenuItem(
                            value: e, child: TranslatedText(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _targetStage = v!),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    dropdownColor: const Color(0xFF1E1E1E),
                    style: const TextStyle(color: Colors.white),
                    value: _investorType,
                    decoration:
                        _inputDecoration('Investor Type', secondaryColor),
                    items: _investorTypes
                        .map((e) => DropdownMenuItem(
                            value: e, child: TranslatedText(e)))
                        .toList(),
                    onChanged: (v) => setState(() => _investorType = v!),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: secondaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submit,
                      child: const TranslatedText('Start Analysis',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),

                  if (_analysisResult != null) ...[
                    const SizedBox(height: 32),
                    // Custom AI Analysis View
                    PitchDeckAnalysisView(analysisResult: _analysisResult!),
                  ],
                  const SizedBox(height: 48), // Bottom padding
                ],
              ),
            ),
    );
  }

  InputDecoration _inputDecoration(String label, Color color) {
    final languageState = ref.watch(languageProvider);
    final translatedLabel = languageState.translations[label] ?? label;

    return InputDecoration(
      labelText: translatedLabel,
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: color),
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.05),
    );
  }
}
