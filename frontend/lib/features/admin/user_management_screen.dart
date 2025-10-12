import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui';
import 'package:oshapp/shared/models/user.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/services/auth_service.dart';
import 'package:oshapp/shared/errors/api_exception.dart';
import 'create_user_screen.dart';
import 'edit_user_dialog.dart';
import 'package:provider/provider.dart';
import 'package:oshapp/shared/widgets/theme_controls.dart';
import 'package:shimmer/shimmer.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_selector/file_selector.dart' as fs;

import 'package:excel/excel.dart' as xls;
import 'package:oshapp/shared/models/employee_creation_request_dto.dart';

// Simple model to describe a single field change in the review dialog
class _FieldChange {
  final String key; // normalized field key, e.g., 'roles', 'firstName'
  final String label; // e.g., 'Rôles', 'Prénom'
  final String? oldValue;
  final String? newValue;
  bool apply; // whether to apply the new value
  _FieldChange(this.key, this.label, this.oldValue, this.newValue)
      : apply = true;
}

// Update candidate collected during import when an existing email is found with differences
class _UpdateCandidate {
  final int rowIndex; // 0-based (add 1 for display)
  final String email;
  final int userId;
  final int? employeeId; // may be null if profile not yet created
  final List<String>? newRoles; // null if roles unchanged
  final EmployeeCreationRequestDTO? profileDto; // null if no profile changes
  final String? manager1Email; // optional manager emails provided in import
  final String? manager2Email;
  final List<_FieldChange> changes; // for UI

  const _UpdateCandidate({
    required this.rowIndex,
    required this.email,
    required this.userId,
    required this.employeeId,
    required this.newRoles,
    required this.profileDto,
    required this.manager1Email,
    required this.manager2Email,
    required this.changes,
  });
}

class _ApplyUpdatesResult {
  final List<String> updatedEmails;
  final List<String> errors;
  const _ApplyUpdatesResult(
      {required this.updatedEmails, required this.errors});
}

class UserManagementScreen extends StatefulWidget {
  final String? initialRoleFilter;
  final String? initialStatusFilter; // 'ACTIF' | 'INACTIF'
  final String? initialVerificationFilter; // 'VERIFIE' | 'NON_VERIFIE'
  const UserManagementScreen(
      {super.key,
      this.initialRoleFilter,
      this.initialStatusFilter,
      this.initialVerificationFilter});

  @override
  UserManagementScreenState createState() => UserManagementScreenState();
}

class UserManagementScreenState extends State<UserManagementScreen> {
  List<User> _users = [];
  bool _isLoading = true;
  bool _canCreateUser = false;
  bool _canManageUsers = false;
  String _query = '';
  String? _roleFilter; // normalized e.g. 'ADMIN', 'HR'
  String? _statusFilter; // 'ACTIF' | 'INACTIF'
  String? _verificationFilter; // 'VERIFIE' | 'NON_VERIFIE'
  String _sortKey = 'Nom'; // 'Nom' | 'Rôle' | 'Statut'
  bool _sortAsc = true;
  // Selection mode for bulk actions
  bool _selectMode = false;
  final Set<String> _selectedUserIds = <String>{};
  bool _isBulkDeleting = false;
  // RH has full admin permissions; no fallback mode.

  @override
  void initState() {
    super.initState();
    // Apply initial filters if provided from navigation
    _roleFilter = widget.initialRoleFilter?.trim().toUpperCase();
    _statusFilter = widget.initialStatusFilter?.trim().toUpperCase();
    _verificationFilter =
        widget.initialVerificationFilter?.trim().toUpperCase();
    _loadData();
  }

  // ---- Selection helpers and bulk delete ----
  void _enterSelectionMode() {
    if (!_canManageUsers) return;
    setState(() {
      _selectMode = true;
    });
  }

  void _startSelectionWith(String userId) {
    if (!_canManageUsers) return;
    setState(() {
      _selectMode = true;
      _selectedUserIds.add(userId);
    });
  }

  void _onRowCheckboxToggled(String userId, bool selected) {
    if (!_canManageUsers) return;
    setState(() {
      if (selected) {
        _selectedUserIds.add(userId);
        _selectMode = true;
      } else {
        _selectedUserIds.remove(userId);
        if (_selectedUserIds.isEmpty) {
          _selectMode = false;
        }
      }
    });
  }

  void _clearSelection() {
    if (!_canManageUsers) return;
    setState(() {
      _selectedUserIds.clear();
      _selectMode = false;
    });
  }

  void _selectAllFiltered() {
    if (!_canManageUsers) return;
    setState(() {
      _selectMode = true;
      _selectedUserIds
        ..clear()
        ..addAll(_filteredUsers.map((u) => u.id));
    });
  }

