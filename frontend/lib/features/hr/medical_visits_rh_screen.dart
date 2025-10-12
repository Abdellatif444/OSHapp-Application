import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/models/appointment.dart';
import 'package:oshapp/features/appointments/widgets/employee_selection_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:oshapp/shared/models/role.dart';
import 'package:oshapp/features/hr/widgets/medical_visit_card.dart';

// Top-level GradientButton widget for primary actions with gradient background
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Gradient gradient;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool showGradientWhenDisabled;

  const GradientButton({
    super.key,
    required this.onPressed,
    required this.child,
    required this.gradient,
    this.radius = 8,
    this.padding = const EdgeInsets.symmetric(vertical: 14),
    this.showGradientWhenDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = onPressed == null;
    final borderRadius = BorderRadius.circular(radius);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: (isDisabled && !showGradientWhenDisabled) ? null : gradient,
        color: (isDisabled && !showGradientWhenDisabled)
            ? theme.disabledColor.withOpacity(0.12)
            : null,
        borderRadius: borderRadius,
        boxShadow: (isDisabled && !showGradientWhenDisabled)
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius,
          child: Padding(
            padding: padding,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class MedicalVisitsRhScreen extends StatefulWidget {
  final bool initialPlanifier;
  const MedicalVisitsRhScreen({super.key, this.initialPlanifier = false});

  @override
  State<MedicalVisitsRhScreen> createState() => _MedicalVisitsRhScreenState();
}

class _MedicalVisitsRhScreenState extends State<MedicalVisitsRhScreen> {
  // Toggle between views
  bool _isPlanifier = false; // Default to Consulter as in existing styling

  // Planifier form state
  final _formKey = GlobalKey<FormState>();
  List<Employee> _allEmployees = [];
  List<Employee> _selectedEmployees = [];
  bool _loadingEmployees = false;
  Map<String, List<String>> _rolesByEmployeeId = {};
  DateTime? _visitDate;
  String _visitType = 'EMBAUCHE'; // Allowed: EMBAUCHE | REPRISE
  bool _submitting = false;
  final TextEditingController _notesController = TextEditingController();
  // Reprise-specific fields
  String? _repriseCase; // AT_MP | HORS_AT_MP | MAT_PAT_ADO | AMENAGEMENT
  // Reprise certificates
  final List<PlatformFile> _selectedCertificates = [];

  // Consulter list state
  bool _loadingList = false;
  List<Appointment> _appointments = [];
  String _search = '';
  final Set<String> _selectedTypes = {'EMBAUCHE', 'REPRISE'};
  // New filters
  String _statusFilter =
      'Tous'; // Tous | En attente | Proposé | Confirmé | Annulé | Terminé
  String _typeFilter = 'Tous'; // Tous | Embauche | Reprise
  String _departmentFilter = 'Tous'; // Tous | <department>

  @override
  void initState() {
    super.initState();
    // Select initial tab and load data accordingly
    _isPlanifier = widget.initialPlanifier;
    if (_isPlanifier) {
      _fetchEmployees();
    } else {
      // When landing on Consulter, prefetch employees so cards can render real names/phones immediately
      _fetchAppointments();
      _fetchEmployees();
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _fetchEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final employees = await api.getAllEmployees();
      // Fetch users to map roles to employees
      final users = await api.getAllUsers();
      // Build roles mapping keyed by employee.id (String)
      final Map<String, List<String>> rolesMap = {};
      for (final u in users) {
        final emp = u.employee;
        if (emp == null) continue;
        final empId = emp.id;
        if (empId.isEmpty) continue;
        final Set<String> normalized = {};
        for (final r in u.roles) {
          try {
            normalized.add(Role.fromString(r).name);
          } catch (_) {
            // ignore unknown roles
          }
        }
        if (normalized.isNotEmpty) {
          rolesMap[empId] = normalized.toList();
        }
      }

      if (!mounted) return;
      setState(() {
        _allEmployees = employees;
        _rolesByEmployeeId = rolesMap;
        _loadingEmployees = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingEmployees = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de chargement des employés: $e')),
      );
    }
  }

  Future<void> _fetchAppointments() async {
    setState(() => _loadingList = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);

      // If no type selected, show empty quickly
      if (_selectedTypes.isEmpty) {
        setState(() {
          _appointments = [];
          _loadingList = false;
        });
        return;
      }

      // Fetch per selected type and merge
      final Map<int, Appointment> map = {};
      for (final vt in _selectedTypes) {
        final data = await api.getAppointments({
          'page': 0,
          'size': 50,
          'sort': 'createdAt,desc',
          'visitType': vt, // ApiService will normalize
        });
        final list = (data['appointments'] as List<Appointment>);
        for (final a in list) {
          map[a.id] = a;
        }
      }

      final merged = map.values.toList()
        ..sort((a, b) => (b.createdAt).compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _appointments = merged;
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

  void _switchToPlanifier() {
    setState(() => _isPlanifier = true);
    if (_allEmployees.isEmpty) {
      _fetchEmployees();
    }
  }

  void _switchToConsulter() {
    setState(() => _isPlanifier = false);
    _fetchAppointments();
    if (_allEmployees.isEmpty) {
      // Prefetch employees so Département filter has values and can work client-side
      _fetchEmployees();
    }
  }

  void _openEmployeeSelectionDialog() {
    List<Employee> tempSelected = List.from(_selectedEmployees);
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
          title: const Text('Sélectionner des Employés'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 16,
            ),
            child: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: EmployeeSelectionWidget(
                allEmployees: _allEmployees,
                selectedEmployees: tempSelected,
                onSelectionChanged: (sel) => tempSelected = sel,
                rolesByEmployeeId: _rolesByEmployeeId,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() => _selectedEmployees = tempSelected);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
              ),
              child: const Text('Confirmer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _visitDate = picked);
    }
  }

  String _formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    return '$dd/$mm/$yyyy';
  }

  // Find the Employee model (from the cached list) for a given appointment
  Employee? _findEmployeeForAppointment(Appointment a) {
    final idStr = a.employeeId.toString();
    for (final e in _allEmployees) {
      if (e.id == idStr) return e;
    }
    return null;
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

  // Builds a smart display for selected employees inside the input-like selector.
  // - Empty: placeholder text
  // - One selected: name + email + job on separate lines
  // - Multiple: up to 3 compact chips with avatar and details, then "+N autres"
  Widget _buildSelectedEmployeesDisplay(ThemeData theme) {
    if (_selectedEmployees.isEmpty) {
      return Text(
        'Sélectionner un salarié',
        style: theme.textTheme.bodyMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      );
    }

    if (_selectedEmployees.length == 1) {
      final e = _selectedEmployees.first;
      final email = (e.email ?? '').trim();
      final job = (e.jobTitle ?? '').trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                    color: theme.colorScheme.primary, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  e.fullName.isNotEmpty ? e.fullName : 'Salarié #${e.id}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _selectedEmployees.removeWhere((x) => x.id == e.id);
                  });
                },
                child: Icon(Icons.close,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          if (email.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.email, size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      email,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          if (job.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.badge_outlined,
                      size: 16, color: theme.colorScheme.outline),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      job,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    // Show detailed blocks stacked for all selected employees, with internal scroll to avoid overflow
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 180),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (int i = 0; i < _selectedEmployees.length; i++) ...[
              _employeeDetailsBlock(theme, _selectedEmployees[i]),
              if (i != _selectedEmployees.length - 1) ...[
                const SizedBox(height: 6),
                Divider(),
                const SizedBox(height: 6),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _employeeDetailsBlock(ThemeData theme, Employee e) {
    final email = (e.email ?? '').trim();
    final job = (e.jobTitle ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  color: theme.colorScheme.primary, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                e.fullName.isNotEmpty ? e.fullName : 'Salarié #${e.id}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            InkWell(
              onTap: () {
                setState(() {
                  _selectedEmployees.removeWhere((x) => x.id == e.id);
                });
              },
              child: Icon(Icons.close,
                  size: 18, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        if (email.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.email, size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        if (job.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.badge_outlined,
                    size: 16, color: theme.colorScheme.outline),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    job,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  String _compactEmployeeLabel(Employee e) {
    final parts = <String>[];
    final name = e.fullName.isNotEmpty ? e.fullName : 'Salarié #${e.id}';
    parts.add(name);
    final email = (e.email ?? '').trim();
    if (email.isNotEmpty) parts.add(email);
    final job = (e.jobTitle ?? '').trim();
    if (job.isNotEmpty) parts.add(job);
    return parts.join(' · ');
  }

  Widget _employeeChip(ThemeData theme, Employee e) {
    return Chip(
      avatar: CircleAvatar(
        radius: 10,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
        child: Text(e.initials,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      ),
      label: Text(_compactEmployeeLabel(e)),
      visualDensity: VisualDensity.compact,
    );
  }

  // GradientButton moved to top-level for proper Dart class scope

  void _showEmployeeDetailsDialog(Employee emp) {
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
    final roles = _rolesByEmployeeId[emp.id] ?? const <String>[];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final roleWrap = Wrap(
          spacing: 6,
          runSpacing: -6,
          children: [
            for (final r in roles)
              Chip(
                label: Text(r),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
                backgroundColor: theme.colorScheme.primary.withOpacity(0.10),
                labelStyle: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600),
              ),
          ],
        );

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

                    // Section: Base Info
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
                            const SizedBox(height: 10),
                            if (roles.isNotEmpty)
                              Text('Rôles',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.65),
                                    fontWeight: FontWeight.w700,
                                  )),
                            if (roles.isNotEmpty) roleWrap,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    // Section: Personal Info
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

                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Fermer'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showEmployeesDetailsCarousel(List<Employee> employees) {
    if (employees.isEmpty) return;
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final controller = PageController();
        int currentIndex = 0;

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

        Widget kvRow(String label, String value,
            {IconData? icon, Color? color}) {
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
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.65),
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 2),
                      Text(value.isNotEmpty ? value : '-',
                          style:
                              theme.textTheme.bodyMedium?.copyWith(color: c)),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        Widget buildEmployeeContent(Employee emp) {
          final fullName =
              emp.fullName.isNotEmpty ? emp.fullName : 'Salarié #${emp.id}';
          final roles = _rolesByEmployeeId[emp.id] ?? const <String>[];
          final roleWrap = roles.isEmpty
              ? const SizedBox.shrink()
              : Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: [
                    for (final r in roles)
                      Chip(
                        label: Text(r),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: const StadiumBorder(),
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.10),
                        labelStyle: TextStyle(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Base Info
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
                      const SizedBox(height: 10),
                      if (roles.isNotEmpty)
                        Text('Rôles',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.65),
                              fontWeight: FontWeight.w700,
                            )),
                      if (roles.isNotEmpty) roleWrap,
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),
              // Personal Info
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
                          Icons.info_outline, 'Informations personnelles'),
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
                      kvRow('Lieu de naissance', (emp.birthPlace ?? '').trim(),
                          icon: Icons.place_outlined),
                      kvRow("Date d'embauche", _fmtDate(emp.hireDate),
                          icon: Icons.event_available_outlined),
                      kvRow('CIN', (emp.cin ?? '').trim(),
                          icon: Icons.badge_outlined),
                      kvRow('CNSS', (emp.cnssNumber ?? '').trim(),
                          icon: Icons.credit_card_outlined),
                      kvRow('État civil', (emp.maritalStatus ?? '').trim(),
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
          );
        }

        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return Dialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Informations des salariés (${currentIndex + 1}/${employees.length})',
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Balayez ou utilisez les flèches pour naviguer',
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

                      // PageView area
                      SizedBox(
                        height: 500,
                        child: PageView.builder(
                          controller: controller,
                          onPageChanged: (i) =>
                              setStateDialog(() => currentIndex = i),
                          itemCount: employees.length,
                          itemBuilder: (c, i) => SingleChildScrollView(
                            child: buildEmployeeContent(employees[i]),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          OutlinedButton.icon(
                            onPressed: currentIndex > 0
                                ? () {
                                    controller.previousPage(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut);
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Précédent'),
                          ),
                          OutlinedButton.icon(
                            onPressed: currentIndex < employees.length - 1
                                ? () {
                                    controller.nextPage(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        curve: Curves.easeInOut);
                                  }
                                : null,
                            icon: const Icon(Icons.chevron_right),
                            label: const Text('Suivant'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickCertificates() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        allowMultiple: true,
        withData: false, // do NOT load full bytes into memory
        withReadStream: true, // request readable streams for large files
      );
      if (result != null && result.files.isNotEmpty) {
        final picked = result.files
            .where((f) => (f.extension?.toLowerCase() == 'pdf'))
            .toList();
        setState(() {
          final existing =
              _selectedCertificates.map((f) => '${f.name}|${f.size}').toSet();
          for (final f in picked) {
            final key = '${f.name}|${f.size}';
            if (!existing.contains(key)) {
              _selectedCertificates.add(f);
              existing.add(key);
            }
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la sélection des fichiers: $e')),
      );
    }
  }

  void _removeCertificateAt(int index) {
    setState(() => _selectedCertificates.removeAt(index));
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes o';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} ko';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(2).replaceAll('.', ',')} Mo';
  }

  Future<void> _submitPlanification() async {
    if (_selectedEmployees.isEmpty || _visitDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Veuillez sélectionner des employés et une date.')),
      );
      return;
    }
    if (_visitType == 'REPRISE') {
      if (_repriseCase == null || _repriseCase!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Veuillez sélectionner le type de reprise.')),
        );
        return;
      }
    }
    setState(() => _submitting = true);
    try {
      final api = Provider.of<ApiService>(context, listen: false);
      final ids = _selectedEmployees.map((e) => int.parse(e.id)).toList();
      // Compose reason and notes for REPRISE
      String? reason;
      String? combinedNotes = _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim();
      if (_visitType == 'REPRISE') {
        switch (_repriseCase) {
          case 'AT_MP':
            reason = 'Absence pour AT/MP';
            break;
          case 'HORS_AT_MP':
            reason = 'Absence pour accident/maladie hors AT/MP';
            break;
          case 'MAT_PAT_ADO':
            reason = 'Absence pour maternité/paternité/adoption';
            break;
          case 'AMENAGEMENT':
            reason = 'Absence pour aménagement';
            break;
          default:
            break;
        }
      }
      // 1) Créer les RDV obligatoires
      await api.createObligatoryAppointments(ids, _visitDate!, _visitType,
          reason: reason, notes: combinedNotes);

      // 2) Uploader les certificats médicaux sélectionnés (si présents)
      final bool hadCerts = _selectedCertificates.isNotEmpty;
      int success = 0;
      int failed = 0;
      if (hadCerts) {
        for (final emp in _selectedEmployees) {
          final empId = int.parse(emp.id);
          for (final file in _selectedCertificates) {
            try {
              final path = (file.path ?? '').trim();
              if (path.isNotEmpty) {
                await api.uploadMedicalCertificate(
                  employeeId: empId,
                  filename: file.name,
                  filePath: path,
                );
              } else if (file.readStream != null) {
                await api.uploadMedicalCertificate(
                  employeeId: empId,
                  filename: file.name,
                  stream: file.readStream!,
                  length: file.size,
                );
              } else {
                // No path nor stream available
                failed++;
                continue;
              }
              success++;
            } catch (err) {
              failed++;
            }
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _submitting = false;
        // Réinitialiser la date; conserver les certificats si échecs pour réessayer
        _visitDate = null;
        if (failed == 0) {
          _selectedCertificates.clear();
        }
      });

      // 3) Feedback utilisateur
      if (!hadCerts) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Demande créée avec succès !')),
        );
      } else {
        if (failed == 0) {
          final total = success;
          final perEmp = _selectedEmployees.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Demande créée. Certificats téléversés avec succès ($total envois pour $perEmp salarié(s)).')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Demande créée. Téléversement des certificats: ${success} réussi(s), ${failed} échec(s).')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur lors de la planification: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Visites médicales (RH)'),
        backgroundColor: Colors.white,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header with action buttons (toggle)
          Center(
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
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
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
          const SizedBox(height: 16),

          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _isPlanifier
                ? _buildPlanifierSection(theme)
                : _buildConsulterSection(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanifierSection(ThemeData theme) {
    return Container(
      key: const ValueKey('planifier'),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.medical_services_rounded,
                          color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      const Text('Créer une demande',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sélectionnez le type puis complétez les informations.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  // First row: Type + Date limite (responsive)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;

                      final typeField = DropdownButtonFormField<String>(
                        value: _visitType,
                        decoration: _decoration(label: 'Type'),
                        items: const [
                          DropdownMenuItem(
                              value: 'EMBAUCHE', child: Text('Embauche')),
                          DropdownMenuItem(
                              value: 'REPRISE', child: Text('Reprise')),
                        ],
                        onChanged: (v) => setState(() {
                          _visitType = v ?? 'EMBAUCHE';
                          if (_visitType != 'REPRISE') {
                            _repriseCase = null;
                          }
                        }),
                      );

                      final dateField = InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: _decoration(
                            label: 'Date limite',
                            suffixIcon: Icon(
                              Icons.calendar_today_rounded,
                              color:
                                  theme.colorScheme.onSurface.withOpacity(0.7),
                            ),
                          ),
                          child: Text(
                            _visitDate == null
                                ? 'Non sélectionnée'
                                : _formatDate(_visitDate!),
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(child: typeField),
                            const SizedBox(width: 12),
                            Expanded(child: dateField),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          typeField,
                          const SizedBox(height: 12),
                          dateField,
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Salarié(s) selector styled like an input + optional info button
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth >= 600;
                      final Widget employeesContent =
                          _buildSelectedEmployeesDisplay(theme);

                      final selectorField = InkWell(
                        onTap: _loadingEmployees
                            ? null
                            : _openEmployeeSelectionDialog,
                        child: InputDecorator(
                          decoration: _decoration(label: 'Salarié'),
                          child: Row(
                            children: [
                              Expanded(
                                child: employeesContent,
                              ),
                              if (_loadingEmployees)
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2))
                              else
                                Icon(Icons.arrow_drop_down,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6)),
                            ],
                          ),
                        ),
                      );

                      final infoBtn = OutlinedButton(
                        onPressed: _selectedEmployees.isNotEmpty
                            ? () {
                                if (_selectedEmployees.length == 1) {
                                  _showEmployeeDetailsDialog(
                                      _selectedEmployees.first);
                                } else {
                                  _showEmployeesDetailsCarousel(
                                      _selectedEmployees);
                                }
                              }
                            : null,
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Afficher informations'),
                      );

                      if (isWide) {
                        return Row(
                          children: [
                            Expanded(child: selectorField),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 200,
                              child: infoBtn,
                            ),
                          ],
                        );
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          selectorField,
                          const SizedBox(height: 8),
                          infoBtn,
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 16),
                  // Reprise-specific extra fields (chips)
                  if (_visitType == 'REPRISE') ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Cas de reprise',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ChoiceChip(
                          label: const Text('Absence pour AT/MP'),
                          selected: _repriseCase == 'AT_MP',
                          onSelected: (sel) => setState(
                              () => _repriseCase = sel ? 'AT_MP' : null),
                        ),
                        ChoiceChip(
                          label: const Text(
                              'Absence pour accident/maladie hors AT/MP'),
                          selected: _repriseCase == 'HORS_AT_MP',
                          onSelected: (sel) => setState(
                              () => _repriseCase = sel ? 'HORS_AT_MP' : null),
                        ),
                        ChoiceChip(
                          label: const Text(
                              'Absence pour maternité/paternité/adoption'),
                          selected: _repriseCase == 'MAT_PAT_ADO',
                          onSelected: (sel) => setState(
                              () => _repriseCase = sel ? 'MAT_PAT_ADO' : null),
                        ),
                        ChoiceChip(
                          label: const Text('Absence pour aménagement'),
                          selected: _repriseCase == 'AMENAGEMENT',
                          onSelected: (sel) => setState(
                              () => _repriseCase = sel ? 'AMENAGEMENT' : null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Certificats médicaux upload section
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Certificats médicaux',
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(width: 8),
                          if (_selectedCertificates.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.primary.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                  '${_selectedCertificates.length} ajouté(s)',
                                  style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Ajoutez un certificat médical au document pour valider la reprise',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isWide = constraints.maxWidth >= 600;
                        final pickerField = InkWell(
                          onTap: _pickCertificates,
                          child: InputDecorator(
                            decoration: _decoration(
                              label: 'Sélectionner les fichiers',
                              suffixIcon: Icon(Icons.attach_file,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7)),
                            ),
                            child: Text(
                              _selectedCertificates.isEmpty
                                  ? 'Choisissez un ou plusieurs certificats (PDF)'
                                  : (_selectedCertificates.length == 1
                                      ? _selectedCertificates.first.name
                                      : '${_selectedCertificates.length} fichiers sélectionnés'),
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        );

                        final addBtn = GradientButton(
                          onPressed: _pickCertificates,
                          gradient: LinearGradient(colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.85),
                          ]),
                          radius: 8,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: const Text('Ajouter un certificat',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        );

                        if (isWide) {
                          final row = Row(
                            children: [
                              Expanded(child: pickerField),
                              const SizedBox(width: 12),
                              SizedBox(width: 220, child: addBtn),
                            ],
                          );
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              row,
                              const SizedBox(height: 6),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Certificats ajoutés : ${_selectedCertificates.length}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }
                        final col = Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            pickerField,
                            const SizedBox(height: 8),
                            addBtn,
                          ],
                        );
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            col,
                            const SizedBox(height: 6),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Certificats ajoutés : ${_selectedCertificates.length}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    if (_selectedCertificates.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (int i = 0;
                                i < _selectedCertificates.length;
                                i++)
                              Chip(
                                label: Text(
                                  '${_selectedCertificates[i].name} • ${_formatBytes(_selectedCertificates[i].size)}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                                deleteIcon: const Icon(Icons.close),
                                onDeleted: () => _removeCertificateAt(i),
                              ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),
                  ],

                  // Notes (optionnel)
                  TextFormField(
                    controller: _notesController,
                    minLines: 3,
                    maxLines: 5,
                    decoration: _decoration(
                        label: 'Détails supplémentaires (optionnel)',
                        hint: 'Remarques...'),
                  ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: Builder(
                      builder: (ctx) {
                        final enabled = !(_submitting ||
                            _selectedEmployees.isEmpty ||
                            _visitDate == null);
                        return GradientButton(
                          onPressed: enabled ? _submitPlanification : null,
                          gradient: LinearGradient(colors: [
                            theme.colorScheme.primary,
                            theme.colorScheme.primary.withOpacity(0.85),
                          ]),
                          radius: 8,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: _submitting
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
          ],
        ),
      ),
    );
  }

  Widget _buildConsulterSection(ThemeData theme) {
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

    final selectedCategory = _statusLabelToBackendEnum(_statusFilter);
    final selectedDept = _departmentFilter;

    // Build department items once (unique + sorted)
    final departments = _allEmployees
        .map((e) => (e.department ?? '').trim())
        .where((d) => d.isNotEmpty)
        .toSet()
        .toList();
    departments.sort();
    final departmentItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem<String>(value: 'Tous', child: Text('Tous')),
      ...departments
          .map((d) => DropdownMenuItem<String>(value: d, child: Text(d))),
    ];

    final list = _appointments.where((a) {
      // Search by name/email
      if (_search.trim().isNotEmpty) {
        final q = _search.trim().toLowerCase();
        final m = a.employeeName.toLowerCase().contains(q) ||
            a.employeeEmail.toLowerCase().contains(q);
        if (!m) return false;
      }

      // Status filter - backend should handle this
      // Removed local status mapping logic

      // Département filter (requires employees list)
      if (selectedDept != 'Tous') {
        final emp = _findEmployeeForAppointment(a);
        final dept = (emp?.department ?? '').trim();
        if (dept.isEmpty || dept != selectedDept) return false;
      }

      return true;
    }).toList();

    return Container(
      key: const ValueKey('consulter'),
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          hint: 'Rechercher...',
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
                          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                          DropdownMenuItem(
                              value: 'En attente', child: Text('En attente')),
                          DropdownMenuItem(
                              value: 'Proposé', child: Text('Proposé')),
                          DropdownMenuItem(
                              value: 'Confirmé', child: Text('Confirmé')),
                          DropdownMenuItem(
                              value: 'Annulé', child: Text('Annulé')),
                          DropdownMenuItem(
                              value: 'Terminé', child: Text('Terminé')),
                        ],
                        onChanged: (v) =>
                            setState(() => _statusFilter = v ?? 'Tous'),
                      ),
                    ),
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String>(
                        value: _typeFilter,
                        decoration: _decoration(label: 'Type'),
                        items: const [
                          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
                          DropdownMenuItem(
                              value: 'Embauche', child: Text('Embauche')),
                          DropdownMenuItem(
                              value: 'Reprise', child: Text('Reprise')),
                        ],
                        onChanged: (v) {
                          final val = v ?? 'Tous';
                          setState(() {
                            _typeFilter = val;
                            if (val == 'Tous') {
                              _selectedTypes
                                ..clear()
                                ..addAll({'EMBAUCHE', 'REPRISE'});
                            } else if (val == 'Embauche') {
                              _selectedTypes
                                ..clear()
                                ..add('EMBAUCHE');
                            } else {
                              _selectedTypes
                                ..clear()
                                ..add('REPRISE');
                            }
                          });
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
                  child: IconButton(
                    tooltip: 'Actualiser',
                    onPressed: _loadingList ? null : _fetchAppointments,
                    icon: _loadingList
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh),
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
          else if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: Text('Aucun rendez-vous trouvé.')),
            )
          else
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  final w = constraints.maxWidth;
                  int cols;
                  if (w < 600) {
                    cols = 1;
                  } else if (w < 900) {
                    cols = 2;
                  } else if (w < 1200) {
                    cols = 3;
                  } else {
                    cols = 4;
                  }
                  const spacing = 12.0;
                  final totalSpacing = spacing * (cols - 1);
                  final itemWidth = (w - totalSpacing) / cols;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (final a in list)
                        SizedBox(
                          width: itemWidth,
                          child: MedicalVisitCard(
                            appointment: a,
                            employee: _findEmployeeForAppointment(a),
                            onShowEmployeeInfo: () async {
                              var emp = _findEmployeeForAppointment(a);
                              if (emp == null) {
                                await _fetchEmployees();
                                emp = _findEmployeeForAppointment(a);
                              }
                              if (emp != null) {
                                _showEmployeeDetailsDialog(emp);
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Informations salarié indisponibles.')),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
