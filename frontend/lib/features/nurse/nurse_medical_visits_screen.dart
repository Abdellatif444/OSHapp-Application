import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../shared/models/appointment.dart';
import '../../shared/models/appointment_request.dart';
import '../../shared/models/employee.dart';
import '../../shared/services/api_service.dart';
import '../../shared/widgets/appointment_card.dart';
import '../../shared/widgets/confirm_dialog.dart';
import 'package:oshapp/features/hr/medical_visits_rh_screen.dart';
import '../../shared/config/app_config.dart';
import 'package:oshapp/shared/services/auth_service.dart';

class NurseMedicalVisitsScreen extends StatefulWidget {
  final VoidCallback? onNotificationUpdate;
  final bool initialIsPlanifier;
  final String? initialStatusFilter;
  final String? initialTypeFilter;
  final String? initialVisitModeFilter;
  final String? initialDepartmentFilter;
  final String? initialSearch;

  const NurseMedicalVisitsScreen({
    super.key,
    this.onNotificationUpdate,
    this.initialIsPlanifier = false,
    this.initialStatusFilter,
    this.initialTypeFilter,
    this.initialVisitModeFilter,
    this.initialDepartmentFilter,
    this.initialSearch,
  });

  @override
  State<NurseMedicalVisitsScreen> createState() =>
      _NurseMedicalVisitsScreenState();
}

class _NurseMedicalVisitsScreenState extends State<NurseMedicalVisitsScreen> {
  bool _isPlanifier = false; // default to Consulter like HR

  @override
  void initState() {
    super.initState();
    // Initialize tab from navigation parameter
    _isPlanifier = widget.initialIsPlanifier;
  }

  void _switchToPlanifier() {
    setState(() => _isPlanifier = true);
  }

  void _switchToConsulter() {
    setState(() => _isPlanifier = false);
  }