  void _confirmAndDeleteSelected() {
    if (_selectedUserIds.isEmpty || _isBulkDeleting) return;
    final count = _selectedUserIds.length;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
              'Supprimer $count utilisateur${count > 1 ? 's' : ''} ?'),
          content: const Text(
              'Cette action est irréversible. Confirmez la suppression des utilisateurs sélectionnés.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _bulkDeleteSelected();
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _bulkDeleteSelected() async {
    if (_selectedUserIds.isEmpty) return;
    setState(() {
      _isBulkDeleting = true;
    });
    final apiService = Provider.of<ApiService>(context, listen: false);
    int success = 0;
    int failed = 0;
    final List<String> failMessages = [];
    final ids = List<String>.from(_selectedUserIds);
    for (final idStr in ids) {
      try {
        await apiService.deleteUser(int.parse(idStr));
        success++;
      } on ApiException catch (e) {
        failed++;
        if (e.statusCode == 409) {
          final msg = (e.message.isNotEmpty)
              ? e.message
              : "Impossible de supprimer l'utilisateur: il est encore référencé par des rendez-vous. Veuillez d'abord réaffecter ou libérer ces rendez-vous, ou désactiver le compte.";
          failMessages.add(msg);
        } else {
          failMessages.add(e.message.isNotEmpty ? e.message : e.toString());
        }
      } catch (e) {
        failed++;
        failMessages.add(e.toString());
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Suppression terminée: $success succès, $failed échec(s).'),
        backgroundColor: failed == 0 ? Colors.green : Colors.orange,
        duration: const Duration(seconds: 4),
      ),
    );

    setState(() {
      _isBulkDeleting = false;
      _selectedUserIds.clear();
      _selectMode = false;
    });

    _refreshUsers();
  }

  // Presents a dialog summarizing detected updates and lets admin choose field-by-field which to apply.
  Future<bool> _showReviewUpdatesDialog(
      List<_UpdateCandidate> candidates) async {
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) {
            return StatefulBuilder(
              builder: (stateCtx, setState) {
                void toggleAll(bool value) {
                  for (final c in candidates) {
                    for (final ch in c.changes) {
                      ch.apply = value;
                    }
                  }
                  setState(() {});
                }

                return AlertDialog(
                  title: const Text('Mises à jour détectées'),
                  content: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              'Des différences ont été détectées pour ${candidates.length} utilisateur(s) existant(s).'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              OutlinedButton(
                                onPressed: () => toggleAll(true),
                                child: const Text('Tout sélectionner'),
                              ),
                              OutlinedButton(
                                onPressed: () => toggleAll(false),
                                child: const Text('Tout désélectionner'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...candidates.map((c) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${c.email} (ligne ${c.rowIndex + 1})',
                                        style: Theme.of(stateCtx)
                                            .textTheme
                                            .titleSmall),
                                    const SizedBox(height: 6),
                                    ...c.changes.map((ch) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 4),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Checkbox(
                                                value: ch.apply,
                                                onChanged: (v) => setState(() => ch.apply = v ?? true),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      ch.label,
                                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    LayoutBuilder(
                                                      builder: (ctx2, cons) {
                                                        final isNarrow = cons.maxWidth < 360;

                                                        Widget buildValue(String key, String? raw, {required bool isNew}) {
                                                          final theme = Theme.of(stateCtx);
                                                          final textStyle = theme.textTheme.bodyMedium;
                                                          final s = (raw ?? '').trim();
                                                          if (s.isEmpty || s == '-') {
                                                            return Text('— (vide)', style: textStyle?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)));
                                                          }
                                                          if (key == 'roles') {
                                                            List<String> splitRoles(String src) => src.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
                                                            final roles = splitRoles(s);
                                                            String labelFor(String r) {
                                                              final t = r.toUpperCase();
                                                              switch (t) {
                                                                case 'ROLE_ADMIN':
                                                                case 'ADMIN':
                                                                  return 'ADMIN';
                                                                case 'ROLE_RH':
                                                                case 'RH':
                                                                  return 'RH';
                                                                case 'ROLE_HSE':
                                                                case 'HSE':
                                                                  return 'HSE';
                                                                case 'ROLE_NURSE':
                                                                case 'NURSE':
                                                                  return 'Infirmier';
                                                                case 'ROLE_DOCTOR':
                                                                case 'DOCTOR':
                                                                  return 'Médecin';
                                                                case 'ROLE_EMPLOYEE':
                                                                case 'EMPLOYEE':
                                                                  return 'Employé';
                                                                default:
                                                                  return t.replaceAll('ROLE_', '');
                                                              }
                                                            }
                                                            // Compute diffs when possible
                                                            final oldSet = splitRoles((ch.oldValue ?? '')).map((e) => e.toUpperCase()).toSet();
                                                            final newSet = splitRoles((ch.newValue ?? '')).map((e) => e.toUpperCase()).toSet();
                                                            Color? bgAdded = Colors.green[100];
                                                            Color? fgAdded = Colors.green[900];
                                                            Color? bgRemoved = Colors.red[100];
                                                            Color? fgRemoved = Colors.red[900];
                                                            return Wrap(
                                                              spacing: 6,
                                                              runSpacing: 6,
                                                              children: roles.map((r) {
                                                                final keyR = r.toUpperCase();
                                                                final added = isNew && !oldSet.contains(keyR) && newSet.contains(keyR);
                                                                final removed = !isNew && oldSet.contains(keyR) && !newSet.contains(keyR);
                                                                final label = labelFor(r);
                                                                if (added) {
                                                                  return Chip(label: Text(label, style: TextStyle(color: fgAdded)), backgroundColor: bgAdded, avatar: const Icon(Icons.add, size: 16, color: Colors.green));
                                                                }
                                                                if (removed) {
                                                                  return Chip(label: Text(label, style: TextStyle(color: fgRemoved, decoration: TextDecoration.lineThrough)), backgroundColor: bgRemoved, avatar: const Icon(Icons.remove, size: 16, color: Colors.red));
                                                                }
                                                                return Chip(label: Text(label));
                                                              }).toList(),
                                                            );
                                                          }
                                                          if (key == 'dateOfBirth' || key == 'hireDate') {
                                                            final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(s);
                                                            if (m != null) {
                                                              final dd = '${m.group(3)}/${m.group(2)}/${m.group(1)}';
                                                              return Text(dd, style: textStyle);
                                                            }
                                                            return Text(s, style: textStyle);
                                                          }
                                                          return Text(s, style: textStyle);
                                                        }

                                                        Widget oldCard = Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(stateCtx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              const Text('Ancien', style: TextStyle(fontWeight: FontWeight.w600)),
                                                              const SizedBox(height: 4),
                                                              buildValue(ch.key, ch.oldValue, isNew: false)
                                                            ],
                                                          ),
                                                        );

                                                        Widget newCard = Container(
                                                          padding: const EdgeInsets.all(8),
                                                          decoration: BoxDecoration(
                                                            color: Theme.of(stateCtx).colorScheme.primaryContainer.withValues(alpha: 0.35),
                                                            borderRadius: BorderRadius.circular(8),
                                                          ),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              const Text('Nouveau', style: TextStyle(fontWeight: FontWeight.w600)),
                                                              const SizedBox(height: 4),
                                                              buildValue(ch.key, ch.newValue, isNew: true)
                                                            ],
                                                          ),
                                                        );

                                                        if (isNarrow) {
                                                          return Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              oldCard,
                                                              const SizedBox(height: 6),
                                                              newCard,
                                                            ],
                                                          );
                                                        } else {
                                                          return Row(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              Expanded(child: oldCard),
                                                              const SizedBox(width: 8),
                                                              Expanded(child: newCard),
                                                            ],
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                                  ],
                                ),
                              )),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 6),
                          const Text(
                              'Cochez les champs à mettre à jour.'),
                        ],
                      ),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(stateCtx).pop(false),
                      child: const Text('Garder les anciennes valeurs'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(stateCtx).pop(true),
                      icon: const Icon(Icons.check_circle_outline),
                      label:
                          const Text('Appliquer les mises à jour sélectionnées'),
                    ),
                  ],
                );
              },
            );
          },
        ) ??
        false;
  }

  Future<_ApplyUpdatesResult> _applyUpdates(
    List<_UpdateCandidate> candidates,
    ApiService api,
    Map<String, int> emailToEmpId,
  ) async {
    final updated = <String>[];
    final errs = <String>[];
    for (final c in candidates) {
      bool anyApplied = false;
      try {
        final selectedKeys =
            c.changes.where((ch) => ch.apply).map((ch) => ch.key).toSet();

        // 1) Roles update (only if selected)
        if (c.newRoles != null && selectedKeys.contains('roles')) {
          await api.updateUser(c.userId, roles: c.newRoles);
          anyApplied = true;
        }

        // 2) Profile update (ensure userId on dto and only keep selected fields)
        int? targetEmpId = c.employeeId;
        if (c.profileDto != null) {
          const profileKeys = {
            'firstName',
            'lastName',
            'position',
            'department',
            'hireDate',
            'dateOfBirth',
            'cin',
            'cnss',
            'phone',
            'placeOfBirth',
            'address',
            'nationality',
            'city',
            'zipCode',
            'country',
            'gender',
          };
          final anyProfileSelected =
              selectedKeys.any((k) => profileKeys.contains(k));
          if (anyProfileSelected) {
            final dto = c.profileDto!;
            final filteredDto = EmployeeCreationRequestDTO(
              userId: c.userId,
              firstName:
                  selectedKeys.contains('firstName') ? dto.firstName : null,
              lastName:
                  selectedKeys.contains('lastName') ? dto.lastName : null,
              email: null, // email change via import non supporté
              position:
                  selectedKeys.contains('position') ? (dto.position ?? dto.jobTitle) : null,
              department:
                  selectedKeys.contains('department') ? dto.department : null,
              hireDate:
                  selectedKeys.contains('hireDate') ? dto.hireDate : null,
              dateOfBirth: selectedKeys.contains('dateOfBirth')
                  ? dto.dateOfBirth
                  : null,
              cin: selectedKeys.contains('cin') ? dto.cin : null,
              cnss: selectedKeys.contains('cnss') ? dto.cnss : null,
              phoneNumber:
                  selectedKeys.contains('phone') ? dto.phoneNumber : null,
              placeOfBirth: selectedKeys.contains('placeOfBirth')
                  ? dto.placeOfBirth
                  : null,
              address:
                  selectedKeys.contains('address') ? dto.address : null,
              nationality: selectedKeys.contains('nationality')
                  ? dto.nationality
                  : null,
              city: selectedKeys.contains('city') ? dto.city : null,
              zipCode:
                  selectedKeys.contains('zipCode') ? dto.zipCode : null,
              country:
                  selectedKeys.contains('country') ? dto.country : null,
              gender:
                  selectedKeys.contains('gender') ? dto.gender : null,
            );
            final emp = await api.updateEmployeeProfile(filteredDto);
            final empId = int.tryParse(emp.id);
            if (empId != null) targetEmpId = empId;
            anyApplied = true;
          }
        }

        // 3) Manager assignment (apply only if selected)
        final applyM1 = selectedKeys.contains('manager1Email');
        final applyM2 = selectedKeys.contains('manager2Email');
        if (applyM1 || applyM2) {
          if (targetEmpId == null) {
            errs.add(
                'Ligne ${c.rowIndex + 1} (${c.email}): profil employé introuvable pour assigner les managers.');
          } else {
            int? mm1;
            int? mm2;
            if (applyM1) {
              if (c.manager1Email != null && c.manager1Email!.isNotEmpty) {
                mm1 = emailToEmpId[c.manager1Email!.toLowerCase()];
                if (mm1 == null) {
                  errs.add(
                      'Ligne ${c.rowIndex + 1} (${c.email}): N+1 "${c.manager1Email}" introuvable.');
                }
              }
            }
            if (applyM2) {
              if (c.manager2Email != null && c.manager2Email!.isNotEmpty) {
                mm2 = emailToEmpId[c.manager2Email!.toLowerCase()];
                if (mm2 == null) {
                  errs.add(
                      'Ligne ${c.rowIndex + 1} (${c.email}): N+2 "${c.manager2Email}" introuvable.');
                }
              }
            }
            // Avoid same selection and self-assignment
            if (mm1 != null && mm2 != null && mm1 == mm2) {
              errs.add(
                  'Ligne ${c.rowIndex + 1} (${c.email}): N+1 et N+2 ne peuvent pas être le même employé (N+2 ignoré).');
              mm2 = null;
            }
            if (mm1 == targetEmpId) {
              errs.add(
                  'Ligne ${c.rowIndex + 1} (${c.email}): N+1 ne peut pas être l\'employé lui-même (ignoré).');
              mm1 = null;
            }
            if (mm2 == targetEmpId) {
              errs.add(
                  'Ligne ${c.rowIndex + 1} (${c.email}): N+2 ne peut pas être l\'employé lui-même (ignoré).');
              mm2 = null;
            }
            if (mm1 != null || mm2 != null) {
              await api.updateEmployeeManagers(targetEmpId,
                  manager1Id: mm1, manager2Id: mm2);
              anyApplied = true;
            }
          }
        }

        if (anyApplied) updated.add(c.email);
      } catch (e) {
        errs.add('Ligne ${c.rowIndex + 1} (${c.email}): échec mise à jour: $e');
      }
    }
    return _ApplyUpdatesResult(updatedEmails: updated, errors: errs);
  }

  // Helper to compare nullable strings with trimming and case-insensitive
  bool _diffStr(String? oldV, String? newV) {
    if (newV == null) return false; // if import didn't provide it, no change
    final a = (oldV ?? '').trim();
    final b = newV.trim();
    return a.toLowerCase() != b.toLowerCase();
  }

  // Reads the picked file bytes using in-memory bytes if available or falls back
  // to the provided readStream. This avoids relying on a platform path which can
  // be unavailable on Android (e.g., Google Drive or scoped storage), preventing
  // "unknown_path" / "Failed to retrieve path" errors.
  Future<Uint8List?> _readPlatformFileBytes(PlatformFile file) async {
    try {
      final direct = file.bytes;
      if (direct != null) return direct;
      final rs = file.readStream;
      if (rs != null) {
        final buffer = BytesBuilder();
        await for (final chunk in rs) {
          buffer.add(chunk);
        }
        return buffer.takeBytes();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Fallback picker using file_selector which works reliably with SAF/Drive URIs
  // across Android/iOS/Desktop without requiring a filesystem path.
  Future<Uint8List?> _pickFileBytesWithFileSelector({
    required List<String> extensions,
    List<String>? mimeTypes,
  }) async {
    try {
      final groups = <fs.XTypeGroup>[];
      if (extensions.isNotEmpty) {
        groups.add(fs.XTypeGroup(label: 'by-ext', extensions: extensions));
      }
      if (mimeTypes != null && mimeTypes.isNotEmpty) {
        groups.add(fs.XTypeGroup(label: 'by-mime', mimeTypes: mimeTypes));
      }
      if (groups.isEmpty) {
        groups.add(fs.XTypeGroup(label: 'all', mimeTypes: ['*/*']));
      }
      final xfile = await fs.openFile(acceptedTypeGroups: groups);
      if (xfile == null) return null; // cancelled
      // Try reading via stream first (often more reliable with Drive/SAF URIs)
      try {
        final stream = xfile.openRead();
        final buffer = BytesBuilder();
        await for (final chunk in stream) {
          buffer.add(chunk);
        }
        return buffer.takeBytes();
      } catch (e1, st1) {
        debugPrint('file_selector stream read failed: $e1\n$st1');
        try {
          return await xfile.readAsBytes();
        } catch (e2, st2) {
          debugPrint('file_selector readAsBytes failed: $e2\n$st2');
          return null;
        }
      }
    } catch (e, st) {
      debugPrint('file_selector open/read failed: $e\n$st');
      return null;
    }
  }

  Future<void> _downloadExcelTemplate() async {
    try {
      final book = xls.Excel.createExcel();
      final sheet = book['Import'];

      // Headers matching the expected columns (aliases supported on import)
      final headers = [
        'email',
        'password',
        'roles',
        'firstName',
        'lastName',
        'position',
        'department',
        'dateOfBirth',
        'hireDate',
        'cin',
        'cnss',
        'phone',
        'placeOfBirth',
        'address',
        'nationality',
        'city',
        'zipCode',
        'country',
        'gender',
        'manager1Email',
        'manager2Email',
      ];

      sheet.appendRow(headers);
      sheet.appendRow([
        'jean.dupont@acme.com',
        'Secret123',
        'EMPLOYEE',
        'Jean',
        'Dupont',
        'Technicien HSE',
        'HSE',
        '1990-05-20',
        '2020-01-15',
        'AB123456',
        '123456789',
        '+212600000000',
        'Casablanca',
        '123 Rue Exemple',
        'Marocaine',
        'Casablanca',
        '20000',
        'Maroc',
        'Homme',
        '',
        '',
      ]);

      final bytes = book.save();
      if (bytes == null) {
        throw 'Génération du fichier Excel échouée';
      }
      final data = Uint8List.fromList(bytes);
      await FileSaver.instance.saveFile(
        name: 'user_import_template',
        bytes: data,
        fileExtension: 'xlsx',
        mimeType: MimeType.microsoftExcel,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Modèle Excel téléchargé.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec du téléchargement du modèle: $e')),
        );
      }
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      // Fetch users; RH now has full admin permissions, no fallback mode
      final users = await apiService.getAllUsers();
      // Use current user's normalized roles for permissions
      final roles = authService.roles; // e.g., ['ADMIN', 'HR']

      if (mounted) {
        setState(() {
          _users = users;
          _canCreateUser = roles.contains('ADMIN') || roles.contains('HR');
          _canManageUsers = roles.contains('ADMIN') || roles.contains('HR');
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load data: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _refreshUsers() {
    _loadData();
  }

  Future<void> _importUsersFromCsv() async {
    if (!_canCreateUser) return;
    bool progressShown = false;
    try {
      Uint8List? data;
      // Prefer file_selector on Android to avoid SAF path issues
      if (defaultTargetPlatform == TargetPlatform.android) {
        data = await _pickFileBytesWithFileSelector(
          extensions: ['csv'],
          mimeTypes: ['text/csv', 'application/csv'],
        );
        if (data == null) {
          // Fallback to file_picker if channel isn't ready or user canceled
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['csv'],
              withData: true,
              withReadStream: true,
            );
            if (result != null && result.files.isNotEmpty) {
              final file = result.files.first;
              data = await _readPlatformFileBytes(file);
            }
          } on PlatformException catch (e) {
            if (e.code == 'unknown_path') {
              // Try a more permissive FilePicker (any) to avoid path resolution issues
              try {
                final alt = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                  allowMultiple: false,
                  withData: true,
                  withReadStream: true,
                );
                if (alt != null && alt.files.isNotEmpty) {
                  data = await _readPlatformFileBytes(alt.files.first);
                }
              } catch (_) {}
              if (data == null) {
                // Try file_selector again as a last resort in this branch
                data = await _pickFileBytesWithFileSelector(
                  extensions: ['csv'],
                  mimeTypes: ['text/csv', 'application/csv'],
                );
              }
            } else {
              rethrow;
            }
          }
        }
      } else {
        try {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['csv'],
            withData: true,
            withReadStream: true,
          );
          if (result == null || result.files.isEmpty) return; // cancelled
          final file = result.files.first;
          data = await _readPlatformFileBytes(file);
        } on PlatformException catch (e) {
          // Fallback to more permissive FilePicker then file_selector for pathless URIs
          if (e.code == 'unknown_path') {
            try {
              final alt = await FilePicker.platform.pickFiles(
                type: FileType.any,
                allowMultiple: false,
                withData: true,
                withReadStream: true,
              );
              if (alt != null && alt.files.isNotEmpty) {
                data = await _readPlatformFileBytes(alt.files.first);
              }
            } catch (_) {}
            if (data == null) {
              data = await _pickFileBytesWithFileSelector(
                extensions: ['csv'],
                mimeTypes: ['text/csv', 'application/csv'],
              );
            }
          } else {
            rethrow;
          }
        }
      }
      if (data == null) {
        // Try a last-chance fallback using file_selector
        data = await _pickFileBytesWithFileSelector(
          extensions: ['csv'],
          mimeTypes: ['text/csv', 'application/csv'],
        );
        if (data == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Impossible de lire le fichier sélectionné.')),
            );
          }
          return;
        }
      }

      var content = utf8.decode(data);
      // Remove potential UTF-8 BOM
      content = content.replaceFirst(RegExp(r'^\uFEFF'), '');

      final rows = const CsvToListConverter().convert(content);
      if (rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le fichier CSV est vide.')),
          );
        }
        return;
      }

      final header =
          rows.first.map((e) => e.toString().trim().toLowerCase()).toList();
      final emailIdx = header.indexOf('email');
      final passwordIdx = header.indexOf('password');
      int rolesIdx = header.indexOf('roles');
      if (rolesIdx < 0) rolesIdx = header.indexOf('role');
      if (emailIdx < 0 || passwordIdx < 0 || rolesIdx < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    "En-têtes requis manquants. Attendu: 'email', 'password', 'roles'.")),
          );
        }
        return;
      }

      // Show progress dialog
      if (mounted) {
        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Import en cours...'),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Veuillez patienter pendant l\'import des utilisateurs.')),
              ],
            ),
          ),
        );
        progressShown = true;
      }

      final api = Provider.of<ApiService>(context, listen: false);
      final successEmails = <String>[];
      final errors = <String>[];
      final List<_UpdateCandidate> updateCandidates = [];
      final List<String> appliedUpdates = [];
      final List<String> updateErrors = [];
      final Map<String, User> existingByEmail = {};
      final Map<int, String> empIdToEmail = {};

      // Preload existing employees mapped by email -> employeeId for manager email resolution
      final Map<String, int> emailToEmpId = {};
      final existingEmails = <String>{};
      try {
        final allUsers = await api.getAllUsers();
        for (final u in allUsers) {
          // Skip inactive/disabled (soft-deleted) accounts entirely
          if (u.enabled != true || u.isActive != true) continue;
          existingEmails.add(u.email.toLowerCase());
          existingByEmail[u.email.toLowerCase()] = u;
          final emp = u.employee;
          if (emp != null) {
            final id = int.tryParse(emp.id);
            if (id != null) {
              emailToEmpId[u.email.toLowerCase()] = id;
              empIdToEmail[id] = u.email;
            }
          }
        }
      } catch (_) {
        // If preload fails, we will still proceed. (CSV import doesn't assign managers.)
      }

      // Track duplicates within the current import file
      final Set<String> seenInFile = {};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        String getCell(int idx) =>
            (idx < row.length ? row[idx] : '').toString().trim();
        final email = getCell(emailIdx);
        final password = getCell(passwordIdx);
        final rolesCell = getCell(rolesIdx);

        // skip empty lines
        if (email.isEmpty && password.isEmpty && rolesCell.isEmpty) {
          continue;
        }

        if (email.isEmpty || !email.contains('@')) {
          errors.add('Ligne ${i + 1}: email invalide "$email"');
          continue;
        }

        // Detect duplicate emails within the same import file
        final emailLower = email.toLowerCase();
        if (seenInFile.contains(emailLower)) {
          errors.add(
              'Ligne ${i + 1}: email dupliqué "$email" dans le fichier (ignoré).');
          continue;
        }
        seenInFile.add(emailLower);

        final bool isExisting = existingEmails.contains(emailLower);

        // Parse roles allowing ',', ';', or '|' (for existing users, roles may be empty -> no change)
        final sep = rolesCell.contains(';')
            ? ';'
            : (rolesCell.contains('|') ? '|' : ',');
        final rawRoles = rolesCell
            .split(sep)
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        final roles = <String>[];

        // Reject explicit MANAGER role token (managers are not a distinct role)
        bool hasInvalidManagerRole = false;
        for (final r in rawRoles) {
          final t = r.trim().toUpperCase();
          if (t == 'MANAGER') {
            hasInvalidManagerRole = true;
            break;
          }
        }
        if (hasInvalidManagerRole) {
          errors.add(
              'Ligne ${i + 1}: rôle invalide "MANAGER". Utilisez EMPLOYEE/RH/HSE/NURSE/DOCTOR/ADMIN.');
          continue;
        }

        String mapRole(String r) {
          final t = r.trim().toUpperCase();
          if (t.startsWith('ROLE_')) return t;
          switch (t) {
            case 'ADMIN':
              return 'ROLE_ADMIN';
            case 'RH':
            case 'HR':
              return 'ROLE_RH';
            case 'EMPLOYEE':
            case 'EMPLOYE':
            case 'EMPLOYÉ':
            case 'SALARIE':
            case 'SALARIÉ':
              return 'ROLE_EMPLOYEE';
            case 'NURSE':
            case 'INFIRMIER':
            case 'INFIRMIÈRE':
              return 'ROLE_NURSE';
            case 'DOCTOR':
            case 'MEDECIN':
            case 'MÉDECIN':
              return 'ROLE_DOCTOR';
            case 'HSE':
              return 'ROLE_HSE';
            default:
              return 'ROLE_' + t.replaceAll(' ', '_');
          }
        }

        for (final r in rawRoles) {
          final nr = mapRole(r);
          if (!roles.contains(nr)) roles.add(nr);
        }

        // Branch: existing user -> collect update candidate if roles differ; new user -> validate roles and create
        if (isExisting) {
          final existing = existingByEmail[emailLower];
          if (existing == null) {
            errors.add(
                'Ligne ${i + 1}: email "$email" existe déjà (cache incohérent).');
            continue;
          }
          final changes = <_FieldChange>[];
          List<String>? newRolesForUpdate;
          if (roles.isNotEmpty) {
            // Validate allowed combos only if roles were provided
            const allowedSingle = {
              'ROLE_ADMIN',
              'ROLE_RH',
              'ROLE_EMPLOYEE',
              'ROLE_NURSE',
              'ROLE_DOCTOR',
              'ROLE_HSE',
            };
            if (roles.length > 2) {
              errors.add(
                  'Ligne ${i + 1}: au plus deux rôles autorisés. Utilisez HSE + [ADMIN|RH|NURSE|DOCTOR|EMPLOYEE] ou un seul rôle.');
              continue;
            }
            if (roles.any((r) => !allowedSingle.contains(r))) {
              errors.add(
                  'Ligne ${i + 1}: rôle non supporté. Autorisés: ADMIN, RH, HSE, NURSE, DOCTOR, EMPLOYEE.');
              continue;
            }
            if (roles.length == 2) {
              if (!roles.contains('ROLE_HSE')) {
                errors.add(
                    'Ligne ${i + 1}: pour deux rôles, HSE doit être inclus (ex: RH+HSE).');
                continue;
              }
              final other = roles.firstWhere((r) => r != 'ROLE_HSE',
                  orElse: () => 'ROLE_HSE');
              if (other == 'ROLE_HSE') {
                errors.add('Ligne ${i + 1}: combinaison de rôles invalide.');
                continue;
              }
            }

            final oldSet = existing.roles
                .map((e) => e.trim().toUpperCase())
                .toSet()
                .toList()
              ..sort();
            final newSet = roles
                .map((e) => e.trim().toUpperCase())
                .toSet()
                .toList()
              ..sort();
            final oldStr = oldSet.join(', ');
            final newStr = newSet.join(', ');
            if (oldStr != newStr) {
              changes.add(_FieldChange('roles', 'Rôles', oldStr, newStr));
              newRolesForUpdate = roles;
            }
          }

          // No profile/manager fields in CSV. If no change detected, mark as ignored
          if (changes.isEmpty) {
            errors.add(
                'Ligne ${i + 1}: email "$email" existe déjà dans le système (aucun changement détecté, ignoré).');
            continue;
          }

          final userId = int.tryParse(existing.id) ?? -1;
          final empId = int.tryParse(existing.employee?.id ?? '');
          updateCandidates.add(_UpdateCandidate(
            rowIndex: i,
            email: email,
            userId: userId,
            employeeId: empId,
            newRoles: newRolesForUpdate,
            profileDto: null,
            manager1Email: null,
            manager2Email: null,
            changes: changes,
          ));
          continue;
        } else {
          // New user: password length only enforced here
          if (password.length < 6) {
            errors.add(
                'Ligne ${i + 1}: mot de passe trop court (min 6 caractères).');
            continue;
          }
          // New user: roles must be provided and valid
          if (roles.isEmpty) {
            errors.add('Ligne ${i + 1}: aucun rôle fourni.');
            continue;
          }

          // Enforce allowed role combinations
          const allowedSingle = {
            'ROLE_ADMIN',
            'ROLE_RH',
            'ROLE_EMPLOYEE',
            'ROLE_NURSE',
            'ROLE_DOCTOR',
            'ROLE_HSE',
          };
          if (roles.length > 2) {
            errors.add(
                'Ligne ${i + 1}: au plus deux rôles autorisés. Utilisez HSE + [ADMIN|RH|NURSE|DOCTOR|EMPLOYEE] ou un seul rôle.');
            continue;
          }
          if (roles.any((r) => !allowedSingle.contains(r))) {
            errors.add(
                'Ligne ${i + 1}: rôle non supporté. Autorisés: ADMIN, RH, HSE, NURSE, DOCTOR, EMPLOYEE.');
            continue;
          }
          if (roles.length == 2) {
            if (!roles.contains('ROLE_HSE')) {
              errors.add(
                  'Ligne ${i + 1}: pour deux rôles, HSE doit être inclus (ex: RH+HSE).');
              continue;
            }
            final other = roles.firstWhere((r) => r != 'ROLE_HSE',
                orElse: () => 'ROLE_HSE');
            if (other == 'ROLE_HSE') {
              errors.add('Ligne ${i + 1}: combinaison de rôles invalide.');
              continue;
            }
          }

          try {
            await api.createUser(email, password, roles);
            successEmails.add(email);
          } catch (e) {
            errors.add('Ligne ${i + 1} ($email): $e');
          }
        }
      }

      // Close progress dialog
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }

      if (!mounted) return;
      // If updates were detected, ask for confirmation and apply
      if (updateCandidates.isNotEmpty) {
        final apply = await _showReviewUpdatesDialog(updateCandidates);
        if (apply) {
          final res = await _applyUpdates(updateCandidates, api, emailToEmpId);
          appliedUpdates.addAll(res.updatedEmails);
          updateErrors.addAll(res.errors);
        } else {
          for (final c in updateCandidates) {
            errors.add(
                'Ligne ${c.rowIndex + 1} (${c.email}): mises à jour détectées mais non appliquées.');
          }
        }
      }

      await _showImportSummaryDialog(
        total: rows.length - 1,
        successEmails: successEmails,
        errors: errors,
        appliedUpdates: appliedUpdates,
        updateErrors: updateErrors,
      );

      if (successEmails.isNotEmpty || appliedUpdates.isNotEmpty) {
        _refreshUsers();
      }
    } catch (e) {
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'import: $e')),
        );
      }
    }
  }

  Future<void> _importUsersFromExcel() async {
    if (!_canCreateUser) return;
    bool progressShown = false;
    try {
      Uint8List? data;
      // Prefer file_selector on Android to avoid SAF path issues
      if (defaultTargetPlatform == TargetPlatform.android) {
        data = await _pickFileBytesWithFileSelector(
          extensions: ['xlsx'],
          mimeTypes: [
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          ],
        );
        if (data == null) {
          // Fallback to file_picker if channel isn't ready or user canceled
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['xlsx'],
              withData: true,
              withReadStream: true,
            );
            if (result != null && result.files.isNotEmpty) {
              final file = result.files.first;
              data = await _readPlatformFileBytes(file);
            }
          } on PlatformException catch (e) {
            if (e.code == 'unknown_path') {
              // Try a more permissive FilePicker (any) to avoid path resolution issues
              try {
                final alt = await FilePicker.platform.pickFiles(
                  type: FileType.any,
                  allowMultiple: false,
                  withData: true,
                  withReadStream: true,
                );
                if (alt != null && alt.files.isNotEmpty) {
                  data = await _readPlatformFileBytes(alt.files.first);
                }
              } catch (_) {}
              if (data == null) {
                data = await _pickFileBytesWithFileSelector(
                  extensions: ['xlsx'],
                  mimeTypes: [
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                  ],
                );
              }
            } else {
              rethrow;
            }
          }
        }
      } else {
        try {
          final result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['xlsx'],
            withData: true,
            withReadStream: true,
          );
          if (result == null || result.files.isEmpty) return; // cancelled
          final file = result.files.first;
          data = await _readPlatformFileBytes(file);
        } on PlatformException catch (e) {
          if (e.code == 'unknown_path') {
            try {
              final alt = await FilePicker.platform.pickFiles(
                type: FileType.any,
                allowMultiple: false,
                withData: true,
                withReadStream: true,
              );
              if (alt != null && alt.files.isNotEmpty) {
                data = await _readPlatformFileBytes(alt.files.first);
              }
            } catch (_) {}
            if (data == null) {
              data = await _pickFileBytesWithFileSelector(
                extensions: ['xlsx'],
                mimeTypes: [
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
                ],
              );
            }
          } else {
            rethrow;
          }
        }
      }
      if (data == null) {
        // Try a last-chance fallback using file_selector
        data = await _pickFileBytesWithFileSelector(
          extensions: ['xlsx'],
          mimeTypes: [
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
          ],
        );
        if (data == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Impossible de lire le fichier sélectionné.')),
            );
          }
          return;
        }
      }

      final excel = xls.Excel.decodeBytes(data);
      xls.Sheet? sheet;
      // Prefer the 'Import' sheet by name if available, else take the first sheet
      if (excel.tables.containsKey('Import')) {
        sheet = excel['Import'];
      } else if (excel.tables.isNotEmpty) {
        sheet = excel.tables.values.first;
      }

      if (sheet == null || sheet.rows.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Le fichier Excel est vide ou illisible.')),
          );
        }
        return;
      }

      // Build header indexes
      final header = sheet.rows.first
          .map((cell) => ((cell?.value) ?? '').toString().trim().toLowerCase())
          .toList();
      int indexOfAny(List<String> hdr, List<String> options) {
        for (final o in options) {
          final i = hdr.indexOf(o);
          if (i >= 0) return i;
        }
        return -1;
      }

      final emailIdx = header.indexOf('email');
      final passwordIdx = header.indexOf('password');
      int rolesIdx = header.indexOf('roles');
      if (rolesIdx < 0) rolesIdx = header.indexOf('role');

      // Optional extended fields
      final firstNameIdx = indexOfAny(header,
          ['firstname', 'first_name', 'first name', 'prénom', 'prenom']);
      final lastNameIdx =
          indexOfAny(header, ['lastname', 'last_name', 'last name', 'nom']);
      final positionIdx = indexOfAny(header,
          ['position', 'jobtitle', 'job_title', 'job title', 'poste', 'titre']);
      final departmentIdx =
          indexOfAny(header, ['department', 'departement', 'département']);
      final dateOfBirthIdx = indexOfAny(header, [
        'dateofbirth',
        'birthdate',
        'birth_date',
        'birth date',
        'date_naissance',
        'date de naissance'
      ]);
      final hireDateIdx = indexOfAny(header, [
        'hiredate',
        'hire_date',
        'hire date',
        'dateembauche',
        "date d'embauche",
        'date embauche'
      ]);
      // Map 'matricule' to CIN for now unless a dedicated backend field exists
      final cinIdx = indexOfAny(header, ['cin', 'matricule']);
      final cnssIdx = indexOfAny(header, ['cnss', 'cnssnumber', 'cnss number']);
      final phoneIdx = indexOfAny(header, [
        'phone',
        'phone_number',
        'phone number',
        'telephone',
        'téléphone',
        'tel'
      ]);
      final placeOfBirthIdx = indexOfAny(header, [
        'placeofbirth',
        'birthplace',
        'place of birth',
        'lieu_naissance',
        'lieu de naissance'
      ]);
      final addressIdx = indexOfAny(header, ['address', 'adresse']);
      final nationalityIdx =
          indexOfAny(header, ['nationality', 'nationalite', 'nationalité']);
      final cityIdx = indexOfAny(header, ['city', 'ville']);
      final zipCodeIdx = indexOfAny(header, [
        'zipcode',
        'zip',
        'zip_code',
        'zip code',
        'codepostal',
        'code postal'
      ]);
      final countryIdx = indexOfAny(header, ['country', 'pays']);
      final genderIdx = indexOfAny(header, ['gender', 'sexe', 'genre']);
      final manager1Idx =
          indexOfAny(header, ['manager1id', 'manager1', 'n1id', 'n1', 'n+1']);
      final manager2Idx =
          indexOfAny(header, ['manager2id', 'manager2', 'n2id', 'n2', 'n+2']);
      // Manager columns (email-only). Prefer explicit email columns. Generic names
      // like 'manager1'/'manager2' are accepted but values MUST be emails (numeric IDs are rejected).
      final manager1EmailIdx = indexOfAny(header, [
        'manager1email',
        'manager1_email',
        'manager1 e-mail',
        'manager1 mail',
        'manager email',
        'manager e-mail',
        'manager mail',
        'n1email',
        'n1 email',
        'n+1 email'
      ]);
      final manager2EmailIdx = indexOfAny(header, [
        'manager2email',
        'manager2_email',
        'manager2 e-mail',
        'manager2 mail',
        'n2email',
        'n2 email',
        'n+2 email'
      ]);
      if (emailIdx < 0 || passwordIdx < 0 || rolesIdx < 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    "En-têtes requis manquants. Attendu: 'email', 'password', 'roles'.")),
          );
        }
        return;
      }

      // Show progress dialog
      if (mounted) {
        // ignore: use_build_context_synchronously
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Import en cours...'),
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                CircularProgressIndicator(),
                SizedBox(width: 12),
                Expanded(
                    child: Text(
                        'Veuillez patienter pendant l\'import des utilisateurs.')),
              ],
            ),
          ),
        );
        progressShown = true;
      }

      final api = Provider.of<ApiService>(context, listen: false);
      final successEmails = <String>[];
      final errors = <String>[];
      final List<_UpdateCandidate> updateCandidates = [];
      final List<String> appliedUpdates = [];
      final List<String> updateErrors = [];
      final Map<String, User> existingByEmail = {};
      final Map<int, String> empIdToEmail = {};

      // Preload existing employees mapped by email -> employeeId for manager email resolution
      final Map<String, int> emailToEmpId = {};
      final existingEmails = <String>{};
      try {
        final allUsers = await api.getAllUsers();
        for (final u in allUsers) {
          // Skip inactive/disabled (soft-deleted) accounts entirely
          if (u.enabled != true || u.isActive != true) continue;
          existingEmails.add(u.email.toLowerCase());
          existingByEmail[u.email.toLowerCase()] = u;
          final emp = u.employee;
          if (emp != null) {
            final id = int.tryParse(emp.id);
            if (id != null) {
              emailToEmpId[u.email.toLowerCase()] = id;
              empIdToEmail[id] = u.email;
            }
          }
        }
      } catch (_) {
        // If preload fails, proceed; second pass will still resolve emails for users created in this file.
      }

      // Track duplicates within the current import file
      final Set<String> seenInFile = {};
      // Collect manager assignments for a second pass (order-independent)
      final List<Map<String, dynamic>> pendingAssignments = [];

      // Safely extract the underlying value from an Excel cell (handles Data?.value)
      dynamic cellValue(dynamic c) {
        try {
          return (c as dynamic).value;
        } catch (_) {
          return c;
        }
      }

      String getCell(List row, int idx) {
        if (idx >= row.length) return '';
        final c = row[idx];
        final val = cellValue(c);
        return (val ?? '').toString().trim();
      }

      DateTime? getDate(List row, int idx) {
        if (idx < 0 || idx >= row.length) return null;
        try {
          final c = row[idx];
          final v = cellValue(c);
          if (v is DateTime) return v;
          final s = v?.toString().trim();
          if (s == null || s.isEmpty) return null;
          // Try ISO first
          try {
            return DateTime.parse(s);
          } catch (_) {}
          // Try dd/MM/yyyy or dd-MM-yyyy
          final re = RegExp(r'^(\d{1,2})[\/-](\d{1,2})[\/-](\d{4})$');
          final m = re.firstMatch(s);
          if (m != null) {
            final d = int.tryParse(m.group(1)!);
            final mo = int.tryParse(m.group(2)!);
            final y = int.tryParse(m.group(3)!);
            if (d != null && mo != null && y != null) {
              return DateTime(y, mo, d);
            }
          }
          // Try numeric excel serial date
          final n = num.tryParse(s);
          if (n != null) {
            // Excel serial date (days since 1899-12-30)
            final origin = DateTime(1899, 12, 30);
            return origin.add(Duration(days: n.floor()));
          }
          return null;
        } catch (_) {
          return null;
        }
      }

      for (int i = 1; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        final email = getCell(row, emailIdx);
        final password = getCell(row, passwordIdx);
        final rolesCell = getCell(row, rolesIdx);

        // skip empty lines
        if (email.isEmpty && password.isEmpty && rolesCell.isEmpty) {
          continue;
        }

        if (email.isEmpty || !email.contains('@')) {
          errors.add('Ligne ${i + 1}: email invalide "$email"');
          continue;
        }
        if (password.length < 6) {
          errors.add(
              'Ligne ${i + 1}: mot de passe trop court (min 6 caractères).');
          continue;
        }

        // Detect duplicate emails within the same import file
        final emailLower = email.toLowerCase();
        if (seenInFile.contains(emailLower)) {
          errors.add(
              'Ligne ${i + 1}: email dupliqué "$email" dans le fichier (ignoré).');
          continue;
        }
        seenInFile.add(emailLower);
        final bool isExisting = existingEmails.contains(emailLower);

        // Parse roles allowing ',', ';', or '|'
        final sep = rolesCell.contains(';')
            ? ';'
            : (rolesCell.contains('|') ? '|' : ',');
        final rawRoles = rolesCell
            .split(sep)
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        final roles = <String>[];

        // Reject explicit MANAGER role token (managers are not a distinct role)
        bool hasInvalidManagerRole = false;
        for (final r in rawRoles) {
          final t = r.trim().toUpperCase();
          if (t == 'MANAGER') {
            hasInvalidManagerRole = true;
            break;
          }
        }
        if (hasInvalidManagerRole) {
          errors.add(
              'Ligne ${i + 1}: rôle invalide "MANAGER". Utilisez EMPLOYEE/RH/HSE/NURSE/DOCTOR/ADMIN.');
          continue;
        }

        String mapRole(String r) {
          final t = r.trim().toUpperCase();
          if (t.startsWith('ROLE_')) return t;
          switch (t) {
            case 'ADMIN':
              return 'ROLE_ADMIN';
            case 'RH':
            case 'HR':
              return 'ROLE_RH';
            case 'EMPLOYEE':
            case 'EMPLOYE':
            case 'EMPLOYÉ':
            case 'SALARIE':
            case 'SALARIÉ':
              return 'ROLE_EMPLOYEE';
            case 'NURSE':
            case 'INFIRMIER':
            case 'INFIRMIÈRE':
              return 'ROLE_NURSE';
            case 'DOCTOR':
            case 'MEDECIN':
            case 'MÉDECIN':
              return 'ROLE_DOCTOR';
            case 'HSE':
              return 'ROLE_HSE';
            default:
              return 'ROLE_' + t.replaceAll(' ', '_');
          }
        }

        for (final r in rawRoles) {
          final nr = mapRole(r);
          if (!roles.contains(nr)) roles.add(nr);
        }

        // Branch on existing vs new user
        if (isExisting) {
          final existing = existingByEmail[emailLower];
          if (existing == null) {
            errors.add(
                'Ligne ${i + 1}: email "$email" existe déjà (cache incohérent).');
            continue;
          }

          final changes = <_FieldChange>[];
          List<String>? newRolesForUpdate;

          // Roles: only validate/apply if provided
          if (roles.isNotEmpty) {
            const allowedSingle = {
              'ROLE_ADMIN',
              'ROLE_RH',
              'ROLE_EMPLOYEE',
              'ROLE_NURSE',
              'ROLE_DOCTOR',
              'ROLE_HSE',
            };
            if (roles.length > 2) {
              errors.add(
                  'Ligne ${i + 1}: au plus deux rôles autorisés. Utilisez HSE + [ADMIN|RH|NURSE|DOCTOR|EMPLOYEE] ou un seul rôle.');
              continue;
            }
            if (roles.any((r) => !allowedSingle.contains(r))) {
              errors.add(
                  'Ligne ${i + 1}: rôle non supporté. Autorisés: ADMIN, RH, HSE, NURSE, DOCTOR, EMPLOYEE.');
              continue;
            }
            if (roles.length == 2) {
              if (!roles.contains('ROLE_HSE')) {
                errors.add(
                    'Ligne ${i + 1}: pour deux rôles, HSE doit être inclus (ex: RH+HSE).');
                continue;
              }
              final other = roles.firstWhere((r) => r != 'ROLE_HSE',
                  orElse: () => 'ROLE_HSE');
              if (other == 'ROLE_HSE') {
                errors.add('Ligne ${i + 1}: combinaison de rôles invalide.');
                continue;
              }
            }

            final oldSet = existing.roles
                .map((e) => e.trim().toUpperCase())
                .toSet()
                .toList()
              ..sort();
            final newSet = roles
                .map((e) => e.trim().toUpperCase())
                .toSet()
                .toList()
              ..sort();
            final oldStr = oldSet.join(', ');
            final newStr = newSet.join(', ');
            if (oldStr != newStr) {
              changes.add(_FieldChange('roles', 'Rôles', oldStr, newStr));
              newRolesForUpdate = roles;
            }
          }

          // Profile fields
          String? _nz(String s) => s.isNotEmpty ? s : null;
          String? firstName = _nz(getCell(row, firstNameIdx));
          String? lastName = _nz(getCell(row, lastNameIdx));
          String? position = _nz(getCell(row, positionIdx));
          String? department = _nz(getCell(row, departmentIdx));
          DateTime? dateOfBirth = getDate(row, dateOfBirthIdx);
          DateTime? hireDate = getDate(row, hireDateIdx);
          String? cin = _nz(getCell(row, cinIdx));
          String? cnss = _nz(getCell(row, cnssIdx));
          String? phoneNumber = _nz(getCell(row, phoneIdx));
          String? placeOfBirth = _nz(getCell(row, placeOfBirthIdx));
          String? address = _nz(getCell(row, addressIdx));
          String? nationality = _nz(getCell(row, nationalityIdx));
          String? city = _nz(getCell(row, cityIdx));
          String? zipCode = _nz(getCell(row, zipCodeIdx));
          String? country = _nz(getCell(row, countryIdx));
          String? genderRaw = _nz(getCell(row, genderIdx));
          String? gender;
          if (genderRaw != null) {
            final g = genderRaw.trim().toUpperCase();
            if (g.startsWith('M') ||
                g.contains('HOMME') ||
                g.contains('MALE')) {
              gender = 'HOMME';
            } else if (g.startsWith('F') ||
                g.contains('FEMME') ||
                g.contains('FEMALE')) {
              gender = 'FEMME';
            }
          }

          String fmtDate(DateTime? d) {
            if (d == null) return '-';
            final y = d.year.toString().padLeft(4, '0');
            final m = d.month.toString().padLeft(2, '0');
            final dd = d.day.toString().padLeft(2, '0');
            return '$y-$m-$dd';
          }

          final emp = existing.employee;
          // Compare and build DTO with only changed fields
          bool anyProfile = false;

          void markChange(String key, String label, String? oldV, String? newV) {
            changes.add(_FieldChange(key, label, oldV, newV));
            anyProfile = true;
          }

          // Build DTO progressively (since EmployeeCreationRequestDTO is immutable, we create one with all fields when needed)
          // Collect new values and then assign once at the end if anyProfile
          String? oldFirst = emp?.firstName;
          String? oldLast = emp?.lastName;
          String? oldJob = emp?.jobTitle;
          String? oldDept = emp?.department;
          DateTime? oldDob = emp?.birthDate;
          DateTime? oldHire = emp?.hireDate;
          String? oldCin = emp?.cin;
          String? oldCnss = emp?.cnssNumber;
          String? oldPhone = emp?.phoneNumber;
          String? oldBirthPlace = emp?.birthPlace;
          String? oldAddr = emp?.address;
          String? oldCity = emp?.city;
          String? oldZip = emp?.zipCode;
          String? oldCountry = emp?.country;
          String? oldGender = emp?.gender;

          if (firstName != null && _diffStr(oldFirst, firstName)) {
            markChange('firstName', 'Prénom', oldFirst, firstName);
          }
          if (lastName != null && _diffStr(oldLast, lastName)) {
            markChange('lastName', 'Nom', oldLast, lastName);
          }
          if (position != null && _diffStr(oldJob, position)) {
            markChange('position', 'Poste', oldJob, position);
          }
          if (department != null && _diffStr(oldDept, department)) {
            markChange('department', 'Département', oldDept, department);
          }
          if (dateOfBirth != null &&
              (oldDob == null || oldDob.compareTo(dateOfBirth) != 0)) {
            markChange('dateOfBirth', 'Date de naissance',
                oldDob != null ? fmtDate(oldDob) : '-', fmtDate(dateOfBirth));
          }
          if (hireDate != null &&
              (oldHire == null || oldHire.compareTo(hireDate) != 0)) {
            markChange('hireDate', 'Date d\'embauche',
                oldHire != null ? fmtDate(oldHire) : '-', fmtDate(hireDate));
          }
          if (cin != null && _diffStr(oldCin, cin)) {
            markChange('cin', 'CIN', oldCin, cin);
          }
          if (cnss != null && _diffStr(oldCnss, cnss)) {
            markChange('cnss', 'CNSS', oldCnss, cnss);
          }
          if (phoneNumber != null && _diffStr(oldPhone, phoneNumber)) {
            markChange('phone', 'Téléphone', oldPhone, phoneNumber);
          }
          if (placeOfBirth != null && _diffStr(oldBirthPlace, placeOfBirth)) {
            markChange('placeOfBirth', 'Lieu de naissance', oldBirthPlace, placeOfBirth);
          }
          if (address != null && _diffStr(oldAddr, address)) {
            markChange('address', 'Adresse', oldAddr, address);
          }
          if (nationality != null) {
            // No old value in model; treat as change when provided
            markChange('nationality', 'Nationalité', '-', nationality);
          }
          if (city != null && _diffStr(oldCity, city)) {
            markChange('city', 'Ville', oldCity, city);
          }
          if (zipCode != null && _diffStr(oldZip, zipCode)) {
            markChange('zipCode', 'Code postal', oldZip, zipCode);
          }
          if (country != null && _diffStr(oldCountry, country)) {
            markChange('country', 'Pays', oldCountry, country);
          }
          if (gender != null && _diffStr(oldGender, gender)) {
            markChange('gender', 'Sexe', oldGender, gender);
          }

          // Managers by email (optional). Accept only emails.
          String? m1Email;
          String? m2Email;
          String m1Raw = '';
          String m2Raw = '';
          if (manager1EmailIdx >= 0)
            m1Raw = getCell(row, manager1EmailIdx);
          else if (manager1Idx >= 0) m1Raw = getCell(row, manager1Idx);
          if (manager2EmailIdx >= 0)
            m2Raw = getCell(row, manager2EmailIdx);
          else if (manager2Idx >= 0) m2Raw = getCell(row, manager2Idx);

          if (m1Raw.isNotEmpty) {
            if (m1Raw.contains('@')) {
              m1Email = m1Raw.toLowerCase();
            } else {
              errors.add(
                  'Ligne ${i + 1} ($email): N+1 "$m1Raw" invalide. Veuillez utiliser l\'email du manager.');
            }
          }
          if (m2Raw.isNotEmpty) {
            if (m2Raw.contains('@')) {
              m2Email = m2Raw.toLowerCase();
            } else {
              errors.add(
                  'Ligne ${i + 1} ($email): N+2 "$m2Raw" invalide. Veuillez utiliser l\'email du manager.');
            }
          }

          // Old manager1 email if known
          String? oldM1Email;
          final oldMgrId = int.tryParse(emp?.manager?.id ?? '');
          if (oldMgrId != null) {
            oldM1Email = empIdToEmail[oldMgrId];
          }
          if (m1Email != null) {
            if ((oldM1Email ?? '').toLowerCase() != m1Email) {
              changes.add(_FieldChange('manager1Email', 'N+1', oldM1Email ?? '-', m1Email));
            }
          }
          if (m2Email != null) {
            changes.add(_FieldChange('manager2Email', 'N+2', '-', m2Email));
          }

          // Build profile DTO if any profile change
          if (changes.isNotEmpty) {
            final userId = int.tryParse(existing.id) ?? -1;
            final empId = int.tryParse(existing.employee?.id ?? '');
            EmployeeCreationRequestDTO? dto;
            if (anyProfile) {
              dto = EmployeeCreationRequestDTO(
                userId: userId,
                firstName: firstName,
                lastName: lastName,
                email: email,
                position: position,
                department: department,
                dateOfBirth: dateOfBirth,
                hireDate: hireDate,
                cin: cin,
                cnss: cnss,
                phoneNumber: phoneNumber,
                placeOfBirth: placeOfBirth,
                address: address,
                nationality: nationality,
                city: city,
                zipCode: zipCode,
                country: country,
                gender: gender,
              );
            }
            updateCandidates.add(_UpdateCandidate(
              rowIndex: i,
              email: email,
              userId: userId,
              employeeId: empId,
              newRoles: newRolesForUpdate,
              profileDto: dto,
              manager1Email: m1Email,
              manager2Email: m2Email,
              changes: changes,
            ));
          } else {
            errors.add(
                'Ligne ${i + 1}: email "$email" existe déjà dans le système (aucun changement détecté, ignoré).');
          }
        } else {
          // New user flow
          if (roles.isEmpty) {
            errors.add('Ligne ${i + 1}: aucun rôle fourni.');
            continue;
          }

          // Enforce allowed role combinations: either a single role among
          // [ADMIN, RH, HSE, NURSE, DOCTOR, EMPLOYEE] OR two roles with HSE + one other
          const allowedSingle = {
            'ROLE_ADMIN',
            'ROLE_RH',
            'ROLE_EMPLOYEE',
            'ROLE_NURSE',
            'ROLE_DOCTOR',
            'ROLE_HSE',
          };
          if (roles.length > 2) {
            errors.add(
                'Ligne ${i + 1}: au plus deux rôles autorisés. Utilisez HSE + [ADMIN|RH|NURSE|DOCTOR|EMPLOYEE] ou un seul rôle.');
            continue;
          }
          if (roles.any((r) => !allowedSingle.contains(r))) {
            errors.add(
                'Ligne ${i + 1}: rôle non supporté. Autorisés: ADMIN, RH, HSE, NURSE, DOCTOR, EMPLOYEE.');
            continue;
          }
          if (roles.length == 2) {
            if (!roles.contains('ROLE_HSE')) {
              errors.add(
                  'Ligne ${i + 1}: pour deux rôles, HSE doit être inclus (ex: RH+HSE).');
              continue;
            }
            final other = roles.firstWhere((r) => r != 'ROLE_HSE',
                orElse: () => 'ROLE_HSE');
            if (other == 'ROLE_HSE') {
              errors.add('Ligne ${i + 1}: combinaison de rôles invalide.');
              continue;
            }
          }

          try {
            final created = await api.createUser(email, password, roles);
            successEmails.add(email);

            // Build employee profile details if any extended fields are provided
            String? _nz(String s) => s.isNotEmpty ? s : null;

            final firstName = _nz(getCell(row, firstNameIdx));
            final lastName = _nz(getCell(row, lastNameIdx));
            final position = _nz(getCell(row, positionIdx));
            final department = _nz(getCell(row, departmentIdx));
            final dateOfBirth = getDate(row, dateOfBirthIdx);
            final hireDate = getDate(row, hireDateIdx);
            final cin = _nz(getCell(row, cinIdx));
            final cnss = _nz(getCell(row, cnssIdx));
            final phoneNumber = _nz(getCell(row, phoneIdx));
            final placeOfBirth = _nz(getCell(row, placeOfBirthIdx));
            final address = _nz(getCell(row, addressIdx));
            final nationality = _nz(getCell(row, nationalityIdx));
            final city = _nz(getCell(row, cityIdx));
            final zipCode = _nz(getCell(row, zipCodeIdx));
            final country = _nz(getCell(row, countryIdx));
            final genderRaw = _nz(getCell(row, genderIdx));
            String? gender;
            if (genderRaw != null) {
              final g = genderRaw.trim().toUpperCase();
              if (g.startsWith('M') ||
                  g.contains('HOMME') ||
                  g.contains('MALE')) {
                gender = 'HOMME';
              } else if (g.startsWith('F') ||
                  g.contains('FEMME') ||
                  g.contains('FEMALE')) {
                gender = 'FEMME';
              }
            }

            // Email-only managers: collect raw manager emails for second pass
            String? m1Email;
            String? m2Email;
            String m1Raw = '';
            String m2Raw = '';
            if (manager1EmailIdx >= 0)
              m1Raw = getCell(row, manager1EmailIdx);
            else if (manager1Idx >= 0) m1Raw = getCell(row, manager1Idx);
            if (manager2EmailIdx >= 0)
              m2Raw = getCell(row, manager2EmailIdx);
            else if (manager2Idx >= 0) m2Raw = getCell(row, manager2Idx);

            if (m1Raw.isNotEmpty) {
              if (m1Raw.contains('@')) {
                m1Email = m1Raw.toLowerCase();
              } else {
                errors.add(
                    'Ligne ${i + 1} ($email): N+1 "$m1Raw" invalide. Veuillez utiliser l\'email du manager.');
              }
            }

            if (m2Raw.isNotEmpty) {
              if (m2Raw.contains('@')) {
                m2Email = m2Raw.toLowerCase();
              } else {
                errors.add(
                    'Ligne ${i + 1} ($email): N+2 "$m2Raw" invalide. Veuillez utiliser l\'email du manager.');
              }
            }

            final userId = int.tryParse(created.id);

            if (userId != null) {
              try {
                final dto = EmployeeCreationRequestDTO(
                  userId: userId,
                  firstName: firstName,
                  lastName: lastName,
                  email: email,
                  position: position,
                  department: department,
                  dateOfBirth: dateOfBirth,
                  hireDate: hireDate,
                  cin: cin,
                  cnss: cnss,
                  phoneNumber: phoneNumber,
                  placeOfBirth: placeOfBirth,
                  address: address,
                  nationality: nationality,
                  city: city,
                  zipCode: zipCode,
                  country: country,
                  gender: gender,
                );
                final emp = await api.updateEmployeeProfile(dto);

                // Update in-memory map so later rows can reference this newly created employee by email
                final createdEmpId = int.tryParse(emp.id);
                if (createdEmpId != null) {
                  emailToEmpId[email.toLowerCase()] = createdEmpId;
                  // Save pending manager emails for second pass
                  pendingAssignments.add({
                    'row': i,
                    'email': email,
                    'empId': createdEmpId,
                    'm1': m1Email,
                    'm2': m2Email,
                  });
                } else {
                  errors.add(
                      'Ligne ${i + 1} ($email): profil mis à jour, mais ID employé introuvable pour assigner les managers.');
                }
              } catch (e) {
                errors.add(
                    'Ligne ${i + 1} ($email): échec mise à jour du profil employé: $e');
              }
            }
          } catch (e) {
            errors.add('Ligne ${i + 1} ($email): $e');
          }
        }
      }

      // Second pass: assign managers by resolving emails to employee IDs
      for (final p in pendingAssignments) {
        final int rowIndex = (p['row'] as int);
        final String email = (p['email'] as String);
        final int empId = (p['empId'] as int);
        int? mm1;
        int? mm2;
        final String? m1Email = p['m1'] as String?;
        final String? m2Email = p['m2'] as String?;

        if (m1Email != null && m1Email.isNotEmpty) {
          final resolved = emailToEmpId[m1Email];
          if (resolved != null) {
            mm1 = resolved;
          } else {
            errors.add(
                'Ligne ${rowIndex + 1} ($email): N+1 "$m1Email" introuvable (email non reconnu).');
          }
        }

        if (m2Email != null && m2Email.isNotEmpty) {
          final resolved = emailToEmpId[m2Email];
          if (resolved != null) {
            mm2 = resolved;
          } else {
            errors.add(
                'Ligne ${rowIndex + 1} ($email): N+2 "$m2Email" introuvable (email non reconnu).');
          }
        }

        // Avoid same selection and self-assignment
        if (mm1 != null && mm2 != null && mm1 == mm2) {
          errors.add(
              'Ligne ${rowIndex + 1} ($email): N+1 et N+2 ne peuvent pas être le même employé (N+2 ignoré).');
          mm2 = null;
        }
        if (mm1 == empId) {
          errors.add(
              'Ligne ${rowIndex + 1} ($email): N+1 ne peut pas être l\'employé lui-même (ignoré).');
          mm1 = null;
        }
        if (mm2 == empId) {
          errors.add(
              'Ligne ${rowIndex + 1} ($email): N+2 ne peut pas être l\'employé lui-même (ignoré).');
          mm2 = null;
        }

        if (mm1 != null || mm2 != null) {
          try {
            await api.updateEmployeeManagers(empId,
                manager1Id: mm1, manager2Id: mm2);
          } catch (e) {
            errors.add(
                'Ligne ${rowIndex + 1} ($email): échec d\'assignation des managers: $e');
          }
        }
      }

      // Close progress dialog
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }

      if (!mounted) return;
      // If updates were detected, ask for confirmation and apply (Excel flow)
      if (updateCandidates.isNotEmpty) {
        final apply = await _showReviewUpdatesDialog(updateCandidates);
        if (apply) {
          final res = await _applyUpdates(updateCandidates, api, emailToEmpId);
          appliedUpdates.addAll(res.updatedEmails);
          updateErrors.addAll(res.errors);
        } else {
          for (final c in updateCandidates) {
            errors.add(
                'Ligne ${c.rowIndex + 1} (${c.email}): mises à jour détectées mais non appliquées.');
          }
        }
      }

      await _showImportSummaryDialog(
        total: sheet.rows.length - 1,
        successEmails: successEmails,
        errors: errors,
        appliedUpdates: appliedUpdates,
        updateErrors: updateErrors,
      );

      if (successEmails.isNotEmpty || appliedUpdates.isNotEmpty) {
        _refreshUsers();
      }
    } catch (e) {
      if (mounted && progressShown) {
        Navigator.of(context, rootNavigator: true).pop();
        progressShown = false;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Échec de l\'import: $e')),
        );
      }
    }
  }

  Future<void> _showImportSummaryDialog({
    required int total,
    required List<String> successEmails,
    required List<String> errors,
    required List<String> appliedUpdates,
    required List<String> updateErrors,
  }) async {
    final theme = Theme.of(context);
    // Classify errors: duplicates in file, existing in system, and other errors
    final duplicatesInFile = <String>{};
    final existingInSystem = <String>{};
    final otherErrors = <String>[];
    final dupRe = RegExp(r'email dupliqué "([^"]+)"');
    final existRe = RegExp(r'email "([^"]+)" existe déjà');
    for (final e in errors) {
      final m1 = dupRe.firstMatch(e);
      if (m1 != null) {
        duplicatesInFile.add(m1.group(1)!);
        continue;
      }
      final m2 = existRe.firstMatch(e);
      if (m2 != null) {
        existingInSystem.add(m2.group(1)!);
        continue;
      }
      otherErrors.add(e);
    }
    final successCount = successEmails.length;
    final updateCount = appliedUpdates.length;
    final ignoredCount = duplicatesInFile.length + existingInSystem.length;
    final failCount = otherErrors.length + updateErrors.length;
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: const Text('Résultats de l\'import'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total lignes (hors en-tête): $total'),
                const SizedBox(height: 6),
                Text('Créés: $successCount',
                    style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w700)),
                if (updateCount > 0)
                  Text('Mises à jour: $updateCount',
                      style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w700)),
                Text('Échecs: $failCount',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700)),
                if (ignoredCount > 0)
                  Text('Ignorés: $ignoredCount',
                      style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                if (successEmails.isNotEmpty) ...[
                  Text('Succès (${successEmails.length})',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: successEmails
                        .map((e) => Chip(
                            label: Text(e),
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.12)))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (appliedUpdates.isNotEmpty) ...[
                  Text('Mises à jour appliquées (${appliedUpdates.length})',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: appliedUpdates
                        .map((e) => Chip(
                              label: Text(e),
                              backgroundColor:
                                  Colors.blue.withValues(alpha: 0.12),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (duplicatesInFile.isNotEmpty) ...[
                  Text(
                      'Doublons dans le fichier (ignorés) (${duplicatesInFile.length})',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: duplicatesInFile
                        .map((e) => Chip(
                              label: Text(e),
                              backgroundColor:
                                  Colors.orange.withValues(alpha: 0.12),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (existingInSystem.isNotEmpty) ...[
                  Text(
                      'Emails déjà existants (ignorés) (${existingInSystem.length})',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: -6,
                    children: existingInSystem
                        .map((e) => Chip(
                              label: Text(e),
                              backgroundColor:
                                  Colors.orange.withValues(alpha: 0.12),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                if (updateErrors.isNotEmpty) ...[
                  Text('Erreurs de mise à jour (${updateErrors.length})',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  ...updateErrors.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $e',
                            style: TextStyle(color: Colors.red.shade700)),
                      )),
                  const SizedBox(height: 12),
                ],
                if (otherErrors.isNotEmpty) ...[
                  Text('Erreurs (${otherErrors.length})',
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 6),
                  ...otherErrors.map((e) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text('• $e',
                            style: TextStyle(color: Colors.red.shade700)),
                      )),
                ],
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                const Text('Format CSV attendu:'),
                const Text('email,password,roles'),
                const Text(
                    'ex: jean@acme.com,Secret123,ROLE_EMPLOYEE|ROLE_HSE'),
                const SizedBox(height: 8),
                const Text('Règles de rôles:'),
                const Text(
                    '• Rôles autorisés: ADMIN, RH, HSE, NURSE, DOCTOR, EMPLOYEE.'),
                const Text('• 1 rôle ou 2 rôles maximum.'),
                const Text(
                    '• Si 2 rôles: HSE + un seul parmi [ADMIN|RH|NURSE|DOCTOR|EMPLOYEE].'),
                const Text(
                    '• Interdits: combinaisons sans HSE, >2 rôles, rôle inconnu, MANAGER.'),
                const SizedBox(height: 8),
                const Text('Managers (optionnel):'),
                const Text(
                    '• Un employé peut avoir 0, 1 (N+1) ou 2 (N+2) managers.'),
                const Text(
                    '• L\'assignation se fait par email: manager1Email, manager2Email.'),
                const Text(
                    '• MANAGER n\'est pas un rôle; le manager est par ex. RH, HSE, EMPLOYEE.'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _navigateToCreateUserScreen() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CreateUserScreen()),
    );

    if (result == true) {
      _refreshUsers();
    }
  }

  void _showEditUserDialog(User user) async {
    final updated = await showDialog<User>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditUserDialog(user: user),
    );
    if (updated != null) {
      if (!mounted) return;
      setState(() {
        _users = _users.map((u) => u.id == updated.id ? updated : u).toList();
      });
    }
  }

  void _showDeleteConfirmationDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirmer la suppression'),
          content: Text(
              'Êtes-vous sûr de vouloir supprimer l\'utilisateur ${user.email} ? Cette action est irréversible.'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () {
                Navigator.of(context).pop(); // Ferme le dialogue
                //if (user.id != null) {
                //_deleteUser(int.parse(user.id));
                // } // Supprime l'utilisateur
                _deleteUser(user.id); // Supprime l'utilisateur
              },
            ),
          ],
        );
      },
    );
  }

  void _showUserDetailsDialog(User user) {
    final theme = Theme.of(context);
    final emp = user.employee;
    String _fmtDate(DateTime? d) {
      if (d == null) return '-';
      String two(int n) => n.toString().padLeft(2, '0');
      return '${d.year}-${two(d.month)}-${two(d.day)}';
    }

    Widget sectionTitle(IconData icon, String title) {
      return Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.35)),
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
      final c = color ?? theme.colorScheme.onSurface.withValues(alpha: 0.75);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.65),
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

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final fullName = (emp?.fullName.isNotEmpty == true)
            ? emp!.fullName
            : (user.username.isNotEmpty ? user.username : user.email);

        final roleWrap = Wrap(
          spacing: 6,
          runSpacing: -6,
          children: [for (final r in user.roles) _roleChip(r, theme)],
        );

        return Dialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          backgroundColor: theme.colorScheme.surface,
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
                              Text("Informations de l'Utilisateur",
                                  style: theme.textTheme.titleLarge
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                'Détails complets de l\'utilisateur sélectionné',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.65),
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
                      color: theme.colorScheme.surface,
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
                                Icons.person_outline, 'Informations de Base'),
                            const SizedBox(height: 12),
                            kvRow('Nom complet', fullName,
                                icon: Icons.badge_outlined),
                            kvRow(
                                "Nom d'utilisateur", '@${user.username}'.trim(),
                                icon: Icons.alternate_email),
                            kvRow('Email', user.email,
                                icon: Icons.email_outlined),
                            Row(children: [
                              _statusChip(
                                  user.enabled ? 'Vérifié' : 'Non vérifié',
                                  user.enabled
                                      ? Colors.green.shade600
                                      : Colors.orange.shade700,
                                  theme),
                              const SizedBox(width: 6),
                              _statusChip(
                                  user.isActive ? 'Actif' : 'Inactif',
                                  user.isActive
                                      ? Colors.green.shade600
                                      : Colors.red.shade600,
                                  theme),
                            ]),
                            const SizedBox(height: 10),
                            roleWrap,
                          ],
                        ),
                      ),
                    ),

                    if (emp != null) ...[
                      const SizedBox(height: 12),
                      // Section: Personal Info
                      Card(
                        color: theme.colorScheme.surface,
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
                                  'Informations Personnelles'),
                              const SizedBox(height: 12),
                              kvRow('Adresse', emp.address ?? '-',
                                  icon: Icons.home_outlined),
                              kvRow('Téléphone', emp.phoneNumber ?? '-',
                                  icon: Icons.phone_outlined),
                              kvRow('Profession', emp.jobTitle ?? '-',
                                  icon: Icons.work_outline),
                              kvRow('Département', emp.department ?? '-',
                                  icon: Icons.account_tree_outlined),
                              kvRow(
                                  'Date de naissance', _fmtDate(emp.birthDate),
                                  icon: Icons.cake_outlined),
                              kvRow("Date d'embauche", _fmtDate(emp.hireDate),
                                  icon: Icons.event_available_outlined),
                            ],
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 12),
                    // Section: Auth Info
                    Card(
                      color: theme.colorScheme.surface,
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
                            sectionTitle(Icons.lock_outline,
                                "Informations d'Authentification"),
                            const SizedBox(height: 12),
                            kvRow('Email vérifié',
                                user.enabled ? 'Vérifié' : 'Non vérifié',
                                icon: Icons.verified_outlined,
                                color: user.enabled
                                    ? Colors.green.shade700
                                    : Colors.orange.shade700),
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
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            _showEditUserDialog(user);
                          },
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Modifier'),
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

  void _showAssignManagersDialog(User user) {
    if (user.employee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Cet utilisateur n'a pas de profil employé.")),
      );
      return;
    }

    User? selectedN1;
    User? selectedN2;
    // Ensure we only prefill once; otherwise selecting "Aucun" gets overridden on rebuild
    bool prefilledManagers = false;

    showDialog(
      context: context,
      builder: (ctx) {
        final api = Provider.of<ApiService>(context, listen: false);
        return StatefulBuilder(
          builder: (ctx2, setStateDialog) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.account_tree_rounded,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text('Assigner N+1 / N+2'),
                ],
              ),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              content: SizedBox(
                width: 520,
                child: FutureBuilder<List<User>>(
                  future: api.getAllUsers(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return Text('Erreur de chargement: ${snapshot.error}');
                    }
                    // Build candidate list: allowed roles only; include inactive/unverified; exclude INFIRMIER/MEDECIN; exclude self
                    final List<User> allUsers = snapshot.data ?? [];
                    final Map<String, User> byEmpId = {};
                    String normRole(String r) =>
                        r.toUpperCase().replaceAll('ROLE_', '').trim();
                    bool hasForbidden(Iterable<String> roles) {
                      final n = roles.map(normRole);
                      return n.contains('INFIRMIER') ||
                          n.contains('INFERMIER') ||
                          n.contains('MEDECIN');
                    }

                    bool allowedByRole(Iterable<String> roles) {
                      final n = roles.map(normRole).toSet();
                      // Autoriser ADMIN, RH, EMPLOYEE, et aussi HSE seul
                      if (n.contains('ADMIN') ||
                          n.contains('RH') ||
                          n.contains('EMPLOYEE') ||
                          n.contains('HSE')) {
                        return true;
                      }
                      return false;
                    }

                    for (final u in allUsers) {
                      final emp = u.employee;
                      if (emp == null) continue;
                      // Exclude the employee themselves
                      if (emp.id == user.employee!.id) continue;
                      // Role-based filtering
                      if (hasForbidden(u.roles)) continue;
                      if (!allowedByRole(u.roles)) continue;
                      // Deduplicate by employeeId, prefer active/enabled entries
                      if (!byEmpId.containsKey(emp.id)) {
                        byEmpId[emp.id] = u;
                      } else {
                        final existing = byEmpId[emp.id]!;
                        final newActive =
                            (u.enabled == true && u.isActive == true) ? 1 : 0;
                        final oldActive = (existing.enabled == true &&
                                existing.isActive == true)
                            ? 1
                            : 0;
                        if (newActive > oldActive) {
                          byEmpId[emp.id] = u;
                        }
                      }
                    }
                    // Determine currently assigned managers (prefer top-level n1Id/n2Id; fallback to nested manager for N+1)
                    int? currentN1EmpId = user.n1Id;
                    if (currentN1EmpId == null) {
                      final nestedMgrIdStr = user.employee?.manager?.id;
                      if (nestedMgrIdStr != null) {
                        currentN1EmpId = int.tryParse(nestedMgrIdStr);
                      }
                    }
                    int? currentN2EmpId = user.n2Id;
                    if (currentN2EmpId == null) {
                      // Fallback: N+2 as manager of manager (if backend embeds nested managers)
                      final nestedMgr2IdStr =
                          user.employee?.manager?.manager?.id;
                      if (nestedMgr2IdStr != null) {
                        currentN2EmpId = int.tryParse(nestedMgr2IdStr);
                      }
                    }

                    // Ensure currently assigned managers appear in the dropdown even if inactive/disabled
                    User? _findUserByEmpIdInAll(int empId) {
                      for (final u in allUsers) {
                        final emp = u.employee;
                        if (emp == null) continue;
                        if (emp.id == empId.toString() ||
                            int.tryParse(emp.id) == empId) {
                          // Exclude the employee themselves
                          if (emp.id == user.employee!.id) return null;
                          return u;
                        }
                      }
                      return null;
                    }

                    if (currentN1EmpId != null &&
                        !byEmpId.containsKey(currentN1EmpId.toString())) {
                      final u = _findUserByEmpIdInAll(currentN1EmpId);
                      if (u != null &&
                          !hasForbidden(u.roles) &&
                          allowedByRole(u.roles)) {
                        byEmpId[u.employee!.id] = u;
                      }
                    }
                    if (currentN2EmpId != null &&
                        !byEmpId.containsKey(currentN2EmpId.toString())) {
                      final u = _findUserByEmpIdInAll(currentN2EmpId);
                      if (u != null &&
                          !hasForbidden(u.roles) &&
                          allowedByRole(u.roles)) {
                        byEmpId[u.employee!.id] = u;
                      }
                    }

                    final employeesUsers = byEmpId.values.toList()
                      ..sort((a, b) => (a.employee!.fullName)
                          .compareTo(b.employee!.fullName));
                    // Prefill selected managers based on user's existing manager IDs (only once)
                    if (!prefilledManagers) {
                      if (currentN1EmpId != null) {
                        final idx1 = employeesUsers.indexWhere((u) {
                          final empId = u.employee?.id;
                          return empId == currentN1EmpId!.toString() ||
                              int.tryParse(empId ?? '') == currentN1EmpId;
                        });
                        if (idx1 != -1) {
                          selectedN1 = employeesUsers[idx1];
                        }
                      }
                      if (currentN2EmpId != null) {
                        final idx2 = employeesUsers.indexWhere((u) {
                          final empId = u.employee?.id;
                          return empId == currentN2EmpId!.toString() ||
                              int.tryParse(empId ?? '') == currentN2EmpId;
                        });
                        if (idx2 != -1) {
                          selectedN2 = employeesUsers[idx2];
                        }
                      }
                      if (selectedN1 != null &&
                          selectedN2 != null &&
                          selectedN1!.employee?.id == selectedN2!.employee?.id) {
                        // Avoid same selection prefilled for both
                        selectedN2 = null;
                      }
                      prefilledManagers = true;
                    }

                    Widget buildDropdown(
                        {required String label,
                        required User? value,
                        required ValueChanged<User?> onChanged,
                        required IconData icon}) {
                      final theme = Theme.of(context);
                      Color roleColor(String role) {
                        final r = role.toUpperCase();
                        switch (r) {
                          case 'ADMIN':
                            return theme.colorScheme.primary;
                          case 'RH':
                            return Colors.purple;
                          case 'HSE':
                            return Colors.teal;
                          case 'EMPLOYEE':
                            return Colors.blueGrey;
                          default:
                            return theme.colorScheme.secondary;
                        }
                      }

                      Widget buildRoleChips(List<String> roles) {
                        return Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: roles.map((r) {
                            final color = roleColor(r);
                            return Chip(
                              label: Text(r,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.onPrimary)),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: color.withValues(alpha: 0.85),
                              side: BorderSide.none,
                            );
                          }).toList(),
                        );
                      }

                      return DropdownButtonFormField<User?>(
                        decoration: InputDecoration(
                          labelText: label,
                          prefixIcon: Icon(icon),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          filled: true,
                          fillColor: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.12),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        value: value,
                        isExpanded: true,
                        items: () {
                          final List<DropdownMenuItem<User?>> items = [
                            const DropdownMenuItem<User?>(
                                value: null, child: Text('Aucun')),
                          ];
                          for (final u in employeesUsers) {
                            final emp = u.employee!;
                            final fullName = emp.fullName.isNotEmpty
                                ? emp.fullName
                                : 'Employé #${emp.id}';
                            final rolesShort =
                                u.roles.map((r) => normRole(r)).toList();
                            final inactive = u.enabled != true || u.isActive != true;
                            final initials = (fullName.isNotEmpty
                                    ? fullName
                                    : (u.email.split('@').first))
                                .trim()
                                .split(RegExp(r'\s+'))
                                .where((p) => p.isNotEmpty)
                                .take(2)
                                .map((p) => p.characters.first.toUpperCase())
                                .join();

                            items.add(
                              DropdownMenuItem<User?>(
                                value: u,
                                child: Container(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  decoration: const BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Color(0x1F000000),
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: theme
                                            .colorScheme
                                            .surfaceTint
                                            .withValues(alpha: 0.2),
                                        child: Text(
                                          initials,
                                          style: theme.textTheme.labelSmall,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    fullName,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: theme
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.copyWith(
                                                            fontWeight:
                                                                FontWeight.w600),
                                                  ),
                                                ),
                                                if (inactive)
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.only(left: 8.0),
                                                    child: Chip(
                                                      label: const Text('non vérifié'),
                                                      backgroundColor:
                                                          Colors.amber.shade600,
                                                      labelStyle: theme
                                                          .textTheme
                                                          .labelSmall
                                                          ?.copyWith(
                                                              color: Colors.white),
                                                      visualDensity:
                                                          VisualDensity.compact,
                                                      materialTapTargetSize:
                                                          MaterialTapTargetSize
                                                              .shrinkWrap,
                                                      padding: const EdgeInsets
                                                              .symmetric(
                                                          horizontal: 6),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              u.email,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface
                                                    .withValues(alpha: 0.7),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 6),
                                            buildRoleChips(rolesShort),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }
                          return items;
                        }(),
                        selectedItemBuilder: (context) {
                          final all = <User?>[null, ...employeesUsers];
                          return all.map((uu) {
                            if (uu == null) {
                              return const Text('Aucun');
                            }
                            final emp = uu.employee!;
                            final fullName = emp.fullName.isNotEmpty
                                ? emp.fullName
                                : 'Employé #${emp.id}';
                            final rolesShort = uu.roles.map((r) => normRole(r)).toList();
                            final inactive = uu.enabled != true || uu.isActive != true;
                            return Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    fullName,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (inactive)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 6.0),
                                    child: Icon(Icons.error_outline,
                                        color: Colors.amber.shade700, size: 16),
                                  ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Wrap(
                                    spacing: 4,
                                    children: rolesShort.take(2).map((r) {
                                      final c = roleColor(r).withValues(alpha: 0.9);
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: c,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          r,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: Colors.white),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            );
                          }).toList();
                        },
                        onChanged: onChanged,
                      );
                    }

                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildDropdown(
                          label: 'Manager N+1',
                          value: selectedN1,
                          onChanged: (val) =>
                              setStateDialog(() => selectedN1 = val),
                          icon: Icons.supervisor_account_outlined,
                        ),
                        const SizedBox(height: 12),
                        buildDropdown(
                          label: 'Manager N+2',
                          value: selectedN2,
                          onChanged: (val) =>
                              setStateDialog(() => selectedN2 = val),
                          icon: Icons.account_tree_outlined,
                        ),
                      ],
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () async {
                    try {
                      final empId = int.tryParse(user.employee!.id);
                      if (empId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('ID employé invalide.')),
                        );
                        return;
                      }

                      if (selectedN1 != null &&
                          selectedN2 != null &&
                          selectedN1!.employee?.id ==
                              selectedN2!.employee?.id) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('N+1 et N+2 doivent être différents.')),
                        );
                        return;
                      }

                      final m1Id = selectedN1?.employee?.id != null
                          ? int.tryParse(selectedN1!.employee!.id)
                          : null;
                      final m2Id = selectedN2?.employee?.id != null
                          ? int.tryParse(selectedN2!.employee!.id)
                          : null;

                      final api =
                          Provider.of<ApiService>(context, listen: false);
                      await api.updateEmployeeManagers(empId,
                          manager1Id: m1Id, manager2Id: m2Id);

                      if (!mounted) return;
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Managers mis à jour avec succès.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      _refreshUsers();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur lors de la mise à jour: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildLoadingShimmer(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB);
    final highlight =
        isDark ? const Color(0xFF4B5563) : const Color(0xFFF3F4F6);
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 6,
      itemBuilder: (context, index) {
        final skeleton = Card(
          color: theme.colorScheme.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFFE5E7EB)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(shape: BoxShape.circle),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: base,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12, width: 200, color: base),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                              height: 10,
                              width: 80,
                              decoration: BoxDecoration(
                                  color: base,
                                  borderRadius: BorderRadius.circular(999))),
                          const SizedBox(width: 8),
                          Container(
                              height: 10,
                              width: 70,
                              decoration: BoxDecoration(
                                  color: base,
                                  borderRadius: BorderRadius.circular(999))),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                        color: base, borderRadius: BorderRadius.circular(8))),
                const SizedBox(width: 6),
                Container(
                    height: 28,
                    width: 28,
                    decoration: BoxDecoration(
                        color: base, borderRadius: BorderRadius.circular(8))),
              ],
            ),
          ),
        );

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                period: const Duration(milliseconds: 1100),
                child: skeleton,
              ),
            ),
          ),
        );
      },
    );
  }

