import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/models/company.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:file_picker/file_picker.dart';

class EditCompanyProfileScreen extends StatefulWidget {
  final Company company;

  const EditCompanyProfileScreen({super.key, required this.company});

  @override
  EditCompanyProfileScreenState createState() => EditCompanyProfileScreenState();
}

class EditCompanyProfileScreenState extends State<EditCompanyProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _sectorController;
  late TextEditingController _siretController;
  late TextEditingController _headcountController;
  late TextEditingController _websiteController;
  // New optional fields
  late TextEditingController _insurerAtMpController; // Assureur AT/MP
  late TextEditingController _insurerHorsAtMpController; // Assureur spécialisé hors AT/MP
  late TextEditingController _otherSocialContributionsController; // Autres cotisations sociales
  late TextEditingController _additionalDetailsController; // Détails supplémentaires

  bool _isLoading = false;
  bool _isUploadingLogo = false;
  String? _logoUrl; // relative path from backend (e.g., 'uploads/company-logos/...')
  Uint8List? _selectedLogo;
  String? _selectedLogoName;
  String? _logoError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.company.name);
    _addressController = TextEditingController(text: widget.company.address);
    _phoneController = TextEditingController(text: widget.company.phone);
    _emailController = TextEditingController(text: widget.company.email);
    _sectorController = TextEditingController(text: widget.company.sector);
    _siretController = TextEditingController(text: widget.company.siret);
    _headcountController = TextEditingController(text: widget.company.headcount.toString());
    _websiteController = TextEditingController(text: widget.company.website);
    _insurerAtMpController = TextEditingController(text: widget.company.insurerAtMp ?? '');
    _insurerHorsAtMpController = TextEditingController(text: widget.company.insurerHorsAtMp ?? '');
    _otherSocialContributionsController = TextEditingController(text: widget.company.otherSocialContributions ?? '');
    _additionalDetailsController = TextEditingController(text: widget.company.additionalDetails ?? '');
    _logoUrl = widget.company.logoUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _sectorController.dispose();
    _siretController.dispose();
    _headcountController.dispose();
    _websiteController.dispose();
    _insurerAtMpController.dispose();
    _insurerHorsAtMpController.dispose();
    _otherSocialContributionsController.dispose();
    _additionalDetailsController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_selectedLogo != null) {
        await _uploadLogo();
      }

      final apiService = Provider.of<ApiService>(context, listen: false);
      final updatedCompany = Company(
        id: widget.company.id,
        name: _nameController.text,
        address: _addressController.text,
        phone: _phoneController.text,
        email: _emailController.text,
        sector: _sectorController.text,
        siret: _siretController.text,
        headcount: int.tryParse(_headcountController.text) ?? widget.company.headcount,
        website: _websiteController.text.trim().isEmpty ? null : _websiteController.text.trim(),
        logoUrl: _logoUrl,
        insurerAtMp: _insurerAtMpController.text.trim().isEmpty ? null : _insurerAtMpController.text.trim(),
        insurerHorsAtMp: _insurerHorsAtMpController.text.trim().isEmpty ? null : _insurerHorsAtMpController.text.trim(),
        otherSocialContributions: _otherSocialContributionsController.text.trim().isEmpty ? null : _otherSocialContributionsController.text.trim(),
        additionalDetails: _additionalDetailsController.text.trim().isEmpty ? null : _additionalDetailsController.text.trim(),
      );
      await apiService.updateCompanyProfile(updatedCompany);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil mis à jour avec succès!')),
        );
        Navigator.of(context).pop(true); // Return true to indicate success
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _uploadLogo() async {
    setState(() => _isUploadingLogo = true);

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final company = await apiService.uploadCompanyLogo(
        bytes: _selectedLogo!,
        filename: _selectedLogoName ?? 'logo.png',
      );
      setState(() {
        _logoUrl = company.logoUrl;
        _selectedLogo = null; // clear selection after successful upload
        _selectedLogoName = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Logo mis à jour avec succès.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'upload du logo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingLogo = false);
      }
    }
  }

  Future<void> _selectLogo() async {
    setState(() => _logoError = null);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    final name = file.name;
    final ext = (file.extension ?? '').toLowerCase();

    if (bytes == null) {
      setState(() => _logoError = 'Impossible de lire le fichier sélectionné.');
      return;
    }

    // Validate size <= 5MB
    const maxBytes = 5 * 1024 * 1024;
    if (bytes.length > maxBytes) {
      setState(() => _logoError = 'Fichier trop volumineux (max 5 Mo).');
      return;
    }

    // Detect image type by magic number (accept PNG/JPEG regardless of filename extension)
    final detectedExt = _detectImageExtension(bytes);
    if (detectedExt == null) {
      setState(() => _logoError = 'Le fichier ne semble pas être une image valide.');
      return;
    }

    // Build a safe filename with the detected extension if needed
    const allowed = {'png', 'jpg', 'jpeg'};
    String finalName = name.trim().isEmpty ? 'logo.' + detectedExt : name;
    if (!(ext.isNotEmpty && allowed.contains(ext))) {
      if (finalName.contains('.')) {
        final base = finalName.substring(0, finalName.lastIndexOf('.'));
        finalName = base + '.' + detectedExt;
      } else {
        finalName = finalName + '.' + detectedExt;
      }
    }

    setState(() {
      _selectedLogo = bytes;
      _selectedLogoName = finalName;
      _logoError = null;
    });
  }

  String? _detectImageExtension(Uint8List bytes) {
    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes.length >= 8) {
      const pngSig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      var isPng = true;
      for (var i = 0; i < pngSig.length; i++) {
        if (bytes[i] != pngSig[i]) {
          isPng = false;
          break;
        }
      }
      if (isPng) return 'png';
    }
    // JPEG: FF D8 at start (be lenient about end marker)
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return 'jpg';
    }
    return null;
  }

  Widget _buildLogoTile() {
    final api = Provider.of<ApiService>(context, listen: false);
    final publicUrl = api.getPublicFileUrl(_logoUrl);

    final preview = _selectedLogo != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedLogo!,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
            ),
          )
        : (publicUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  publicUrl,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _logoPlaceholder(),
                ),
              )
            : _logoPlaceholder());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                preview,
                if (_selectedLogo != null)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isUploadingLogo
                            ? null
                            : () {
                                setState(() {
                                  _selectedLogo = null;
                                  _selectedLogoName = null;
                                  _logoError = null;
                                });
                              },
                        customBorder: const CircleBorder(),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (_selectedLogo == null && publicUrl != null)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _isUploadingLogo
                            ? null
                            : () {
                                setState(() {
                                  _logoUrl = null; // clear current server logo locally
                                  _logoError = null;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Logo retiré. Cliquez sur Enregistrer pour confirmer.')),
                                );
                              },
                        customBorder: const CircleBorder(),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(4),
                          child: const Icon(Icons.delete_outline, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                if (_isUploadingLogo)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black38,
                      child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Logo de l\'entreprise', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('PNG ou JPG. Taille maximale: 5 Mo.', style: TextStyle(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isUploadingLogo ? null : _selectLogo,
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('Choisir...'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _isUploadingLogo || _selectedLogo == null ? null : _uploadLogo,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Téléverser'),
                      ),
                      if (_selectedLogo == null && _logoUrl != null)
                        OutlinedButton.icon(
                          onPressed: _isUploadingLogo
                              ? null
                              : () {
                                  setState(() {
                                    _logoUrl = null;
                                    _logoError = null;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Logo retiré. Cliquez sur Enregistrer pour confirmer.')),
                                  );
                                },
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer le logo'),
                        ),
                    ],
                  ),
                  if (_selectedLogoName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('Sélectionné: ' + _selectedLogoName!, style: const TextStyle(fontSize: 12)),
                    ),
                  if (_logoError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(_logoError!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _logoPlaceholder() {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image_not_supported_outlined, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le Profil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProfile,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _saveProfile,
        icon: const Icon(Icons.save),
        label: const Text('Enregistrer'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _sectionHeader('Informations générales', Icons.info_outline),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          _buildLogoTile(),
                          const SizedBox(height: 8),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          _buildTextField(
                            _nameController,
                            'Nom de l\'entreprise',
                            icon: Icons.apartment,
                            textInputAction: TextInputAction.next,
                          ),
                          _buildTextField(
                            _sectorController,
                            'Secteur d\'activité',
                            icon: Icons.business_center_outlined,
                            textInputAction: TextInputAction.next,
                          ),
                          _buildTextField(
                            _siretController,
                            'SIRET',
                            icon: Icons.badge_outlined,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(14),
                            ],
                            maxLength: 14,
                            hintText: '14 chiffres',
                            textInputAction: TextInputAction.next,
                            extraValidator: (v) {
                              final t = (v ?? '').trim();
                              return RegExp(r'^\d{14}$').hasMatch(t)
                                  ? null
                                  : 'SIRET invalide (14 chiffres requis)';
                            },
                          ),
                          _buildTextField(
                            _addressController,
                            'Adresse',
                            icon: Icons.location_on_outlined,
                            textInputAction: TextInputAction.next,
                          ),
                          _buildTextField(
                            _phoneController,
                            'Téléphone',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s().]')),
                              LengthLimitingTextInputFormatter(25),
                            ],
                            hintText: 'ex: +33 1 23 45 67 89',
                            textInputAction: TextInputAction.next,
                            extraValidator: (v) {
                              final t = (v ?? '').trim();
                              final re = RegExp(r'^[0-9+\-\s().]{6,}$');
                              return re.hasMatch(t) ? null : 'Numéro de téléphone invalide';
                            },
                          ),
                          _buildTextField(
                            _emailController,
                            'Email',
                            keyboardType: TextInputType.emailAddress,
                            icon: Icons.email_outlined,
                            textInputAction: TextInputAction.next,
                            extraValidator: (v) {
                              final t = (v ?? '').trim();
                              final re = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
                              return re.hasMatch(t) ? null : 'Adresse email invalide';
                            },
                          ),
                          _buildTextField(
                            _websiteController,
                            'Site Web',
                            icon: Icons.web_asset_outlined,
                            keyboardType: TextInputType.url,
                            requiredField: false,
                            hintText: 'https://exemple.com',
                            textInputAction: TextInputAction.next,
                            extraValidator: (v) {
                              final t = (v ?? '').trim();
                              if (t.isEmpty) return null;
                              final re = RegExp(r'^(https?:\/\/)?([\w\-]+\.)+[\w\-]{2,}(:\d+)?(\/\S*)?$');
                              return re.hasMatch(t) ? null : 'URL invalide (ex: https://exemple.com)';
                            },
                          ),
                          _buildTextField(
                            _headcountController,
                            'Effectif',
                            keyboardType: TextInputType.number,
                            icon: Icons.people_alt_outlined,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(9),
                            ],
                            textInputAction: TextInputAction.next,
                            extraValidator: (v) {
                              final t = (v ?? '').trim();
                              final n = int.tryParse(t);
                              if (n == null || n < 0) return 'Veuillez saisir un entier positif';
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _sectionHeader('Assureurs et cotisations', Icons.policy_outlined),
                  Card(
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        children: [
                          _buildTextField(
                            _insurerAtMpController,
                            'Assureur AT/MP',
                            requiredField: false,
                            icon: Icons.policy_outlined,
                            textInputAction: TextInputAction.next,
                          ),
                          _buildTextField(
                            _insurerHorsAtMpController,
                            'Assureur spécialisé hors AT/MP',
                            requiredField: false,
                            icon: Icons.policy_outlined,
                            textInputAction: TextInputAction.next,
                          ),
                          _buildTextField(
                            _otherSocialContributionsController,
                            'Autres cotisations sociales',
                            requiredField: false,
                            icon: Icons.account_balance_wallet_outlined,
                            textInputAction: TextInputAction.next,
                          ),
                          _buildTextField(
                            _additionalDetailsController,
                            'Détails supplémentaires',
                            maxLines: 4,
                            requiredField: false,
                            icon: Icons.notes_outlined,
                            textInputAction: TextInputAction.newline,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
    int maxLines = 1,
    bool requiredField = true,
    IconData? icon,
    String? Function(String?)? extraValidator,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    String? hintText,
    int? maxLength,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        decoration: _decor(label, icon: icon, hintText: hintText),
        keyboardType: keyboardType,
        maxLines: maxLines,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        validator: (value) {
          if (requiredField) {
            if (value == null || value.isEmpty) {
              return 'Ce champ ne peut pas être vide';
            }
          }
          if (extraValidator != null) {
            return extraValidator(value);
          }
          return null;
        },
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  InputDecoration _decor(String label, {IconData? icon, String? hintText}) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InputDecoration(
      labelText: label,
      hintText: hintText,
      prefixIcon: icon != null ? Icon(icon) : null,
      filled: true,
      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 2),
      ),
    );
  }
}
