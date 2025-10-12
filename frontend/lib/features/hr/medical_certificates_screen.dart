import 'package:flutter/material.dart';
import 'package:oshapp/shared/models/uploaded_medical_certificate.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

class MedicalCertificatesScreen extends StatefulWidget {
  final int? employeeId;
  final String? employeeName;

  const MedicalCertificatesScreen({super.key, this.employeeId, this.employeeName});

  @override
  MedicalCertificatesScreenState createState() =>
      MedicalCertificatesScreenState();
}

class MedicalCertificatesScreenState extends State<MedicalCertificatesScreen> {
  List<UploadedMedicalCertificate> _certificates = [];
  bool _isLoading = true;
  List<Employee>? _allEmployees; // Cache for employees

  @override
  void initState() {
    super.initState();
    _loadCertificates();
  }

  Future<void> _loadCertificates() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      List<UploadedMedicalCertificate> certificates =
          await apiService.getUploadedMedicalCertificates();
      // Optionally filter by employee if provided
      final int? empId = widget.employeeId;
      if (empId != null) {
        certificates = certificates
            .where((c) => c.employeeId == empId)
            .toList(growable: false);
      }
      if (mounted) {
        setState(() {
          _certificates = certificates;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load certificates: $e')),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openPdf(String? filePath) async {
    if (filePath == null || filePath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun fichier PDF disponible')),
      );
      return;
    }

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      // Use ApiService's getPublicFileUrl method to construct the full URL
      final String? pdfUrl = apiService.getPublicFileUrl(filePath);
      
      if (pdfUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('URL du fichier PDF invalide')),
          );
        }
        return;
      }
      
      final Uri uri = Uri.parse(pdfUrl);
      
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Impossible d\'ouvrir le fichier PDF')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'ouverture du PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String titleText = (() {
      final name = widget.employeeName?.trim();
      if (name != null && name.isNotEmpty) {
        return 'Certificats médicaux – ' + name;
      }
      return 'Certificats médicaux (téléversés)';
    })();
    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCertificates,
              child: _certificates.isEmpty
                  ? const Center(
                      child: Text('Aucun certificat médical téléversé.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: _certificates.length,
                      itemBuilder: (context, index) {
                        final cert = _certificates[index];
                        return _buildCertificateCard(context, cert, theme);
                      },
                    ),
            ),
    );
  }

  Widget _buildCertificateCard(BuildContext context, UploadedMedicalCertificate cert, ThemeData theme) {
    final dateFmt = DateFormat('dd/MM/yyyy', 'fr_FR');
    final isExpiring = cert.expirationDate?.isBefore(
          DateTime.now().add(const Duration(days: 30)),
        ) ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header compact avec gradient et information employé
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.9),
                    theme.colorScheme.primary,
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Avatar compact avec icône PDF
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.surface.withOpacity(0.3),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.picture_as_pdf_rounded,
                      color: theme.colorScheme.onPrimary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Informations employé
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Nom complet sur une ligne
                        Container(
                          width: double.infinity,
                          child: Text(
                            cert.employeeName?.trim().isNotEmpty == true 
                                ? cert.employeeName! 
                                : 'Employé non identifié',
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: theme.colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Email sur une ligne séparée
                        if (cert.employeeId != null)
                          FutureBuilder<String?>(
                            future: _getEmployeeEmail(cert.employeeId!),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data?.trim().isNotEmpty == true) {
                                return Row(
                                  children: [
                                    Icon(
                                      Icons.email_rounded,
                                      size: 14,
                                      color: theme.colorScheme.onPrimary.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        snapshot.data!,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onPrimary.withOpacity(0.85),
                                          fontWeight: FontWeight.w500,
                                          height: 1.1,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.visible,
                                      ),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bouton PDF compact
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _openPdf(cert.filePath),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.visibility_rounded,
                                color: theme.colorScheme.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'PDF',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Contenu principal compact
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge de statut si expiration proche
                  if (isExpiring) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: theme.colorScheme.error,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Expiration prochaine',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  // Grille d'informations structurée
                  _buildInfoGrid(context, cert, theme, dateFmt),
                  
                  // Section fichier repensée
                  if (cert.filePath?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 16),
                    _buildFileSection(context, cert, theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context, UploadedMedicalCertificate cert, ThemeData theme, DateFormat dateFmt) {
    final infoItems = <Map<String, dynamic>>[
      {
        'icon': Icons.medical_information_rounded,
        'label': 'Type de certificat',
        'value': _getDisplayValue(cert.certificateType, 'Type non renseigné'),
        'color': theme.colorScheme.primary,
      },
      {
        'icon': Icons.event_rounded,
        'label': 'Date de délivrance',
        'value': dateFmt.format(cert.issueDate),
        'color': theme.colorScheme.secondary,
      },
      if (cert.expirationDate != null)
        {
          'icon': Icons.schedule_rounded,
          'label': 'Date d\'expiration',
          'value': dateFmt.format(cert.expirationDate!),
          'color': cert.expirationDate!.isBefore(DateTime.now().add(const Duration(days: 30)))
              ? theme.colorScheme.error
              : theme.colorScheme.tertiary,
          'isWarning': cert.expirationDate!.isBefore(DateTime.now().add(const Duration(days: 30))),
        },
      if (cert.doctorName?.trim().isNotEmpty == true)
        {
          'icon': Icons.person_rounded,
          'label': 'Médecin prescripteur',
          'value': cert.doctorName!.trim(),
          'color': theme.colorScheme.primary,
        },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Titre de section compact
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Informations du certificat',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        
        // Grille d'informations
        ...infoItems.map((item) => _buildModernInfoItem(
          icon: item['icon'] as IconData,
          label: item['label'] as String,
          value: item['value'] as String,
          color: item['color'] as Color,
          theme: theme,
          isWarning: item['isWarning'] as bool? ?? false,
        )),
        
        // Section commentaires séparée si présente
        if (cert.comments?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 12),
          _buildCommentsSection(cert.comments!.trim(), theme),
        ],
      ],
    );
  }

  Widget _buildModernInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required ThemeData theme,
    bool isWarning = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isWarning ? theme.colorScheme.error : theme.colorScheme.onSurface,
                    fontWeight: isWarning ? FontWeight.w600 : FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (isWarning)
            Icon(
              Icons.warning_amber_rounded,
              color: theme.colorScheme.error,
              size: 20,
            ),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(String comments, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.notes_rounded,
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                'Commentaires',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            comments,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSection(BuildContext context, UploadedMedicalCertificate cert, ThemeData theme) {
    final fileName = cert.filePath!.split('/').last;
    final fileExtension = fileName.split('.').last.toUpperCase();
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withOpacity(0.3),
            theme.colorScheme.primaryContainer.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.description_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  fileExtension,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fichier du certificat',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fileName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getDisplayValue(String? value, String fallback) {
    if (value == null || value.trim().isEmpty) {
      return fallback;
    }
    final trimmed = value.trim();
    if (trimmed.toUpperCase() == 'UNKNOWN' || 
        trimmed.toUpperCase() == 'N/A' ||
        trimmed == '-') {
      return fallback;
    }
    return trimmed;
  }

  Future<String?> _getEmployeeEmail(int employeeId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Load all employees if not already cached
      _allEmployees ??= await apiService.getAllEmployees();
      
      // Find employee by ID
      final employee = _allEmployees!.firstWhere(
        (emp) => int.parse(emp.id) == employeeId,
        orElse: () => throw Exception('Employee not found'),
      );
      
      return employee.email;
    } catch (e) {
      return null; // Return null if email can't be fetched
    }
  }
}