//  void _deleteUser(int userId) async {
  void _deleteUser(String userId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.deleteUser(int.parse(userId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Utilisateur supprimé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
      _refreshUsers(); // Rafraîchir la liste
    } on ApiException catch (e) {
      if (!mounted) return;
      String msg = e.message;
      if (e.statusCode == 409) {
        // Conflit de contrainte: utilisateur référencé (par ex. rendez-vous)
        msg = msg.isNotEmpty
            ? msg
            : "Impossible de supprimer l'utilisateur: il est encore référencé par des rendez-vous. Veuillez d'abord réaffecter ou libérer ces rendez-vous, ou désactiver le compte.";
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la suppression : $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showResendActivationDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Renvoyer le code d\'activation'),
          content:
              Text('Envoyer un nouveau code d\'activation à ${user.email} ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Envoyer'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final authService =
                      Provider.of<AuthService>(context, listen: false);
                  await authService.resendActivationCode(user.email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Code d\'activation renvoyé.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Échec de l\'envoi: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _showResetPasswordDialog(User user) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Réinitialiser le mot de passe'),
          content:
              Text('Envoyer un email de réinitialisation à ${user.email} ?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Envoyer'),
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  final apiService =
                      Provider.of<ApiService>(context, listen: false);
                  await apiService.forgotPassword(user.email);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Email de réinitialisation envoyé.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Échec de l\'envoi: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isCompactTopBar = width < 720;
    final isVeryCompactTopBar = width < 560;
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        toolbarHeight: 80,
        title: _selectMode
            ? Text('Sélection: ${_selectedUserIds.length}')
            : const Text('Gestion des Utilisateurs'),
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Quitter la sélection',
                onPressed: _clearSelection,
              )
            : null,
        backgroundColor: theme.colorScheme.surface.withValues(alpha: 0.85),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          ),
        ),
        actions: _selectMode
            ? [
                if (isVeryCompactTopBar) ...[
                  TextButton.icon(
                    onPressed: _isBulkDeleting ? null : _selectAllFiltered,
                    icon: const Icon(Icons.select_all),
                    label: const Text('Tout sél.'),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _isBulkDeleting ? null : _clearSelection,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Tout désél.'),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ] else ...[
                  Tooltip(
                    message: 'Tout sélectionner (liste filtrée)',
                    child: OutlinedButton.icon(
                      onPressed: _isBulkDeleting ? null : _selectAllFiltered,
                      icon: const Icon(Icons.select_all),
                      label: const Text('Tout sélectionner'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Tout désélectionner',
                    child: OutlinedButton.icon(
                      onPressed: _isBulkDeleting ? null : _clearSelection,
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Tout désélectionner'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
                if (isVeryCompactTopBar)
                  IconButton(
                    tooltip:
                        'Supprimer la sélection (${_selectedUserIds.length})',
                    onPressed: _isBulkDeleting || _selectedUserIds.isEmpty
                        ? null
                        : _confirmAndDeleteSelected,
                    icon: Icon(Icons.delete, color: Colors.red.shade600),
                  )
                else ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message:
                        'Supprimer la sélection (${_selectedUserIds.length})',
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      onPressed: _isBulkDeleting || _selectedUserIds.isEmpty
                          ? null
                          : _confirmAndDeleteSelected,
                      icon: const Icon(Icons.delete),
                      label:
                          Text('Supprimer (${_selectedUserIds.length})'),
                    ),
                  ),
                ],
              ]
            : [
                const ThemeControls(),
                const SizedBox(width: 8),
                if (_canCreateUser)
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: _navigateToCreateUserScreen,
                    tooltip: 'Nouvel utilisateur',
                  ),
                if (_canCreateUser)
                  if (isCompactTopBar)
                    PopupMenuButton<int>(
                      tooltip: 'Plus',
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        switch (value) {
                          case 1:
                            _importUsersFromCsv();
                            break;
                          case 2:
                            _importUsersFromExcel();
                            break;
                          case 3:
                            _downloadExcelTemplate();
                            break;
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem<int>(
                          value: 1,
                          child: Row(
                            children: const [
                              Icon(Icons.file_upload),
                              SizedBox(width: 8),
                              Text('Importer CSV'),
                            ],
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: 2,
                          child: Row(
                            children: const [
                              Icon(Icons.grid_on),
                              SizedBox(width: 8),
                              Text('Importer Excel'),
                            ],
                          ),
                        ),
                        PopupMenuItem<int>(
                          value: 3,
                          child: Row(
                            children: const [
                              Icon(Icons.download),
                              SizedBox(width: 8),
                              Text('Modèle Excel'),
                            ],
                          ),
                        ),
                      ],
                    )
                  else ...[
                    IconButton(
                      icon: const Icon(Icons.file_upload),
                      onPressed: _importUsersFromCsv,
                      tooltip: 'Importer CSV',
                    ),
                    IconButton(
                      icon: const Icon(Icons.grid_on),
                      onPressed: _importUsersFromExcel,
                      tooltip: 'Importer Excel',
                    ),
                    IconButton(
                      icon: const Icon(Icons.download),
                      onPressed: _downloadExcelTemplate,
                      tooltip: 'Télécharger le modèle Excel',
                    ),
                  ],
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _refreshUsers,
                  tooltip: 'Actualiser',
                ),
              ],
      ),
      body: _isLoading
          ? _buildLoadingShimmer(theme)
          : RefreshIndicator(
              onRefresh: _loadData,
              child: _users.isEmpty
                  ? const Center(child: Text('Aucun utilisateur trouvé.'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _filteredUsers.length + 1, // + filters card
                      itemBuilder: (context, index) {
                        Widget content;
                        if (index == 0) {
                          content = _buildFiltersBar(theme);
                        } else {
                          final user = _filteredUsers[index - 1];
                          content = _buildUserRowCard(theme, user);
                        }
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1400),
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: content,
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  // Derived filtered list
  List<User> get _filteredUsers {
    final q = _query.trim().toLowerCase();
    final r = _roleFilter?.trim().toUpperCase();
    final s = _statusFilter?.trim().toUpperCase();
    final v = _verificationFilter?.trim().toUpperCase();

    var list = _users.where((u) {
      final matchesQuery = q.isEmpty ||
          u.email.toLowerCase().contains(q) ||
          u.username.toLowerCase().contains(q);
      final matchesRole = r == null ||
          r.isEmpty ||
          u.roles.any((role) => role.trim().toUpperCase().contains(r));
      final matchesStatus =
          s == null || s.isEmpty || (s == 'ACTIF' ? u.isActive : !u.isActive);
      final matchesVerification =
          v == null || v.isEmpty || (v == 'VERIFIE' ? u.enabled : !u.enabled);
      return matchesQuery &&
          matchesRole &&
          matchesStatus &&
          matchesVerification;
    }).toList();

    int cmp(String a, String b) => a.toLowerCase().compareTo(b.toLowerCase());

    list.sort((a, b) {
      switch (_sortKey) {
        case 'Rôle':
          final ar = a.roles.isNotEmpty ? a.roles.first : '';
          final br = b.roles.isNotEmpty ? b.roles.first : '';
          return cmp(ar, br);
        case 'Statut':
          // Actif > Inactif by default
          return (b.isActive ? 1 : 0).compareTo(a.isActive ? 1 : 0);
        case 'Nom':
        default:
          final an = a.username.isNotEmpty ? a.username : a.email;
          final bn = b.username.isNotEmpty ? b.username : b.email;
          return cmp(an, bn);
      }
    });

    if (!_sortAsc) {
      list = list.reversed.toList();
    }
    return list;
  }

  Widget _buildFiltersBar(ThemeData theme) {
    final roles = {
      for (final u in _users) ...u.roles.map((e) => e.trim().toUpperCase())
    }.toList()
      ..sort();
    return Column(
      children: [
        _buildPageHeader(theme),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Card(
            color: theme.colorScheme.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 520;
                  final full = constraints.maxWidth;
                  final wSearch = isCompact ? full : 320.0;
                  final wRole = isCompact ? full : 220.0;
                  final wStatus = isCompact ? full : 200.0;
                  final wVerify = isCompact ? full : 200.0;
                  final wSort = isCompact ? full : 180.0;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filtres et Recherche',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.9),
                          )),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          SizedBox(
                            width: wSearch,
                            child: TextField(
                              decoration: InputDecoration(
                                hintText:
                                    'Rechercher par nom, email, téléphone...',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                          ),
                          SizedBox(
                            width: wRole,
                            child: DropdownButtonFormField<String?>(
                              value: _roleFilter,
                              items: [
                                const DropdownMenuItem<String?>(
                                    value: null, child: Text('Tous les rôles')),
                                ...roles.map(
                                  (r) => DropdownMenuItem<String?>(
                                      value: r, child: Text(_roleLabel(r))),
                                ),
                              ],
                              onChanged: (v) => setState(() => _roleFilter = v),
                              decoration: const InputDecoration(
                                prefixIcon:
                                    const Icon(Icons.verified_user_outlined),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: wStatus,
                            child: DropdownButtonFormField<String?>(
                              value: _statusFilter,
                              items: const [
                                DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Tous les statuts')),
                                DropdownMenuItem<String?>(
                                    value: 'ACTIF', child: Text('Actif')),
                                DropdownMenuItem<String?>(
                                    value: 'INACTIF', child: Text('Inactif')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _statusFilter = v),
                              decoration: const InputDecoration(
                                prefixIcon:
                                    const Icon(Icons.toggle_on_outlined),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: wVerify,
                            child: DropdownButtonFormField<String?>(
                              value: _verificationFilter,
                              items: const [
                                DropdownMenuItem<String?>(
                                    value: null, child: Text('Tous (vérif.)')),
                                DropdownMenuItem<String?>(
                                    value: 'VERIFIE', child: Text('Vérifié')),
                                DropdownMenuItem<String?>(
                                    value: 'NON_VERIFIE',
                                    child: Text('Non vérifié')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _verificationFilter = v),
                              decoration: const InputDecoration(
                                prefixIcon: const Icon(Icons.verified_outlined),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: wSort,
                            child: DropdownButtonFormField<String>(
                              value: _sortKey,
                              items: const [
                                DropdownMenuItem<String>(
                                    value: 'Nom',
                                    child: Text('Trier par: Nom')),
                                DropdownMenuItem<String>(
                                    value: 'Rôle',
                                    child: Text('Trier par: Rôle')),
                                DropdownMenuItem<String>(
                                    value: 'Statut',
                                    child: Text('Trier par: Statut')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _sortKey = v ?? 'Nom'),
                              decoration: const InputDecoration(
                                prefixIcon: const Icon(Icons.sort_by_alpha),
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 56,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _sortAsc = !_sortAsc),
                              icon: Icon(_sortAsc
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward),
                              label: Text(_sortAsc ? 'Asc' : 'Desc'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        _buildUsersSectionHeader(theme),
      ],
    );
  }

  Widget _buildPageHeader(ThemeData theme) {
    final count = _filteredUsers.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 520;

              final leading = Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xffB71C1C), Color(0xffE53935)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xffB71C1C).withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(Icons.admin_panel_settings,
                    color: Colors.white, size: 22),
              );

              final title = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gestion des Utilisateurs',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(
                    'Gérez les utilisateurs et leurs permissions - $count utilisateur(s)',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.65),
                    ),
                  ),
                  // RH has full admin permissions: removing read-only banner
                ],
              );

              final actions = Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _refreshUsers,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Actualiser'),
                  ),
                  if (_canCreateUser)
                    _gradientActionButton(
                      icon: Icons.person_add_alt_1,
                      label: 'Nouvel Utilisateur',
                      onTap: _navigateToCreateUserScreen,
                    ),
                  if (_canCreateUser)
                    OutlinedButton.icon(
                      onPressed: _importUsersFromCsv,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Importer CSV'),
                    ),
                  if (_canCreateUser)
                    OutlinedButton.icon(
                      onPressed: _importUsersFromExcel,
                      icon: const Icon(Icons.grid_on),
                      label: const Text('Importer Excel'),
                    ),
                  if (_canCreateUser)
                    OutlinedButton.icon(
                      onPressed: _downloadExcelTemplate,
                      icon: const Icon(Icons.download),
                      label: const Text('Modèle Excel'),
                    ),
                ],
              );

              if (!isCompact) {
                return Row(
                  children: [
                    leading,
                    const SizedBox(width: 12),
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    Flexible(
                        child: Align(
                            alignment: Alignment.centerRight, child: actions)),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      leading,
                      const SizedBox(width: 12),
                      Expanded(child: title),
                    ],
                  ),
                  const SizedBox(height: 12),
                  actions,
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUsersSectionHeader(ThemeData theme) {
    final count = _filteredUsers.length;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Card(
        color: theme.colorScheme.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.group_outlined,
                        size: 16, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Text('Utilisateurs ($count)',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Liste de tous les utilisateurs du système avec leurs informations détaillées',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserRowCard(ThemeData theme, User user) {
    final email = user.email;
    final name =
        user.username.isNotEmpty ? user.username : email.split('@').first;
    final first = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final roles = user.roles;
    final userId = user.id;
    final bool isSelected = _selectedUserIds.contains(userId);
    return Card(
      color: theme.colorScheme.surface,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: GestureDetector(
          onLongPress: () => _startSelectionWith(userId),
          onTap: () {
            if (_selectMode) {
              _onRowCheckboxToggled(userId, !isSelected);
            }
          },
          child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 520;

            final avatar = CircleAvatar(
              radius: 18,
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Text(first,
                  style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700)),
            );

            final emailText = Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            );

            final statusWrap = Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _statusChip(
                  user.enabled ? 'Vérifié' : 'Non vérifié',
                  user.enabled ? Colors.green.shade600 : Colors.orange.shade700,
                  theme,
                ),
                _statusChip(
                  user.isActive ? 'Actif' : 'Inactif',
                  user.isActive ? Colors.green.shade600 : Colors.red.shade600,
                  theme,
                ),
              ],
            );

            final roleWrap = Wrap(
              spacing: 6,
              runSpacing: -6,
              children: [
                for (final r in roles) _roleChip(r, theme),
              ],
            );

            final actionsRow = (_canManageUsers)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (user.employee != null) ...[
                        _iconActionButton(
                          icon: Icons.supervisor_account,
                          color: Colors.purple.shade600,
                          tooltip: 'Assigner N+1/N+2',
                          onTap: () => _showAssignManagersDialog(user),
                        ),
                        const SizedBox(width: 6),
                      ],
                      _iconActionButton(
                        icon: Icons.visibility_outlined,
                        color: Colors.indigo.shade600,
                        tooltip: 'Voir les informations',
                        onTap: () => _showUserDetailsDialog(user),
                      ),
                      const SizedBox(width: 6),
                      if (!user.enabled) ...[
                        _iconActionButton(
                          icon: Icons.mark_email_unread_outlined,
                          color: Colors.orange.shade700,
                          tooltip: 'Renvoyer activation',
                          onTap: () => _showResendActivationDialog(user),
                        ),
                        const SizedBox(width: 6),
                      ],
                      _iconActionButton(
                        icon: Icons.vpn_key_outlined,
                        color: Colors.teal.shade700,
                        tooltip: 'Réinitialiser le mot de passe',
                        onTap: () => _showResetPasswordDialog(user),
                      ),
                      const SizedBox(width: 6),
                      _iconActionButton(
                        icon: Icons.edit,
                        color: Colors.blue.shade600,
                        tooltip: 'Modifier',
                        onTap: () => _showEditUserDialog(user),
                      ),
                      const SizedBox(width: 6),
                      _iconActionButton(
                        icon: Icons.delete,
                        color: Colors.red.shade600,
                        tooltip: 'Supprimer',
                        onTap: () => _showDeleteConfirmationDialog(user),
                      ),
                    ],
                  )
                : const SizedBox.shrink();

            if (!isCompact) {
              return Row(
                children: [
                  if (_selectMode)
                    Checkbox(
                      value: isSelected,
                      onChanged: (v) =>
                          _onRowCheckboxToggled(userId, v ?? false),
                    ),
                  avatar,
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: emailText),
                            const SizedBox(width: 8),
                            _statusChip(
                              user.enabled ? 'Vérifié' : 'Non vérifié',
                              user.enabled
                                  ? Colors.green.shade600
                                  : Colors.orange.shade700,
                              theme,
                            ),
                            const SizedBox(width: 6),
                            _statusChip(
                              user.isActive ? 'Actif' : 'Inactif',
                              user.isActive
                                  ? Colors.green.shade600
                                  : Colors.red.shade600,
                              theme,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        roleWrap,
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (!_selectMode && _canManageUsers) actionsRow,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (_selectMode)
                      Checkbox(
                        value: isSelected,
                        onChanged: (v) =>
                            _onRowCheckboxToggled(userId, v ?? false),
                      ),
                    avatar,
                    const SizedBox(width: 12),
                    Expanded(child: emailText),
                  ],
                ),
                const SizedBox(height: 8),
                statusWrap,
                const SizedBox(height: 6),
                roleWrap,
                if (!_selectMode && _canManageUsers) ...[
                  const SizedBox(height: 8),
                  actionsRow,
                ],
              ],
            );
          },
          ),
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 8, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _roleChip(String role, ThemeData theme) {
    final r = role.trim();
    final c = _roleColor(r) ?? theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_user_outlined, size: 14, color: c),
          const SizedBox(width: 6),
          Text(_roleLabel(r),
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _roleLabel(String role) {
    final up = role.trim().toUpperCase();
    if (up.contains('ADMIN')) return 'Admin';
    if (up.contains('EMPLOY') ||
        up.contains('EMPLOYEE') ||
        up.contains('SALAR')) return 'Employé';
    if (up.contains('RH') || up.contains('HR')) return 'RH';
    if (up.contains('HSE')) return 'HSE';
    if (up.contains('NURSE') || up.contains('INFIRM')) return 'Infirmier';
    if (up.contains('DOCT') || up.contains('MEDEC')) return 'Médecin';
    final cleaned =
        up.replaceAll('ROLE_', '').replaceAll('_', ' ').toLowerCase();
    return cleaned
        .split(' ')
        .where((e) => e.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  Color? _roleColor(String r) {
    final up = r.toUpperCase();
    if (up.contains('ADMIN')) return Colors.red.shade600;
    if (up.contains('SALAR') || up.contains('EMPLOY'))
      return Colors.blue.shade600;
    if (up.contains('INFIRMI')) return Colors.purple.shade600;
    if (up.contains('MEDEC') || up.contains('DOCT'))
      return Colors.green.shade600;
    return null;
  }

  Widget _gradientActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xffB71C1C), Color(0xffE53935)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xffB71C1C).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 2),
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _iconActionButton(
      {required IconData icon,
      required Color color,
      required String tooltip,
      required VoidCallback onTap}) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}
