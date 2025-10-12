import 'package:flutter/material.dart';
import 'package:oshapp/shared/models/employee.dart';

class EmployeeSelectionWidget extends StatefulWidget {
  final List<Employee> allEmployees;
  final List<Employee> selectedEmployees;
  final ValueChanged<List<Employee>> onSelectionChanged;
  final Map<String, List<String>> rolesByEmployeeId;

  const EmployeeSelectionWidget({
    super.key,
    required this.allEmployees,
    required this.selectedEmployees,
    required this.onSelectionChanged,
    this.rolesByEmployeeId = const {},
  });

  @override
  EmployeeSelectionWidgetState createState() => EmployeeSelectionWidgetState();
}

class EmployeeSelectionWidgetState extends State<EmployeeSelectionWidget> {
  late List<Employee> _baseEmployees; // after static filters
  late List<Employee> _filteredEmployees;
  final TextEditingController _searchController = TextEditingController();
  late Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _baseEmployees = _applyStaticFilters(widget.allEmployees);
    _filteredEmployees = _baseEmployees;
    _selectedIds = widget.selectedEmployees.map((e) => e.id).toSet();
    _searchController.addListener(_filterEmployees);
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterEmployees);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EmployeeSelectionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.allEmployees != widget.allEmployees) {
      _baseEmployees = _applyStaticFilters(widget.allEmployees);
      _filterEmployees();
    }
    if (oldWidget.selectedEmployees != widget.selectedEmployees) {
      // Sync local selection with parent-provided selection
      _selectedIds = widget.selectedEmployees.map((e) => e.id).toSet();
    }
    if (oldWidget.rolesByEmployeeId != widget.rolesByEmployeeId) {
      // Roles now affect static filters (exclusion) and search/chips; recompute base list
      _baseEmployees = _applyStaticFilters(widget.allEmployees);
      _filterEmployees();
    }
  }

  // Normalize string: lower-case and strip common French accents for robust matching
  String _normalize(String? s) {
    if (s == null) return '';
    final lower = s.toLowerCase();
    const Map<String, String> map = {
      'à': 'a', 'â': 'a', 'ä': 'a',
      'ç': 'c',
      'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
      'î': 'i', 'ï': 'i',
      'ô': 'o', 'ö': 'o',
      'û': 'u', 'ü': 'u',
      'ÿ': 'y',
    };
    final sb = StringBuffer();
    for (final ch in lower.split('')) {
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  // Display-friendly role label. Prefer French "RH" for HR.
  String _roleDisplay(String role) {
    final r = role.trim().toUpperCase();
    if (r == 'HR') return 'RH';
    return r;
  }

  bool _isMedicalRole(Employee e) {
    final jt = _normalize(e.jobTitle);
    if (jt.isEmpty) return false;
    const keywords = <String>{
      'infirmier', 'infirmiere',
      'nurse',
      'medecin', 'medicin', 'medico',
      'doctor', 'docteur',
    };
    for (final k in keywords) {
      if (jt.contains(k)) return true;
    }
    return false;
  }

  // Apply static filters once: exclude soft-deleted (approx by missing email) and nurse/doctor roles
  List<Employee> _applyStaticFilters(List<Employee> list) {
    return list.where((e) {
      final hasEmail = (e.email ?? '').trim().isNotEmpty;
      if (!hasEmail) return false; // likely soft-deleted or invalid
      // Exclude medical profiles primarily by roles (if available), else fallback to jobTitle keywords
      final roles = widget.rolesByEmployeeId[e.id] ?? const <String>[];
      if (roles.isNotEmpty) {
        final hasMedicalRole = roles.any((r) {
          final rr = r.trim().toUpperCase();
          return rr == 'NURSE' || rr == 'DOCTOR';
        });
        if (hasMedicalRole) return false;
      } else {
        if (_isMedicalRole(e)) return false; // fallback exclusion by job title
      }
      return true;
    }).toList();
  }

  void _filterEmployees() {
    final queryRaw = _searchController.text.trim();
    final query = _normalize(queryRaw);
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = _baseEmployees;
        return;
      }
      _filteredEmployees = _baseEmployees.where((employee) {
        final roles = widget.rolesByEmployeeId[employee.id] ?? const <String>[];
        final haystack = [
          employee.firstName,
          employee.lastName,
          employee.department,
          employee.jobTitle,
          employee.cin,
          employee.cnssNumber,
          employee.email,
          // include roles for search
          roles.join(' '),
        ].whereType<String>().map(_normalize).join(' ');
        return haystack.contains(query);
      }).toList();
    });
  }

  void _onEmployeeSelected(bool? selected, Employee employee) {
    setState(() {
      if (selected == true) {
        _selectedIds.add(employee.id);
      } else {
        _selectedIds.remove(employee.id);
      }
    });
    // Notify parent with the new selection list
    final newSelection = widget.allEmployees
        .where((e) => _selectedIds.contains(e.id))
        .toList();
    widget.onSelectionChanged(newSelection);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              labelText: 'Rechercher un salarié',
              hintText: 'Rechercher par nom, email, département, poste…',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredEmployees.length,
            itemBuilder: (context, index) {
              final employee = _filteredEmployees[index];
              final isSelected = _selectedIds.contains(employee.id);
              final fullName = employee.fullName.isNotEmpty
                  ? employee.fullName
                  : 'Salarié #${employee.id}';

              final email = (employee.email ?? '').trim();
              final job = (employee.jobTitle ?? '').trim();
              final dept = (employee.department ?? '').trim();
              // Show role/department as chips below; avoid combined meta string to reduce truncation.
              final roles = widget.rolesByEmployeeId[employee.id] ?? const <String>[];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                leading: CircleAvatar(
                  radius: 16,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
                  child: Text(employee.initials),
                ),
                title: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    fullName,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
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
                            Icon(Icons.email, size: 16, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                            Icon(Icons.badge_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                            const SizedBox(width: 6),
                            Expanded(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Text(
                                  job,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (roles.isNotEmpty || dept.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final r in roles)
                              Chip(
                                label: Text(_roleDisplay(r)),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (dept.isNotEmpty)
                              Chip(
                                avatar: Icon(
                                  Icons.apartment_outlined,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.primary,
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
                trailing: Checkbox(
                  value: isSelected,
                  onChanged: (bool? selected) {
                    _onEmployeeSelected(selected, employee);
                  },
                ),
                onTap: () {
                  _onEmployeeSelected(!isSelected, employee);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
