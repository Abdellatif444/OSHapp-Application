import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/models/user.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:oshapp/shared/models/employee_creation_request_dto.dart';
import 'package:flutter/services.dart';

class EditUserDialog extends StatefulWidget {
  final User user;
  const EditUserDialog({super.key, required this.user});

  @override
  State<EditUserDialog> createState() => _EditUserDialogState();
}

class _EditUserDialogState extends State<EditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Account
  late TextEditingController _emailController;
  late bool _isActive;

  // Employee profile controllers
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _positionController;
  late TextEditingController _departmentController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cinController;
  late TextEditingController _cnssController;
  late TextEditingController _birthPlaceController;
  late TextEditingController _cityController;
  late TextEditingController _zipCodeController;
  late TextEditingController _countryController;
  late TextEditingController _nationalityController;
  DateTime? _hireDate;
  DateTime? _birthDate;
  String? _gender; // UI only for now
  bool _hasEmployee = false;

  // Roles: single select for "Rôle spécifique"
  // Map human label -> backend code
  final Map<String, String> _roleLabelToCode = const {
    'Administrateur': 'ROLE_ADMIN',
    'RH': 'ROLE_RH',
    'Infirmier': 'ROLE_NURSE',
    'Médecin': 'ROLE_DOCTOR',
    'HSE': 'ROLE_HSE',
    'Employé': 'ROLE_EMPLOYEE',
  };
  late String _selectedRoleLabel;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user.email);
    _isActive = widget.user.isActive;

    _firstNameController = TextEditingController(text: widget.user.employee?.firstName ?? '');
    _lastNameController = TextEditingController(text: widget.user.employee?.lastName ?? '');
    _positionController = TextEditingController(text: widget.user.employee?.jobTitle ?? '');
    _departmentController = TextEditingController(text: widget.user.employee?.department ?? '');
    _phoneController = TextEditingController(text: widget.user.employee?.phoneNumber ?? '');
    _addressController = TextEditingController(text: widget.user.employee?.address ?? '');
    _cinController = TextEditingController(text: widget.user.employee?.cin ?? '');
    _cnssController = TextEditingController(text: widget.user.employee?.cnssNumber ?? '');
    _birthPlaceController = TextEditingController(text: widget.user.employee?.birthPlace ?? '');
    _cityController = TextEditingController(text: widget.user.employee?.city ?? '');
    _zipCodeController = TextEditingController(text: widget.user.employee?.zipCode ?? '');
    _countryController = TextEditingController(text: widget.user.employee?.country ?? '');
    _nationalityController = TextEditingController();
    _hireDate = widget.user.employee?.hireDate;
    _birthDate = widget.user.employee?.birthDate;
    _hasEmployee = widget.user.employee != null;
    _gender = widget.user.employee?.gender; // prefill gender

    // Preselect single role based on user's current roles
    final normalized = widget.user.roles.map((r) => r.trim().toUpperCase()).toList();
    String code = 'ROLE_EMPLOYEE';
    for (final entry in _roleLabelToCode.entries) {
      if (normalized.contains(entry.value)) {
        code = entry.value;
        break;
      }
    }
    _selectedRoleLabel = _roleLabelToCode.entries
        .firstWhere((e) => e.value == code, orElse: () => const MapEntry('Employé', 'ROLE_EMPLOYEE'))
        .key;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _positionController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cinController.dispose();
    _cnssController.dispose();
    _birthPlaceController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    _nationalityController.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
    }

  List<String> _sanitizeRoles(Iterable<String> codes) {
    const allowed = {
      'ROLE_ADMIN', 'ROLE_RH', 'ROLE_NURSE', 'ROLE_DOCTOR', 'ROLE_HSE', 'ROLE_EMPLOYEE'
    };
    return codes.map((r) => r.trim().toUpperCase()).where(allowed.contains).toSet().toList();
  }

  // Determine if the admin intends to create/update an employee profile.
  // We show the employee fields always, and consider the profile "wanted" if
  // a profile already exists or if any field has been filled.
  bool _hasAnyEmployeeInput() {
    String t(TextEditingController c) => c.text.trim();
    return t(_firstNameController).isNotEmpty ||
        t(_lastNameController).isNotEmpty ||
        t(_positionController).isNotEmpty ||
        t(_departmentController).isNotEmpty ||
        t(_phoneController).isNotEmpty ||
        t(_addressController).isNotEmpty ||
        t(_cinController).isNotEmpty ||
        t(_cnssController).isNotEmpty ||
        t(_birthPlaceController).isNotEmpty ||
        t(_cityController).isNotEmpty ||
        t(_zipCodeController).isNotEmpty ||
        t(_countryController).isNotEmpty ||
        t(_nationalityController).isNotEmpty ||
        _hireDate != null ||
        _birthDate != null ||
        (_gender != null && _gender!.isNotEmpty);
  }

  bool get _wantsEmployeeProfile => _hasEmployee || _hasAnyEmployeeInput();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final api = Provider.of<ApiService>(context, listen: false);

    final userId = int.tryParse(widget.user.id);
    if (userId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ID utilisateur invalide.'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    final selectedCode = _roleLabelToCode[_selectedRoleLabel]!;
    final rolesPayload = _sanitizeRoles([selectedCode]);
    if (rolesPayload.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sélectionnez un rôle.'), backgroundColor: Colors.orange),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      // Update user account and capture updated user payload
      final updatedUser = await api.updateUser(
        userId,
        email: _emailController.text.trim(),
        roles: rolesPayload,
        isActive: _isActive,
      );
      // Optionally update or create employee profile and merge into returned user
      var mergedEmployee = updatedUser.employee;
      final bool wantsEmployee = _wantsEmployeeProfile;
      if (wantsEmployee) {
        final dto = EmployeeCreationRequestDTO(
          id: widget.user.employee?.id,
          userId: userId,
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim().isEmpty ? null : _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim().isEmpty ? null : _lastNameController.text.trim(),
          position: _positionController.text.trim().isEmpty ? null : _positionController.text.trim(),
          department: _departmentController.text.trim().isEmpty ? null : _departmentController.text.trim(),
          phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
          address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
          cin: _cinController.text.trim().isEmpty ? null : _cinController.text.trim(),
          cnss: _cnssController.text.trim().isEmpty ? null : _cnssController.text.trim(),
          placeOfBirth: _birthPlaceController.text.trim().isEmpty ? null : _birthPlaceController.text.trim(),
          nationality: _nationalityController.text.trim().isEmpty ? null : _nationalityController.text.trim(),
          city: _cityController.text.trim().isEmpty ? null : _cityController.text.trim(),
          zipCode: _zipCodeController.text.trim().isEmpty ? null : _zipCodeController.text.trim(),
          country: _countryController.text.trim().isEmpty ? null : _countryController.text.trim(),
          hireDate: _hireDate,
          dateOfBirth: _birthDate,
          gender: _gender,
        );
        final updatedEmployee = await api.updateEmployeeProfile(dto);
        mergedEmployee = updatedEmployee;
      }
      // Build a final updated User to return to the caller (ensures employee is up-to-date)
      final resultUser = User(
        id: updatedUser.id,
        username: updatedUser.username,
        email: updatedUser.email,
        roles: updatedUser.roles,
        isActive: updatedUser.isActive,
        enabled: updatedUser.enabled,
        employee: mergedEmployee,
        n1Id: updatedUser.n1Id,
        n2Id: updatedUser.n2Id,
      );
      // Push to global auth state (no-op if it's not the current user)
      final auth = Provider.of<AuthService>(context, listen: false);
      auth.applyUserUpdate(resultUser);
      if (mounted) {
        // Show feedback while context is still valid, then close the dialog.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur mis à jour avec succès!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pop(resultUser);
      }
      return;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur mise à jour: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    InputDecoration decoration(String label, {IconData? icon, String? hint, bool readOnly = false}) {
      final baseBorder = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      );
      final focused = OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
      );
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.12),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        border: baseBorder,
        enabledBorder: baseBorder,
        focusedBorder: focused,
        enabled: !readOnly,
      );
    }

    Widget dateField({required String label, required DateTime? value, required ValueChanged<DateTime?> onChanged, required IconData icon}) {
      return InkWell(
        onTap: _isLoading
            ? null
            : () async {
                final now = DateTime.now();
                final first = DateTime(1950, 1, 1);
                final last = DateTime(now.year, now.month, now.day);
                final picked = await showDatePicker(
                  context: context,
                  initialDate: value ?? last,
                  firstDate: first,
                  lastDate: last,
                );
                if (picked != null) onChanged(picked);
              },
        child: InputDecorator(
          decoration: decoration(label, icon: icon),
          child: Text(value == null ? 'Sélectionner' : _fmtDate(value)),
        ),
      );
    }

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Modifier l'utilisateur", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                "Modifiez les informations de l'utilisateur. Les champs marqués d'un * sont obligatoires.",
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      IconButton(
                        tooltip: 'Fermer',
                        icon: const Icon(Icons.close),
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      )
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Web parity: same field names and order (always visible)
                  ...[
                    // Section: Informations personnelles
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text('Informations personnelles', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    // 1-2. Prénom et Nom
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: decoration(_wantsEmployeeProfile ? 'Prénom *' : 'Prénom', icon: Icons.person),
                            textInputAction: TextInputAction.next,
                            autofocus: true,
                            validator: (v) {
                              if (!_wantsEmployeeProfile) return null;
                              return (v == null || v.trim().isEmpty) ? 'Le prénom est requis.' : null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: decoration(_wantsEmployeeProfile ? 'Nom *' : 'Nom', icon: Icons.person_outline),
                            textInputAction: TextInputAction.next,
                            validator: (v) {
                              if (!_wantsEmployeeProfile) return null;
                              return (v == null || v.trim().isEmpty) ? 'Le nom est requis.' : null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Section: Compte
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Compte', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  // 3. Email
                  TextFormField(
                    controller: _emailController,
                    decoration: decoration('Email *', icon: Icons.email_outlined, hint: 'exemple@domaine.com'),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty || !value.contains('@')) return 'Email invalide';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // État du compte
                  SwitchListTile.adaptive(
                    value: _isActive,
                    onChanged: _isLoading ? null : (v) => setState(() => _isActive = v),
                    title: const Text('Compte actif'),
                    subtitle: Text(_isActive ? 'Peut se connecter et recevoir des notifications' : 'Désactivé — accès suspendu'),
                    secondary: Icon(_isActive ? Icons.verified_user : Icons.visibility_off_outlined),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 12),

                  ...[
                    // 4. Sexe
                    DropdownButtonFormField<String> (
                      value: _gender,
                      items: <DropdownMenuItem<String>>[
                        DropdownMenuItem<String>(value: 'FEMME', child: Text('Femme')),
                        DropdownMenuItem<String>(value: 'HOMME', child: Text('Homme')),
                      ],
                      isExpanded: true,
                      hint: const Text('Sélectionner'),
                      onChanged: (v) => setState(() => _gender = v),
                      decoration: decoration('Sexe', icon: Icons.wc_outlined),
                    ),
                    const SizedBox(height: 12),
                    // 5. Date de naissance
                    dateField(
                      label: 'Date de naissance',
                      value: _birthDate,
                      onChanged: (d) => setState(() => _birthDate = d),
                      icon: Icons.cake_outlined,
                    ),
                    const SizedBox(height: 12),
                    // Section: Coordonnées
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text('Coordonnées', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    // 6. Adresse
                    TextFormField(
                      controller: _addressController,
                      decoration: decoration('Adresse', icon: Icons.home_outlined),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    // Section: Informations d'emploi
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Text("Informations d'emploi", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    // 7-9. Profession et Département
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _positionController,
                            decoration: decoration('Profession', icon: Icons.work_outline),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _departmentController,
                            decoration: decoration('Département', icon: Icons.account_tree_outlined),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // 10. Entreprise (lecture seule)
                    TextFormField(
                      readOnly: true,
                      decoration: decoration('Entreprise', icon: Icons.apartment_outlined, hint: 'OHSE CAPITAL', readOnly: true),
                    ),
                    const SizedBox(height: 12),
                    // 11. Date d'embauche
                    dateField(
                      label: "Date d'embauche",
                      value: _hireDate,
                      onChanged: (d) => setState(() => _hireDate = d),
                      icon: Icons.event_outlined,
                    ),
                    const SizedBox(height: 12),
                    // 10. Téléphone
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: decoration('Téléphone', icon: Icons.phone_outlined, hint: 'Ex. 0612345678'),
                      textInputAction: TextInputAction.next,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        final t = (v ?? '').trim();
                        if (t.isEmpty) return null; // optional
                        final isDigits = RegExp(r'^[0-9]+$').hasMatch(t);
                        if (!isDigits) return 'Le téléphone doit contenir uniquement des chiffres';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    // 12. Numéro de matricule (CNSS)
                    TextFormField(
                      controller: _cnssController,
                      decoration: decoration('Numéro de matricule', icon: Icons.confirmation_num_outlined),
                      textInputAction: TextInputAction.done,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 13. Rôle spécifique
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Rôle et permissions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                  DropdownButtonFormField<String>(
                    value: _selectedRoleLabel,
                    isExpanded: true,
                    items: _roleLabelToCode.keys
                        .map((label) => DropdownMenuItem<String>(value: label, child: Text(label)))
                        .toList(),
                    onChanged: (label) {
                      if (label == null) return;
                      setState(() => _selectedRoleLabel = label);
                    },
                    decoration: decoration('Rôle spécifique *', icon: Icons.shield_outlined),
                    validator: (v) => (v == null || v.isEmpty) ? 'Sélectionnez un rôle' : null,
                  ),

                  if (!_hasEmployee) ...[
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.amber.shade50,
                      child: const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: Text(
                          "Cet utilisateur n'a pas de profil employé. Renseignez les champs ci-dessus pour créer son profil.",
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        label: const Text('Annuler'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _isLoading ? null : _submit,
                        icon: _isLoading
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.save_outlined),
                        label: Text(_isLoading ? 'Patientez...' : 'Mettre à jour'),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  }
}
