import 'package:flutter/material.dart';
import 'package:oshapp/shared/services/api_service.dart';
import 'package:oshapp/shared/models/employee.dart';
import 'package:oshapp/shared/models/employee_creation_request_dto.dart';
import 'package:provider/provider.dart';

class CreateEmployeeScreen extends StatefulWidget {
  const CreateEmployeeScreen({super.key});

  @override
  State<CreateEmployeeScreen> createState() => _CreateEmployeeScreenState();
}

class _CreateEmployeeScreenState extends State<CreateEmployeeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _positionController = TextEditingController();
  final _departmentController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cinController = TextEditingController();
  final _cnssController = TextEditingController();
  final _birthPlaceController = TextEditingController();
  final _nationalityController = TextEditingController();
  final _cityController = TextEditingController();
  final _zipCodeController = TextEditingController();
  final _countryController = TextEditingController();
  DateTime? _hireDate;
  DateTime? _birthDate;
  String? _gender; // HOMME | FEMME

  Employee? _selectedManager1;
  Employee? _selectedManager2;
  List<Employee> _availableEmployees = [];
  final List<String> _selectedRoles = ['ROLE_EMPLOYEE'];
  bool _isLoading = false;

  final List<String> _availableRoles = [
    'ROLE_ADMIN',
    'ROLE_RH',
    'ROLE_NURSE',
    'ROLE_DOCTOR',
    'ROLE_HSE',
    'ROLE_EMPLOYEE'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAvailableEmployees();
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _positionController.dispose();
    _departmentController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cinController.dispose();
    _cnssController.dispose();
    _birthPlaceController.dispose();
    _nationalityController.dispose();
    _cityController.dispose();
    _zipCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableEmployees() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final employees = await apiService.getAllEmployees();
      if (mounted) {
        setState(() {
          _availableEmployees = employees;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load employees: $e')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      try {
        final apiService = Provider.of<ApiService>(context, listen: false);

        // Check email uniqueness before creating the user
        final email = _emailController.text.trim();
        final exists = await apiService.checkEmailExists(email);
        if (exists) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cet email est déjà utilisé')),
            );
          }
          return;
        }

        // 1) Create the User account first
        final createdUser = await apiService.createUser(
          email,
          _passwordController.text.trim(),
          _selectedRoles,
        );

        final int? userId = int.tryParse(createdUser.id);
        if (userId == null) {
          throw Exception('Failed to parse created user id');
        }

        // 2) Create the complete Employee profile
        final int? m1 = _parseEmployeeId(_selectedManager1);
        final int? m2 = _parseEmployeeId(_selectedManager2);
        if (m1 != null && m2 != null && m1 == m2) {
          throw Exception('Les managers N+1 et N+2 ne peuvent pas être identiques');
        }

        final dto = EmployeeCreationRequestDTO(
          userId: userId,
          email: _emailController.text.trim(),
          firstName: _firstNameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          position: _positionController.text.trim(),
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
          manager1Id: m1,
          manager2Id: m2,
          gender: _gender,
        );

        await apiService.createCompleteEmployee(dto);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Employee created successfully!')),
          );
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create employee: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Employee'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Section Compte Utilisateur
              _buildSectionHeader('Informations de Connexion', Icons.account_circle),
              const SizedBox(height: 16),
              _buildEmailField(),
              const SizedBox(height: 16),
              _buildPasswordField(),
              const SizedBox(height: 16),
              _buildRolesSection(),
              
              const SizedBox(height: 32),
              
              // Section Informations Personnelles
              _buildSectionHeader('Informations Personnelles', Icons.person),
              const SizedBox(height: 16),
              _buildFirstNameField(),
              const SizedBox(height: 16),
              _buildLastNameField(),
              const SizedBox(height: 16),
              _buildGenderField(),
              const SizedBox(height: 16),
              _buildBirthDateField(),
              const SizedBox(height: 16),
              _buildBirthPlaceField(),
              const SizedBox(height: 16),
              _buildNationalityField(),
              const SizedBox(height: 16),
              _buildCinField(),
              const SizedBox(height: 16),
              _buildCnssField(),
              const SizedBox(height: 16),
              _buildSectionHeader('Informations Professionnelles', Icons.work_outline),
              const SizedBox(height: 16),
              _buildPositionField(),
              const SizedBox(height: 16),
              _buildDepartmentField(),
              const SizedBox(height: 16),
              _buildHireDateField(),

              const SizedBox(height: 32),

              _buildSectionHeader('Contact & Adresse', Icons.home_outlined),
              const SizedBox(height: 16),
              _buildPhoneField(),
              const SizedBox(height: 16),
              _buildAddressField(),
              const SizedBox(height: 16),
              _buildCityField(),
              const SizedBox(height: 16),
              _buildZipField(),
              const SizedBox(height: 16),
              _buildCountryField(),
              
              const SizedBox(height: 32),
              
              // Section Hiérarchie
              _buildSectionHeader('Hiérarchie', Icons.account_tree),
              const SizedBox(height: 16),
              _buildManagerSelection(),
              
              const SizedBox(height: 32),
              
              // Bouton de création
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF8B4A6B)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B4A6B),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: const InputDecoration(
        labelText: 'Email *',
        hintText: 'prenom.nom@entreprise.com',
        prefixIcon: Icon(Icons.email),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'L\'email est obligatoire';
        }
        if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
          return 'Format d\'email invalide';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: const InputDecoration(
        labelText: 'Mot de passe *',
        hintText: 'Mot de passe sécurisé (8+ caractères)',
        prefixIcon: Icon(Icons.lock),
        border: OutlineInputBorder(),
      ),
      obscureText: true,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le mot de passe est obligatoire';
        }
        if (value.length < 6) {
          return 'Le mot de passe doit contenir au moins 6 caractères';
        }
        return null;
      },
    );
  }

  Widget _buildFirstNameField() {
    return TextFormField(
      controller: _firstNameController,
      decoration: const InputDecoration(
        labelText: 'Prénom *',
        hintText: 'Ex: Jean',
        prefixIcon: Icon(Icons.person),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le prénom est obligatoire';
        }
        return null;
      },
    );
  }

  Widget _buildLastNameField() {
    return TextFormField(
      controller: _lastNameController,
      decoration: const InputDecoration(
        labelText: 'Nom *',
        hintText: 'Ex: Dupont',
        prefixIcon: Icon(Icons.person_outline),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le nom est obligatoire';
        }
        return null;
      },
    );
  }

  Widget _buildGenderField() {
    return DropdownButtonFormField<String>(
      decoration: const InputDecoration(
        labelText: 'Sexe',
        prefixIcon: Icon(Icons.wc),
        border: OutlineInputBorder(),
      ),
      value: _gender,
      items: const [
        DropdownMenuItem<String>(value: 'HOMME', child: Text('Homme')),
        DropdownMenuItem<String>(value: 'FEMME', child: Text('Femme')),
      ],
      onChanged: _isLoading
          ? null
          : (String? value) {
              setState(() => _gender = value);
            },
    );
  }

  Widget _buildPositionField() {
    return TextFormField(
      controller: _positionController,
      decoration: const InputDecoration(
        labelText: 'Poste *',
        hintText: 'Ex: Développeur, Comptable...',
        prefixIcon: Icon(Icons.work),
        border: OutlineInputBorder(),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Le poste est obligatoire';
        }
        return null;
      },
    );
  }

  Widget _buildDepartmentField() {
    return TextFormField(
      controller: _departmentController,
      decoration: const InputDecoration(
        labelText: 'Département',
        hintText: 'Ex: Informatique, Finance... ',
        prefixIcon: Icon(Icons.apartment_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneController,
      decoration: const InputDecoration(
        labelText: 'Téléphone',
        hintText: '+212 6XX XX XX XX',
        prefixIcon: Icon(Icons.phone),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildAddressField() {
    return TextFormField(
      controller: _addressController,
      decoration: const InputDecoration(
        labelText: 'Adresse',
        hintText: 'Rue, quartier...',
        prefixIcon: Icon(Icons.location_on_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildCityField() {
    return TextFormField(
      controller: _cityController,
      decoration: const InputDecoration(
        labelText: 'Ville',
        prefixIcon: Icon(Icons.location_city_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildZipField() {
    return TextFormField(
      controller: _zipCodeController,
      decoration: const InputDecoration(
        labelText: 'Code postal',
        prefixIcon: Icon(Icons.local_post_office_outlined),
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildCountryField() {
    return TextFormField(
      controller: _countryController,
      decoration: const InputDecoration(
        labelText: 'Pays',
        prefixIcon: Icon(Icons.public),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildCinField() {
    return TextFormField(
      controller: _cinController,
      decoration: const InputDecoration(
        labelText: 'CIN',
        prefixIcon: Icon(Icons.badge_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildCnssField() {
    return TextFormField(
      controller: _cnssController,
      decoration: const InputDecoration(
        labelText: 'CNSS',
        prefixIcon: Icon(Icons.confirmation_num_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildBirthPlaceField() {
    return TextFormField(
      controller: _birthPlaceController,
      decoration: const InputDecoration(
        labelText: 'Lieu de naissance',
        prefixIcon: Icon(Icons.place_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildNationalityField() {
    return TextFormField(
      controller: _nationalityController,
      decoration: const InputDecoration(
        labelText: 'Nationalité',
        prefixIcon: Icon(Icons.flag_outlined),
        border: OutlineInputBorder(),
      ),
    );
  }

  String _fmtDate(DateTime? d) {
    if (d == null) return '';
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '$y-$m-$dd';
  }

  Widget _buildBirthDateField() {
    return InkWell(
      onTap: _isLoading
          ? null
          : () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
                firstDate: DateTime(1950, 1, 1),
                lastDate: DateTime(now.year, now.month, now.day),
              );
              if (picked != null) {
                setState(() => _birthDate = picked);
              }
            },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date de naissance',
          prefixIcon: Icon(Icons.cake_outlined),
          border: OutlineInputBorder(),
        ),
        child: Text(_birthDate == null ? 'Sélectionner' : _fmtDate(_birthDate)),
      ),
    );
  }

  Widget _buildHireDateField() {
    return InkWell(
      onTap: _isLoading
          ? null
          : () async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: _hireDate ?? now,
                firstDate: DateTime(1950, 1, 1),
                lastDate: DateTime(now.year, now.month, now.day),
              );
              if (picked != null) {
                setState(() => _hireDate = picked);
              }
            },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: "Date d'embauche",
          prefixIcon: Icon(Icons.event_outlined),
          border: OutlineInputBorder(),
        ),
        child: Text(_hireDate == null ? 'Sélectionner' : _fmtDate(_hireDate)),
      ),
    );
  }

  int? _parseEmployeeId(Employee? e) {
    if (e == null) return null;
    return int.tryParse(e.id);
  }

  Widget _buildRolesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rôles *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: _availableRoles.map((role) {
            final isSelected = _selectedRoles.contains(role);
            return FilterChip(
              label: Text(role.replaceAll('ROLE_', '')),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedRoles.add(role);
                  } else {
                    _selectedRoles.remove(role);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildManagerSelection() {
    return Column(
      children: [
        // Manager N+1
        DropdownButtonFormField<Employee>(
          decoration: const InputDecoration(
            labelText: 'Manager N+1 (Supérieur direct)',
            prefixIcon: Icon(Icons.supervisor_account),
            border: OutlineInputBorder(),
          ),
          value: _selectedManager1,
          items: _availableEmployees.map((employee) {
            return DropdownMenuItem<Employee>(
              value: employee,
              child: Text('${employee.firstName} ${employee.lastName}'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedManager1 = value;
            });
          },
        ),
        const SizedBox(height: 16),
        
        // Manager N+2
        DropdownButtonFormField<Employee>(
          decoration: const InputDecoration(
            labelText: 'Manager N+2 (Supérieur hiérarchique)',
            prefixIcon: Icon(Icons.account_tree),
            border: OutlineInputBorder(),
          ),
          value: _selectedManager2,
          items: _availableEmployees.map((employee) {
            return DropdownMenuItem<Employee>(
              value: employee,
              child: Text('${employee.firstName} ${employee.lastName}'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedManager2 = value;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCreateButton() {
    return ElevatedButton(
      onPressed: _isLoading ? null : _submitForm,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF8B4A6B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
              'Créer l\'Employé',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
    );
  }
}
