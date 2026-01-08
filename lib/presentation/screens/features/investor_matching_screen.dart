import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:startup_application/core/theme/app_theme.dart';

import 'package:startup_application/presentation/providers/auth_provider.dart';
import 'package:startup_application/presentation/widgets/language_selector.dart';
import 'package:startup_application/presentation/widgets/translated_text.dart';
import 'package:startup_application/presentation/providers/language_provider.dart';
import 'package:startup_application/core/services/investor_matching_service.dart';
import 'package:startup_application/core/services/glossary_service.dart';

class InvestorMatchingScreen extends ConsumerStatefulWidget {
  const InvestorMatchingScreen({super.key});

  @override
  ConsumerState<InvestorMatchingScreen> createState() =>
      _InvestorMatchingScreenState();
}

class _InvestorMatchingScreenState extends ConsumerState<InvestorMatchingScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final InvestorMatchingService _matchingService = InvestorMatchingService();

  bool _isLoading = false;
  List<dynamic>? _matchedInvestors;
  final ScrollController _scrollController = ScrollController();

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Controllers
  final _nameController = TextEditingController();
  final _subSectorController = TextEditingController();
  final _locationController = TextEditingController();
  final _fundingAmountController = TextEditingController();
  final _descriptionController = TextEditingController();

  // Dropdown values
  String? _selectedSector;
  String? _selectedStage;
  String? _selectedBusinessModel;

  final List<String> _sectors = [
    'AgriTech',
    'FinTech',
    'HealthTech',
    'EdTech',
    'Other'
  ];
  final List<String> _stages = ['Pre-seed', 'Seed', 'Series A'];
  final List<String> _businessModels = ['B2B', 'B2C', 'SaaS'];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Auto-fill form if profile exists
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUserProfile());
  }

  Future<void> _loadUserProfile() async {
    final userId = ref.read(authProvider).user?.id;
    if (userId != null) {
      final profile = await _matchingService.fetchUserStartupProfile(userId);
      if (profile != null && mounted) {
        setState(() {
          _nameController.text = profile['startup_name'] ?? '';
          _selectedSector =
              _sectors.contains(profile['sector']) ? profile['sector'] : null;
          _subSectorController.text = profile['sub_sector'] ?? '';
          _selectedStage = _stages.contains(profile['age_stage'])
              ? profile['age_stage']
              : null; // Note: using age_stage
          _locationController.text = profile['location'] ?? '';
          _fundingAmountController.text =
              profile['funding_amount']?.toString() ?? '';
          _selectedBusinessModel =
              _businessModels.contains(profile['business_model'])
                  ? profile['business_model']
                  : null;
          _descriptionController.text = profile['description'] ?? '';
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _subSectorController.dispose();
    _locationController.dispose();
    _fundingAmountController.dispose();
    _descriptionController.dispose();
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _findMatches(Color secondaryColor) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _matchedInvestors = null; // Clear previous results
    });

    try {
      // 1. Prepare Profile Map
      final profile = {
        'startup_name': _nameController.text,
        'sector': _selectedSector ?? '',
        'sub_sector': _subSectorController.text,
        'age_stage': _selectedStage ?? '',
        'location': _locationController.text,
        'funding_amount': _fundingAmountController.text,
        'description': _descriptionController.text,
      };

      // 2. Load CSV Data
      final fundingData = await _matchingService.loadAndFilterCSV(
          _selectedSector ?? '', _selectedStage ?? '');

      // 3. Call AI
      final jsonResponse =
          await _matchingService.generateInvestorMatches(profile, fundingData);

      if (jsonResponse != null) {
        // Parse JSON
        // Note: The AI might return strict JSON, but sometimes minimal markdown ```json ... ```
        String cleanJson =
            jsonResponse.replaceAll('```json', '').replaceAll('```', '').trim();
        final List<dynamic> matches = jsonDecode(cleanJson);

        setState(() {
          _matchedInvestors = matches;
        });

        // Scroll to results
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
          );
        });
      } else {
        throw Exception("Failed to generate matches.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finding investors: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveToHistory() async {
    if (_matchedInvestors == null) return;

    final userId = ref.read(authProvider).user?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    try {
      await _matchingService.saveInvestorMatches(userId, _matchedInvestors!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Matches saved to history!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving matches: $e')),
        );
      }
    }
  }

  void _showHistoryModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final userId = ref.read(authProvider).user?.id;
          if (userId == null) {
            return const Center(
                child: Text('Please log in to view history',
                    style: TextStyle(color: Colors.white)));
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _matchingService.fetchInvestorMatches(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text('Error: ${snapshot.error}',
                        style: const TextStyle(color: Colors.white)));
              }
              final history = snapshot.data ?? [];
              if (history.isEmpty) {
                return const Center(
                    child: Text('No history found.',
                        style: TextStyle(color: Colors.white)));
              }

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[600],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Text(
                    "Matching History",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: history.length,
                      itemBuilder: (context, index) {
                        final item = history[index];
                        final dateStr = item['created_at'];
                        final date = dateStr != null
                            ? DateTime.parse(dateStr).toLocal()
                            : DateTime.now();
                        final formattedDate =
                            DateFormat.yMMMd().add_jm().format(date);
                        final secondaryColor =
                            AppTheme.getSecondaryColorForSector(
                                ref.read(authProvider).profile?.startupSector ??
                                    'Other');

                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1)),
                          ),
                          child: ListTile(
                            title: Text(
                              item['investor_name'] ?? 'Unknown',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formattedDate,
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.5),
                                      fontSize: 12),
                                ),
                                if (item['reason'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      item['reason'],
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.7),
                                          fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: secondaryColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color:
                                        secondaryColor.withValues(alpha: 0.5)),
                              ),
                              child: Text(
                                item['match_percentage'] ?? 'N/A',
                                style: TextStyle(
                                    color: secondaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final sector = authState.profile?.startupSector ?? 'Other';
    final secondaryColor = AppTheme.getSecondaryColorForSector(sector);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const TranslatedText('Investor Matching',
            style: TextStyle(color: Colors.white)),
        actions: [
          TextButton.icon(
            onPressed: _showHistoryModal,
            icon: const Icon(Icons.history, color: Colors.white, size: 20),
            label: const TranslatedText('History',
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(width: 8),
          const LanguageSelector(),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Form Section
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(
                      'Startup Name', _nameController, secondaryColor),
                  const SizedBox(height: 16),
                  _buildDropdown(
                      'Sector',
                      _sectors,
                      (v) => setState(() => _selectedSector = v),
                      secondaryColor,
                      _selectedSector),
                  const SizedBox(height: 16),
                  _buildTextField(
                      'Sub-sector', _subSectorController, secondaryColor),
                  const SizedBox(height: 16),
                  _buildDropdown(
                      'Startup Stage',
                      _stages,
                      (v) => setState(() => _selectedStage = v),
                      secondaryColor,
                      _selectedStage),
                  const SizedBox(height: 16),
                  _buildTextField(
                      'Location', _locationController, secondaryColor),
                  const SizedBox(height: 16),
                  _buildTextField('Funding Amount Sought',
                      _fundingAmountController, secondaryColor,
                      type: TextInputType.number),
                  const SizedBox(height: 16),
                  _buildDropdown(
                      'Business Model',
                      _businessModels,
                      (v) => setState(() => _selectedBusinessModel = v),
                      secondaryColor,
                      _selectedBusinessModel),
                  const SizedBox(height: 16),
                  _buildTextField('Brief Description (Optional)',
                      _descriptionController, secondaryColor,
                      type: TextInputType.multiline,
                      lines: 4,
                      isOptional: true),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: secondaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _findMatches(secondaryColor),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const TranslatedText('Find Matches',
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // Loading Animation
            if (_isLoading)
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                      color: secondaryColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: secondaryColor.withValues(alpha: 0.5),
                            blurRadius: 20,
                            spreadRadius: 5)
                      ]),
                  child: Center(
                    child: Text(
                      "Thinking...",
                      style: TextStyle(
                          color: secondaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),

            // Results Section
            if (_matchedInvestors != null) ...[
              const Divider(color: Colors.grey),
              const SizedBox(height: 20),
              Text(
                "Top 3 Investor Matches",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ..._matchedInvestors!
                  .map((match) => _buildInvestorCard(match, secondaryColor)),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: _saveToHistory,
                icon: Icon(Icons.save, color: secondaryColor),
                label: Text("Save to History",
                    style: TextStyle(color: secondaryColor)),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: secondaryColor),
                    padding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
              ),
              const SizedBox(height: 40),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildInvestorCard(Map<String, dynamic> match, Color color) {
    final languageCode = ref.watch(languageProvider).code;
    final glossaryService = GlossaryService();

    return FutureBuilder<Map<String, String>>(
        future: Future.wait([
          glossaryService.translate(
              match['investor_name'] ?? 'Unknown Investor', languageCode),
          glossaryService.translate(
              match['reason'] ?? 'No reason provided.', languageCode),
        ]).then((values) => {'name': values[0], 'reason': values[1]}),
        builder: (context, snapshot) {
          final name = snapshot.data?['name'] ??
              match['investor_name'] ??
              'Unknown Investor';
          final reason = snapshot.data?['reason'] ??
              match['reason'] ??
              'No reason provided.';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4))
                ]),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: color.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        match['match_percentage'] ?? 'N/A',
                        style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 12),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  reason,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      height: 1.4),
                ),
              ],
            ),
          );
        });
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    Color color, {
    TextInputType type = TextInputType.text,
    int lines = 1,
    bool isOptional = false,
  }) {
    String cleanLabel = label.replaceAll('(Optional)', '').trim();

    return TextFormField(
      controller: controller,
      keyboardType: type,
      maxLines: lines,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(cleanLabel, color, isOptional: isOptional),
      validator: (value) {
        if (isOptional) return null;
        return value?.isEmpty ?? true ? 'Required' : null;
      },
    );
  }

  InputDecoration _inputDecoration(String label, Color color,
      {bool isOptional = false}) {
    final languageState = ref.watch(languageProvider);
    final translatedLabel = languageState.translations[label] ?? label;

    String? hintText;
    if (isOptional) {
      hintText = languageState.translations['(Optional)'] ?? '(Optional)';
    }

    return InputDecoration(
      labelText: translatedLabel,
      hintText: hintText,
      floatingLabelBehavior: isOptional ? FloatingLabelBehavior.always : null,
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

  Widget _buildDropdown(
    String label,
    List<String> items,
    Function(String?) onChanged,
    Color color,
    String? value,
  ) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: const Color(0xFF1E1E1E),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label, color),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: TranslatedText(e)))
          .toList(),
      onChanged: onChanged,
      validator: (value) => value == null ? 'Required' : null,
    );
  }
}