  void _reloadNotifications() {
    // Appeler le callback du dashboard parent pour recharger les notifications
    widget.onNotificationUpdate?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Visites médicales(Inférmier)'),
        backgroundColor: Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isPlanifier)
                      GradientButton(
                        onPressed: null,
                        gradient: LinearGradient(colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.85),
                        ]),
                        showGradientWhenDisabled: true,
                        radius: 24,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: const Text('Planifier',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      )
                    else
                      OutlinedButton(
                        onPressed: _switchToPlanifier,
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          side: BorderSide(color: theme.colorScheme.primary),
                          foregroundColor: theme.colorScheme.primary,
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Planifier'),
                      ),
                    const SizedBox(width: 10),
                    if (_isPlanifier)
                      OutlinedButton(
                        onPressed: _switchToConsulter,
                        style: OutlinedButton.styleFrom(
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                          side: BorderSide(color: theme.colorScheme.primary),
                          foregroundColor: theme.colorScheme.primary,
                          textStyle:
                              const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        child: const Text('Consulter'),
                      )
                    else
                      GradientButton(
                        onPressed: null,
                        gradient: LinearGradient(colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.85),
                        ]),
                        showGradientWhenDisabled: true,
                        radius: 24,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        child: const Text('Consulter',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _isPlanifier
                  ? _PlanifierTab(
                      onNotificationUpdate: _reloadNotifications,
                    )
                  : _ConsulterTab(
                      onNotificationUpdate: _reloadNotifications,
                      initialStatusFilter: widget.initialStatusFilter,
                      initialTypeFilter: widget.initialTypeFilter,
                      initialVisitModeFilter: widget.initialVisitModeFilter,
                      initialDepartmentFilter: widget.initialDepartmentFilter,
                      initialSearch: widget.initialSearch,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanifierTab extends StatefulWidget {
  final VoidCallback? onNotificationUpdate;

  const _PlanifierTab({this.onNotificationUpdate});

  @override
  State<_PlanifierTab> createState() => _PlanifierTabState();
}

class _PlanifierTabState extends State<_PlanifierTab> {
  final _formKey = GlobalKey<FormState>();
  late ApiService _api;

  Employee? _selectedEmployee;
  late TextEditingController _employeeCtrl;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  // final _commentsCtrl = TextEditingController();
  final _medicalInstructionsCtrl = TextEditingController();
  String _visitMode = 'IN_PERSON';
  String? _selectedVisitType;
  bool _isSubmitting = false;

  // Preloaded data and filtering base
  List<Employee> _allEmployees = [];
  Map<String, List<String>> _rolesByEmployeeId = {};
  List<Employee> _baseEmployees = [];
  Future<void>? _loadBaseFuture;

  final Map<String, String> _visitTypes = const {
    'PERIODIC': 'Périodique',
    'SURVEILLANCE_PARTICULIERE': 'Surveillance particulière',
    'MEDICAL_CALL': 'À l\'appel du médecin',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _api = Provider.of<ApiService>(context, listen: false);
    // Preload employees and users once to build roles map and base filtered list
    _loadBaseFuture ??= _loadBaseData();
  }

  @override
  void dispose() {
    _medicalInstructionsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  // Normalize strings (lowercase + strip common French accents)
  String _normalize(String? s) {
    if (s == null) return '';
    final lower = s.toLowerCase();
    const Map<String, String> map = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'ç': 'c',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
    };
    final sb = StringBuffer();
    for (final ch in lower.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  String _normalizeRole(String role) {
    var name = role.trim().toUpperCase();
    if (name.startsWith('ROLE_')) name = name.substring(5);
    if (name == 'RH') name = 'HR';
    if (name == 'INFIRMIER') name = 'NURSE';
    if (name == 'MEDECIN') name = 'DOCTOR';
    return name;
  }

  bool _isMedicalRole(Employee e) {
    final jt = _normalize(e.jobTitle);
    if (jt.isEmpty) return false;
    const keywords = <String>{
      'infirmier',
      'infirmiere',
      'nurse',
      'medecin',
      'medicin',
      'medico',
      'doctor',
      'docteur',
    };
    for (final k in keywords) {
      if (jt.contains(k)) return true;
    }
    return false;
  }

  List<Employee> _applyStaticFilters(List<Employee> list) {
    return list.where((e) {
      // Exclude soft-deleted/inactive employees approximated by missing email
      final hasEmail = (e.email ?? '').trim().isNotEmpty;
      if (!hasEmail) return false;
      final roles = _rolesByEmployeeId[e.id] ?? const <String>[];
      if (roles.isNotEmpty) {
        final hasMedicalRole = roles.any((r) {
          final rr = r.trim().toUpperCase();
          return rr == 'NURSE' || rr == 'DOCTOR';
        });
        if (hasMedicalRole) return false;
      } else {
        if (_isMedicalRole(e)) return false;
      }
      return true;
    }).toList();
  }

  String _employeeSearchHaystack(Employee e) {
    final roles = _rolesByEmployeeId[e.id] ?? const <String>[];
    return [
      e.firstName,
      e.lastName,
      e.department,
      e.jobTitle,
      e.cin,
      e.cnssNumber,
      e.email,
      roles.join(' '),
    ].whereType<String>().map(_normalize).join(' ');
  }

  Future<void> _loadBaseData() async {
    // Fetch employees first; even if users fetch fails, keep a usable base list.
    List<Employee> employees = <Employee>[];
    try {
      employees = await _api.getAllEmployees();
      if (!mounted) return;
      setState(() {
        _allEmployees = employees;
        // Build roles map from employees if backend provides roles in DTO
        final map = <String, List<String>>{};
        for (final e in employees) {
          final rs = e.roles;
          if (rs != null && rs.isNotEmpty) {
            final norm = rs
                .map((r) => _normalizeRole(r))
                .where((r) => r.isNotEmpty)
                .toList();
            if (norm.isNotEmpty) map[e.id] = norm;
          }
        }
        _rolesByEmployeeId = map;
        // Compute base list now that roles are available
        _baseEmployees = _applyStaticFilters(employees);
      });
    } catch (e) {
      // If employees fetch fails (e.g., 403), leave base empty; UI will show no suggestions.
      return;
    }
    // Skip admin-only users/roles enrichment to avoid 403 for nurse role.
    // Rely on jobTitle-based filtering for medical staff when roles are unavailable.
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);
    try {
      final finalDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _selectedTime!.hour,
        _selectedTime!.minute,
      );

      final planRequest = {
        'employeeId': int.parse(_selectedEmployee!.id),
        'type': _selectedVisitType ?? 'PERIODIC',
        'scheduledDateTime': finalDateTime.toIso8601String(),
        'visitMode': _visitMode,
        'medicalInstructions': _medicalInstructionsCtrl.text.trim().isEmpty
            ? null
            : _medicalInstructionsCtrl.text.trim(),
      };

      await _api.planMedicalVisit(planRequest);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rendez-vous planifié avec succès.')),
      );
      // Reset form
      setState(() {
        _selectedEmployee = null;
        _employeeCtrl.text = '';
        _selectedDate = null;
        _selectedTime = null;
        _selectedVisitType = null;
        _visitMode = 'IN_PERSON';

        _medicalInstructionsCtrl.clear();
      });
      // Notify parent dashboard to refresh counts/notifications
      widget.onNotificationUpdate?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  InputDecoration _decoration(
      {String? label, String? hint, Widget? prefixIcon, Widget? suffixIcon}) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(8);
    final baseBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: focusedBorder,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Form(
          key: _formKey,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planifier une visite',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Créer une demande pour un salarié (types autorisés: périodique, surveillance particulière, à l\'appel du médecin)',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 16),
                _buildEmployeeTypeahead(),
                const SizedBox(height: 8),
                _buildEmployeeInfoButton(),
                const SizedBox(height: 16),
                _buildVisitTypeDropdown(),
                const SizedBox(height: 16),
                _buildDateTimePickers(),
                const SizedBox(height: 16),
                _buildVisitModeRadios(),
                const SizedBox(height: 16),
                _buildMedicalInstructionsField(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: Builder(
                    builder: (ctx) {
                      final enabled = !(_isSubmitting ||
                          _selectedEmployee == null ||
                          _selectedDate == null ||
                          _selectedTime == null);
                      return GradientButton(
                        onPressed: enabled ? _submit : null,
                        gradient: LinearGradient(colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.primary.withOpacity(0.85),
                        ]),
                        radius: 8,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(Icons.medical_services_outlined,
                                      size: 18, color: Colors.white),
                                  SizedBox(width: 8),
                                  Text('Créer la demande',
                                      style: TextStyle(color: Colors.white)),
                                ],
                              ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmployeeTypeahead() {
    return TypeAheadField<Employee?>(
      hideOnEmpty: false,
      showOnFocus: true,
      debounceDuration: const Duration(milliseconds: 200),
      suggestionsCallback: (pattern) async {
        final q = _normalize(pattern);
        try {
          await (_loadBaseFuture ??= _loadBaseData());
        } catch (_) {}
        final source = _baseEmployees;
        if (q.isEmpty) {
          // Show all employees immediately when focusing/clicking the field
          return source;
        }
        final results = source
            .where((emp) {
              final hay = _employeeSearchHaystack(emp);
              return hay.contains(q);
            })
            .take(20)
            .toList();
        return results;
      },
      itemBuilder: (context, Employee? suggestion) {
        final e = suggestion!;
        final theme = Theme.of(context);
        final fullName =
            e.fullName.isNotEmpty ? e.fullName : 'Salarié #${e.id}';
        final email = (e.email ?? '').trim();
        final job = (e.jobTitle ?? '').trim();
        final dept = (e.department ?? '').trim();
        final rolesRaw = _rolesByEmployeeId[e.id] ?? const <String>[];
        final rolesNorm = rolesRaw.map(_normalizeRole).toList();
        String _computePrimaryRole() {
          // Prefer non-medical roles. Fallback by job title keywords.
          final filtered =
              rolesNorm.where((r) => r != 'NURSE' && r != 'DOCTOR').toList();
          String pickFrom(List<String> order) {
            for (final k in order) {
              if (filtered.contains(k)) return k;
            }
            return filtered.isNotEmpty ? filtered.first : '';
          }

          var r = pickFrom(['ADMIN', 'HSE', 'HR', 'MANAGER', 'EMPLOYEE']);
          if (r.isEmpty) {
            final jt = _normalize(e.jobTitle);
            if (jt.contains('admin'))
              r = 'ADMIN';
            else if (jt.contains('hse'))
              r = 'HSE';
            else if (jt.contains('hr') || jt.contains('rh'))
              r = 'HR';
            else
              r = 'EMPLOYEE';
          }
          return r;
        }

        String _displayRoleLabel(String r) {
          switch (r) {
            case 'HR':
              return 'RH';
            case 'HSE':
              return 'HSE';
            case 'MANAGER':
              return 'Manager';
            case 'EMPLOYEE':
              return 'Employee';
            default:
              if (r.isEmpty) return 'Employee';
              return r[0] + r.substring(1).toLowerCase();
          }
        }

        final primaryRole = _computePrimaryRole();
        String _chipText(String r) => (_displayRoleLabel(r)).toUpperCase();
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: theme.colorScheme.primaryContainer,
            foregroundColor: theme.colorScheme.onPrimaryContainer,
            child: Text(e.initials),
          ),
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Text(
              fullName,
              maxLines: 1,
              softWrap: false,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.email,
                          size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            email,
                            maxLines: 1,
                            softWrap: false,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (job.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.work_outline,
                          size: 16, color: theme.colorScheme.outline),
                      const SizedBox(width: 6),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Text(
                            job,
                            maxLines: 1,
                            softWrap: false,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (primaryRole.isNotEmpty || dept.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (primaryRole.isNotEmpty)
                        Chip(
                          label: Text(_chipText(primaryRole)),
                          visualDensity: VisualDensity.compact,
                        ),
                      if (dept.isNotEmpty)
                        Chip(
                          avatar: Icon(
                            Icons.apartment_outlined,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          label: Text(dept),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                ),
            ],
          ),
          isThreeLine: true,
        );
      },
      onSelected: (Employee? suggestion) {
        final e = suggestion!;
        setState(() => _selectedEmployee = e);
        _employeeCtrl.text = e.fullName;
      },
      builder: (context, controller, focusNode) {
        _employeeCtrl = controller;
        return TextFormField(
          controller: controller,
          focusNode: focusNode,
          onChanged: (value) {
            if (_selectedEmployee != null) {
              final selectedName = _selectedEmployee!.fullName;
              if (value.trim() != selectedName) {
                setState(() => _selectedEmployee = null);
              }
            }
          },
          decoration: _decoration(
            label: 'Salarié',
            hint: 'Rechercher un salarié',
            prefixIcon: const Icon(Icons.search),
          ),
          validator: (_) => _selectedEmployee == null
              ? 'Veuillez sélectionner un employé dans la liste.'
              : null,
        );
      },
      emptyBuilder: (context) => const Padding(
        padding: EdgeInsets.all(8.0),
        child:
            Text('Aucun employé trouvé.', style: TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildEmployeeInfoButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _selectedEmployee != null ? _showEmployeeInfo : null,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Afficher informations'),
      ),
    );
  }

  void _showEmployeeInfo() {
    if (_selectedEmployee == null) return;
    final emp = _selectedEmployee!;
    final theme = Theme.of(context);

    String _fmtDate(DateTime? d) {
      if (d == null) return '-';
      String two(int n) => n.toString().padLeft(2, '0');
      return '${two(d.day)}/${two(d.month)}/${d.year}';
    }

    Widget sectionTitle(IconData icon, String title) {
      return Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.35)),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ],
      );
    }

    Widget kvRow(String label, String value, {IconData? icon, Color? color}) {
      final c = color ?? theme.colorScheme.onSurface.withOpacity(0.75);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: theme.colorScheme.onSurface.withOpacity(0.65)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.65),
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(value.isNotEmpty ? value : '-',
                      style: theme.textTheme.bodyMedium?.copyWith(color: c)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final fullName =
        emp.fullName.isNotEmpty ? emp.fullName : 'Salarié #${emp.id}';

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Informations du salarié',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                'Détails complets du salarié sélectionné',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fermer',
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(ctx).pop(),
                        )
                      ],
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle(
                                Icons.person_outline, 'Informations de base'),
                            const SizedBox(height: 12),
                            kvRow('Nom complet', fullName,
                                icon: Icons.badge_outlined),
                            kvRow('Identifiant', emp.id,
                                icon: Icons.fingerprint_outlined),
                            kvRow('Email', (emp.email ?? '').trim(),
                                icon: Icons.email_outlined),
                            kvRow('Poste', (emp.jobTitle ?? '').trim(),
                                icon: Icons.work_outline),
                            kvRow('Département', (emp.department ?? '').trim(),
                                icon: Icons.account_tree_outlined),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            sectionTitle(Icons.info_outline,
                                'Informations personnelles'),
                            const SizedBox(height: 12),
                            kvRow('Adresse', (emp.address ?? '').trim(),
                                icon: Icons.home_outlined),
                            kvRow('Ville', (emp.city ?? '').trim(),
                                icon: Icons.location_city_outlined),
                            kvRow('Code postal', (emp.zipCode ?? '').trim(),
                                icon: Icons.local_post_office_outlined),
                            kvRow('Pays', (emp.country ?? '').trim(),
                                icon: Icons.public_outlined),
                            kvRow('Téléphone', (emp.phoneNumber ?? '').trim(),
                                icon: Icons.phone_outlined),
                            kvRow('Date de naissance', _fmtDate(emp.birthDate),
                                icon: Icons.cake_outlined),
                            kvRow('Lieu de naissance',
                                (emp.birthPlace ?? '').trim(),
                                icon: Icons.place_outlined),
                            kvRow("Date d'embauche", _fmtDate(emp.hireDate),
                                icon: Icons.event_available_outlined),
                            kvRow('CIN', (emp.cin ?? '').trim(),
                                icon: Icons.badge_outlined),
                            kvRow('CNSS', (emp.cnssNumber ?? '').trim(),
                                icon: Icons.credit_card_outlined),
                            kvRow(
                                'État civil', (emp.maritalStatus ?? '').trim(),
                                icon: Icons.family_restroom_outlined),
                            if (emp.childrenCount != null)
                              kvRow('Enfants', emp.childrenCount.toString(),
                                  icon: Icons.child_friendly_outlined),
                            kvRow('Genre', (emp.gender ?? '').trim(),
                                icon: Icons.wc_outlined),
                            kvRow('Profil complété',
                                emp.profileCompleted ? 'Oui' : 'Non',
                                icon: Icons.verified_user_outlined),
                            if (emp.manager != null)
                              kvRow(
                                  'Manager',
                                  emp.manager!.fullName.isNotEmpty
                                      ? emp.manager!.fullName
                                      : 'Salarié #${emp.manager!.id}',
                                  icon: Icons.supervisor_account_outlined),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDateTimePickers() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            readOnly: true,
            onTap: _pickDate,
            decoration: _decoration(
              label: 'Date souhaitée',
              hint: 'Sélectionner une date',
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            controller: TextEditingController(
              text: _selectedDate == null
                  ? ''
                  : DateFormat('dd/MM/yyyy').format(_selectedDate!),
            ),
            validator: (_) => _selectedDate == null ? 'Choisir une date' : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: TextFormField(
            readOnly: true,
            onTap: _pickTime,
            decoration: _decoration(
              label: 'Heure souhaitée',
              hint: 'Sélectionner une heure',
              suffixIcon: const Icon(Icons.access_time),
            ),
            controller: TextEditingController(
              text: _selectedTime == null ? '' : _selectedTime!.format(context),
            ),
            validator: (_) =>
                _selectedTime == null ? 'Choisir une heure' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildVisitTypeDropdown() {
    final current = _selectedVisitType ?? 'PERIODIC';
    return DropdownButtonFormField<String>(
      value: current,
      items: _visitTypes.entries
          .map((e) => DropdownMenuItem(
                value: e.key,
                child: Text(e.value),
              ))
          .toList(),
      onChanged: (v) => setState(() => _selectedVisitType = v),
      decoration: _decoration(label: 'Type de visite'),
    );
  }

  Widget _buildVisitModeRadios() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modalité',
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Présentiel'),
                value: 'IN_PERSON',
                groupValue: _visitMode,
                onChanged: (v) => setState(() => _visitMode = v ?? 'IN_PERSON'),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                contentPadding: EdgeInsets.zero,
                title: const Text('À distance'),
                value: 'REMOTE',
                groupValue: _visitMode,
                onChanged: (v) => setState(() => _visitMode = v ?? 'IN_PERSON'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVisitModeDropdown() {
    return DropdownButtonFormField<String>(
      value: _visitMode,
      items: const [
        DropdownMenuItem(value: 'IN_PERSON', child: Text('Présentiel')),
        DropdownMenuItem(value: 'REMOTE', child: Text('À distance')),
      ],
      onChanged: (v) => setState(() => _visitMode = v ?? 'IN_PERSON'),
      decoration: _decoration(label: 'Modalité'),
      validator: (v) => v == null ? 'Choisir un mode' : null,
    );
  }

  Widget _buildMedicalInstructionsField() {
    return TextFormField(
      controller: _medicalInstructionsCtrl,
      maxLines: 3,
      decoration: _decoration(
        label: 'Consignes ou remarques',
        hint: 'Instructions ou recommandations spécifiques (optionnel)',
        prefixIcon: const Icon(Icons.medical_services),
      ),
    );
  }
}

class _ConsulterTab extends StatefulWidget {
  final VoidCallback? onNotificationUpdate;
  final String? initialStatusFilter;
  final String? initialTypeFilter;
  final String? initialVisitModeFilter;
  final String? initialDepartmentFilter;
  final String? initialSearch;

  const _ConsulterTab({
    this.onNotificationUpdate,
    this.initialStatusFilter,
    this.initialTypeFilter,
    this.initialVisitModeFilter,
    this.initialDepartmentFilter,
    this.initialSearch,
  });

  @override
  State<_ConsulterTab> createState() => _ConsulterTabState();
}

class _ConsulterTabState extends State<_ConsulterTab> {
  late ApiService _api;
  bool _initialized = false;

  // Data
  List<Appointment> _appointments = [];
  List<Employee> _allEmployees = [];

  // UI state
  bool _loadingList = false;
  bool _resetting = false;
  String _statusFilter =
      'En attente'; // Tous | En attente | Proposé | Confirmé | Annulé | Terminé
  String _typeFilter = 'Tous'; // Tous | Embauche | Reprise
  String _visitModeFilter = 'Tous'; // Tous | Présentiel | À distance
  String _departmentFilter = 'Tous';
  String _search = '';

  @override
  void initState() {
    super.initState();
    // Apply initial filters if provided by navigation
    if (widget.initialStatusFilter != null) {
      _statusFilter = widget.initialStatusFilter!;
    }
    if (widget.initialTypeFilter != null) {
      _typeFilter = widget.initialTypeFilter!;
    }
    if (widget.initialVisitModeFilter != null) {
      _visitModeFilter = widget.initialVisitModeFilter!;
    }
    if (widget.initialDepartmentFilter != null) {
      _departmentFilter = widget.initialDepartmentFilter!;
    }
    if (widget.initialSearch != null) {
      _search = widget.initialSearch!;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _api = Provider.of<ApiService>(context, listen: false);
      _initialized = true;
      _fetchAppointments();
    }
  }

  // Map UI labels to backend enum values for API communication
  String? _statusLabelToBackendEnum(String label) {
    // This is NOT data generation - just translation for API calls
    switch (label) {
      case 'En attente':
        return 'REQUESTED_EMPLOYEE';
      case 'Proposé':
        return 'PROPOSED_MEDECIN';
      case 'Confirmé':
        return 'CONFIRMED';
      case 'Annulé':
        return 'CANCELLED';
      case 'Terminé':
        return 'COMPLETED';
      default:
        return null; // Tous
    }
  }

  // Input decoration (match HR styling)
  InputDecoration _decoration(
      {String? label, String? hint, Widget? prefixIcon}) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(8);
    final baseBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
    );
    final focusedBorder = OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
    );
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: baseBorder,
      enabledBorder: baseBorder,
      focusedBorder: focusedBorder,
      prefixIcon: prefixIcon,
    );
  }

  Future<void> _fetchEmployees() async {
    try {
      final list = await _api.getAllEmployees();
      if (!mounted) return;
      setState(() => _allEmployees = list);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors du chargement des employés: $e')),
      );
    }
  }

  Employee? _findEmployeeForAppointment(Appointment a) {
    final idStr = a.employeeId.toString();
    for (final e in _allEmployees) {
      if (e.id == idStr) return e;
    }
    return null;
  }

  Future<void> _fetchAppointments() async {
    setState(() => _loadingList = true);
    try {
      final Map<String, dynamic> filters = {
        'page': 0,
        'size': 50,
        'sort': 'createdAt,desc',
      };
      // Apply type filter to backend when specified
      if (_typeFilter != 'Tous') {
        final vt = _typeFilter == 'Embauche' ? 'EMBAUCHE' : 'REPRISE';
        filters['visitType'] = vt; // ApiService will normalize
      }
      // Apply status filter
      if (_statusFilter == 'En attente') {
        // Pending should include both employee-requested and HR-initiated obligatory visits
        filters['statuses'] = ['REQUESTED_EMPLOYEE', 'OBLIGATORY'];
      } else {
        // Use single status mapping for other categories
        final statusEnum = _statusLabelToBackendEnum(_statusFilter);
        if (statusEnum != null) filters['status'] = statusEnum;
      }

      // Apply visit mode filter to backend when specified
      if (_visitModeFilter != 'Tous') {
        final vm = _visitModeFilter == 'Présentiel' ? 'IN_PERSON' : 'REMOTE';
        filters['visitMode'] = vm;
      }

      final data = await _api.getAppointments(filters);
      final list = (data['appointments'] as List<Appointment>);
      if (!mounted) return;
      setState(() {
        _appointments = list;
        _loadingList = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingList = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Erreur lors du chargement des rendez-vous: $e')),
      );
    }
  }

  Future<void> _refresh() => _fetchAppointments();

  Future<void> _confirmAndReset() async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            title: const Text('Réinitialiser mes données (TEST)'),
            content: const Text(
                'Cette action va supprimer TOUTES vos notifications et rendez-vous.\n\nUtilisez uniquement en environnement de test.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Annuler'),
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.error,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                icon: const Icon(Icons.delete_forever),
                label: const Text('Réinitialiser'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || _resetting) return;
    await _resetMyData();
  }

  Future<void> _resetMyData() async {
    setState(() => _resetting = true);
    try {
      final appts = await _api.getMyAppointments();
      final notifs = await _api.getMyNotifications();
      final apptIds = appts.map((a) => a.id).toList();
      final notifIds = notifs.map((n) => n.id).toList();

      List<int> failedN = const [];
      List<int> failedA = const [];
      if (notifIds.isNotEmpty) {
        failedN = await _api.deleteNotificationsBulk(notifIds);
      }
      if (apptIds.isNotEmpty) {
        failedA = await _api.deleteAppointmentsBulk(apptIds);
      }

      if (!mounted) return;
      final deletedN = notifIds.length - failedN.length;
      final deletedA = apptIds.length - failedA.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Réinitialisation terminée: $deletedA rendez-vous, $deletedN notifications supprimés.'),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la réinitialisation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _resetting = false);
        _fetchAppointments();
        widget.onNotificationUpdate?.call();
      }
    }
  }

  void _openConfirmOrPropose(Appointment a) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogCtx) {
          final theme = Theme.of(dialogCtx);
          final formKey = GlobalKey<FormState>();
          DateTime? proposedDate;
          TimeOfDay? proposedTime;
          String visitMode =
              (a.visitMode?.isNotEmpty ?? false) ? a.visitMode! : 'IN_PERSON';
          final notesCtrl = TextEditingController();
          bool isLoading = false;

          bool isValidDisplay(String? v) {
            if (v == null) return false;
            final t = v.trim();
            if (t.isEmpty) return false;
            if (t.toUpperCase() == 'N/A') return false;
            return true;
          }

          String employeeLabel() {
            String? name;
            String? email;

            bool looksLikeEmail(String? v) {
              if (v == null) return false;
              final s = v.trim();
              if (s.isEmpty) return false;
              final re = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
              return re.hasMatch(s);
            }

            // 1) Prefer appointment's own employee info (matches card logic visually)
            final rawName = a.employeeName;
            if (isValidDisplay(rawName)) name = rawName.trim();
            final rawEmail = a.employeeEmail;
            if (isValidDisplay(rawEmail)) email = rawEmail.trim();

            // 1.b) If the "name" we got looks like an email or equals email, try to improve using employee profile
            if (name == null || looksLikeEmail(name) ||
                (email != null && name != null && name!.trim().toLowerCase() == email!.trim().toLowerCase())) {
              final emp = _findEmployeeForAppointment(a);
              final fullName = emp?.fullName?.trim();
              final empEmail = emp?.email?.trim();
              if (isValidDisplay(fullName) && !looksLikeEmail(fullName)) {
                name = fullName;
              }
              if (email == null && isValidDisplay(empEmail)) {
                email = empEmail;
              }
            }

            // 2) If still missing, try the creator when it's an EMPLOYEE or has an employee profile
            if (name == null || email == null) {
              final createdBy = a.createdBy;
              if (createdBy != null &&
                  (createdBy.hasRole('EMPLOYEE') || createdBy.employee != null)) {
                final createdName = createdBy.employee?.fullName;
                final createdEmail = createdBy.employee?.email ?? createdBy.email;
                if (name == null && isValidDisplay(createdName) && !looksLikeEmail(createdName)) {
                  name = createdName!.trim();
                }
                if (email == null && isValidDisplay(createdEmail)) {
                  email = createdEmail.trim();
                }
              }
            }

            // 3) Final fallback: current user from AuthService if still missing
            if (name == null || email == null) {
              try {
                final auth = Provider.of<AuthService>(dialogCtx, listen: false);
                final user = auth.user;
                final currentName = user?.employee?.fullName;
                final currentEmail = user?.employee?.email ?? user?.email;
                if (name == null && isValidDisplay(currentName) && !looksLikeEmail(currentName)) {
                  name = currentName!.trim();
                }
                if (email == null && isValidDisplay(currentEmail)) {
                  email = currentEmail!.trim();
                }
              } catch (_) {
                // ignore when AuthService is not available in this context
              }
            }

            // 4) Build label with de-duplication rules
            if (name != null && email != null) {
              final n = name!.trim();
              final e = email!.trim();
              if (n.toLowerCase() == e.toLowerCase() || looksLikeEmail(n)) {
                return e; // avoid duplicate like "email — email"
              }
              return '$n — $e';
            }
            if (name != null) return name!;
            if (email != null) return email!;
            return 'Employé #${a.employeeId}';
          }

          Future<void> pickDate(StateSetter setState) async {
            final picked = await showDatePicker(
              context: dialogCtx,
              initialDate: proposedDate ?? DateTime.now(),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) setState(() => proposedDate = picked);
          }

          Future<void> pickTime(StateSetter setState) async {
            final picked = await showTimePicker(
              context: dialogCtx,
              initialTime: proposedTime ?? TimeOfDay.now(),
            );
            if (picked != null) setState(() => proposedTime = picked);
          }

          Future<void> submit(StateSetter setState) async {
            if (!(formKey.currentState?.validate() ?? false)) return;
            if (proposedDate == null || proposedTime == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Veuillez sélectionner une date et une heure.')),
              );
              return;
            }
            setState(() => isLoading = true);
            try {
              final finalDate = DateTime(
                proposedDate!.year,
                proposedDate!.month,
                proposedDate!.day,
                proposedTime!.hour,
                proposedTime!.minute,
              );
              await _api.proposeAppointmentSlot(
                appointmentId: a.id,
                proposedDate: finalDate,
                comments: notesCtrl.text,
                visitMode: visitMode,
              );
              // Refresh notifications to show the new proposal notification
              widget.onNotificationUpdate?.call();
              Navigator.of(dialogCtx).pop(true);
            } catch (e) {
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Erreur: $e')));
            } finally {
              if (mounted) setState(() => isLoading = false);
            }
          }

          return StatefulBuilder(
            builder: (ctx, setState) {
              return Dialog(
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                        left: 16,
                        right: 16,
                        top: 16,
                        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Header
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.35),
                                  ),
                                ),
                                child: Icon(Icons.event_available_outlined,
                                    size: 20, color: theme.colorScheme.primary),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Proposer un créneau',
                                        style: theme.textTheme.titleLarge
                                            ?.copyWith(
                                                fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Pour ${employeeLabel()}',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurface
                                            .withOpacity(0.65),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Fermer',
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(dialogCtx).pop(),
                              )
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Card form
                          Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Form(
                                key: formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Date / Time
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            readOnly: true,
                                            onTap: () => pickDate(setState),
                                            decoration: _decoration(
                                              label: 'Date',
                                              hint: 'Choisir...',
                                              prefixIcon: const Icon(
                                                  Icons.calendar_today),
                                            ),
                                            controller: TextEditingController(
                                              text: proposedDate == null
                                                  ? ''
                                                  : DateFormat('dd/MM/yyyy')
                                                      .format(proposedDate!),
                                            ),
                                            validator: (_) =>
                                                proposedDate == null
                                                    ? 'Sélectionner une date'
                                                    : null,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            readOnly: true,
                                            onTap: () => pickTime(setState),
                                            decoration: _decoration(
                                              label: 'Heure',
                                              hint: 'Choisir...',
                                              prefixIcon:
                                                  const Icon(Icons.access_time),
                                            ),
                                            controller: TextEditingController(
                                              text: proposedTime == null
                                                  ? ''
                                                  : proposedTime!.format(ctx),
                                            ),
                                            validator: (_) =>
                                                proposedTime == null
                                                    ? 'Sélectionner une heure'
                                                    : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Visit mode radios (match Planifier)
                                    Text('Modalité',
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: RadioListTile<String>(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text('Présentiel'),
                                            value: 'IN_PERSON',
                                            groupValue: visitMode,
                                            onChanged: (v) => setState(() =>
                                                visitMode = v ?? 'IN_PERSON'),
                                          ),
                                        ),
                                        Expanded(
                                          child: RadioListTile<String>(
                                            contentPadding: EdgeInsets.zero,
                                            title: const Text('À distance'),
                                            value: 'REMOTE',
                                            groupValue: visitMode,
                                            onChanged: (v) => setState(() =>
                                                visitMode = v ?? 'IN_PERSON'),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    // Notes
                                    TextFormField(
                                      controller: notesCtrl,
                                      maxLines: 3,
                                      decoration: _decoration(
                                              label: 'Justification',
                                              hint: 'Notes / remarques')
                                          .copyWith(alignLabelWithHint: true),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Submit
                          SizedBox(
                            width: double.infinity,
                            child: GradientButton(
                              onPressed:
                                  isLoading ? null : () => submit(setState),
                              gradient: LinearGradient(colors: [
                                theme.colorScheme.primary,
                                theme.colorScheme.primary.withOpacity(0.85),
                              ]),
                              radius: 10,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text('Proposer ce Créneau',
                                      style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
      if (!mounted) return;
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Créneau proposé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAppointments();
        widget.onNotificationUpdate?.call();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la proposition: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleConfirmAppointment(Appointment appointment) async {
    final visitMode = await _showVisitModeDialog();
    if (visitMode == null) return;

    final confirmed = await showConfirmDialog(context);
    if (!confirmed) return;

    try {
      await _api.confirmAppointment(appointment.id, visitMode: visitMode);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rendez-vous confirmé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      _fetchAppointments();
      // Notifier le parent pour recharger les notifications
      widget.onNotificationUpdate?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la confirmation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openCancel(Appointment appointment) async {
    final reason = await _showCancellationDialog();
    if (reason == null || reason.trim().isEmpty) return;

    try {
      await _api.cancelAppointment(appointment.id, reason: reason.trim());
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rendez-vous annulé avec succès'),
          backgroundColor: Colors.green,
        ),
      );

      _fetchAppointments();
      widget.onNotificationUpdate?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de l\'annulation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<String?> _showVisitModeDialog() async {
    return showDialog<String>(
      context: context,
      builder: (context) {
        String selectedMode = 'IN_PERSON';
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: const Text('Modalité'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Veuillez choisir la modalité :'),
                  const SizedBox(height: 16),
                  RadioListTile<String>(
                    title: const Text('Présentiel'),
                    value: 'IN_PERSON',
                    groupValue: selectedMode,
                    onChanged: (value) {
                      setState(() => selectedMode = value!);
                    },
                  ),
                  RadioListTile<String>(
                    title: const Text('À distance'),
                    value: 'REMOTE',
                    groupValue: selectedMode,
                    onChanged: (value) {
                      setState(() => selectedMode = value!);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(selectedMode),
                  child: const Text('Confirmer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String?> _showCancellationDialog() async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        final formKey = GlobalKey<FormState>();
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: const Text('Annuler le rendez-vous'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Veuillez indiquer la raison de l\'annulation:'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: controller,
                  decoration: const InputDecoration(
                    labelText: 'Raison de l\'annulation',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Veuillez indiquer une raison';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Retour'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  Navigator.of(context).pop(controller.text.trim());
                }
              },
              child: const Text('Confirmer l\'annulation'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Build department items once (unique + sorted)
    final departments = _allEmployees
        .map((e) => (e.department ?? '').trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    final departmentItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: 'Tous', child: Text('Tous')),
      ...departments
          .map((d) => DropdownMenuItem<String>(value: d, child: Text(d))),
    ];

    // Client-side filtering for search and department
    final filtered = _appointments.where((a) {
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        final match = a.employeeName.toLowerCase().contains(q) ||
            a.employeeEmail.toLowerCase().contains(q);
        if (!match) return false;
      }
      if (_departmentFilter != 'Tous') {
        final emp = _findEmployeeForAppointment(a);
        final dept = (emp?.department ?? '').trim();
        if (dept.isEmpty || dept != _departmentFilter) return false;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt_outlined,
                        color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    const SizedBox(width: 8),
                    const Text('Filtres de recherche',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      crossAxisAlignment: WrapCrossAlignment.start,
                      children: [
                        SizedBox(
                          width: 280,
                          child: TextField(
                            decoration: _decoration(
                              label: 'Rechercher',
                              hint: 'Nom ou e-mail...',
                              prefixIcon: const Icon(Icons.search),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: _decoration(label: 'Statut'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Tous', child: Text('Tous')),
                              DropdownMenuItem(
                                  value: 'En attente',
                                  child: Text('En attente')),
                              DropdownMenuItem(
                                  value: 'Proposé', child: Text('Proposé')),
                              DropdownMenuItem(
                                  value: 'Confirmé', child: Text('Confirmé')),
                              DropdownMenuItem(
                                  value: 'Annulé', child: Text('Annulé')),
                              DropdownMenuItem(
                                  value: 'Terminé', child: Text('Terminé')),
                            ],
                            onChanged: (v) {
                              setState(() => _statusFilter = v ?? 'Tous');
                              _fetchAppointments();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: _typeFilter,
                            decoration: _decoration(label: 'Type'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Tous', child: Text('Tous')),
                              DropdownMenuItem(
                                  value: 'Embauche', child: Text('Embauche')),
                              DropdownMenuItem(
                                  value: 'Reprise', child: Text('Reprise')),
                            ],
                            onChanged: (v) {
                              setState(() => _typeFilter = v ?? 'Tous');
                              _fetchAppointments();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 180,
                          child: DropdownButtonFormField<String>(
                            value: _visitModeFilter,
                            decoration: _decoration(label: 'Modalité'),
                            items: const [
                              DropdownMenuItem(
                                  value: 'Tous', child: Text('Tous')),
                              DropdownMenuItem(
                                  value: 'Présentiel',
                                  child: Text('Présentiel')),
                              DropdownMenuItem(
                                  value: 'À distance',
                                  child: Text('À distance')),
                            ],
                            onChanged: (v) {
                              setState(() => _visitModeFilter = v ?? 'Tous');
                              _fetchAppointments();
                            },
                          ),
                        ),
                        SizedBox(
                          width: 220,
                          child: DropdownButtonFormField<String>(
                            value: _departmentFilter,
                            decoration: _decoration(label: 'Département'),
                            items: departmentItems,
                            onChanged: (v) async {
                              final val = v ?? 'Tous';
                              if (val != 'Tous' && _allEmployees.isEmpty) {
                                await _fetchEmployees();
                              }
                              if (!mounted) return;
                              setState(() => _departmentFilter = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          IconButton(
                            tooltip: 'Actualiser',
                            onPressed: _loadingList ? null : _fetchAppointments,
                            icon: _loadingList
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                                : const Icon(Icons.refresh),
                          ),
                          if (AppConfig.showTestResetButton)
                            OutlinedButton.icon(
                              onPressed: (_loadingList || _resetting)
                                  ? null
                                  : _confirmAndReset,
                              icon: _resetting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.delete_forever,
                                      color: Colors.red),
                              label: const Text('Reset (Test)'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.redAccent),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_loadingList)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(child: Text('Aucun rendez-vous trouvé.')),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 8.0),
                  child: Column(
                    children: [
                      for (final a in filtered)
                        AppointmentCard(
                          appointment: a,
                          // Backend determines available actions via action flags
                          onConfirm: () => _handleConfirmAppointment(a),
                          onPropose: () => _openConfirmOrPropose(a),
                          onCancel: () => _openCancel(a),
                          isNurseView: true,
                          canSeePrivateInfo:
                              true, // Service médical peut voir consignes et téléphone
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  // Backend-driven action visibility logic
}
