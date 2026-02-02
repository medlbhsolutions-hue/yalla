import 'package:flutter/material.dart';import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/auth_service.dart';import '../professional_main_screen.dart';

import '../professional/professional_main_screen.dart';

class ProfessionalAuthScreen extends ConsumerStatefulWidget {

class ProfessionalAuthScreen extends ConsumerStatefulWidget {  const ProfessionalAuthScreen({super.key});

  const ProfessionalAuthScreen({super.key});

  @override

  @override  ConsumerState<ProfessionalAuthScreen> createState() =>

  ConsumerState<ProfessionalAuthScreen> createState() => _ProfessionalAuthScreenState();      _ProfessionalAuthScreenState();

}}



class _ProfessionalAuthScreenState extends ConsumerState<ProfessionalAuthScreen> {class _ProfessionalAuthScreenState

  final _formKey = GlobalKey<FormState>();    extends ConsumerState<ProfessionalAuthScreen> {

  final _emailController = TextEditingController();  final _formKey = GlobalKey<FormState>();

  final _passwordController = TextEditingController();  final _emailController = TextEditingController();

  final _nameController = TextEditingController();  final _passwordController = TextEditingController();

  final _phoneController = TextEditingController();  final _nameController = TextEditingController();

  final _specialtyController = TextEditingController();  final _phoneController = TextEditingController();

  final _licenseController = TextEditingController();  final _specialtyController = TextEditingController();

  final _licenseController = TextEditingController();

  bool _isLogin = true;

  bool _isLoading = false;  bool _isLogin = true;

  bool _obscurePassword = true;  bool _isLoading = false;

  String _selectedSpecialty = 'Médecin généraliste';  bool _obscurePassword = true;

  String _selectedSpecialty = 'Médecin généraliste';

  final List<String> _specialties = [

    'Médecin généraliste',  final List<String> _specialties = [

    'Cardiologue',    'Médecin généraliste',

    'Dermatologue',    'Cardiologue',

    'Gynécologue',    'Dermatologue',

    'Pédiatre',    'Gynécologue',

    'Psychiatre',    'Pédiatre',

    'Chirurgien',    'Neurologue',

    'Ophtalmologue',    'Orthopédiste',

    'ORL',    'Ophtalmologue',

    'Dentiste',    'ORL',

  ];    'Psychiatre',

    'Endocrinologue',

  @override    'Gastro-entérologue',

  void dispose() {    'Pneumologue',

    _emailController.dispose();    'Rhumatologue',

    _passwordController.dispose();    'Urologue',

    _nameController.dispose();    'Radiologue',

    _phoneController.dispose();    'Anesthésiste',

    _specialtyController.dispose();    'Chirurgien',

    _licenseController.dispose();    'Dentiste',

    super.dispose();    'Pharmacien',

  }    'Infirmier(e)',

    'Kinésithérapeute',

  Future<void> _handleAuth() async {    'Psychologue',

    if (!_formKey.currentState!.validate()) return;    'Sage-femme',

  ];

    setState(() => _isLoading = true);

  @override

    try {  Widget build(BuildContext context) {

      final authService = AuthService();    return Scaffold(

      backgroundColor: Colors.white,

      if (_isLogin) {      appBar: AppBar(

        // Connexion professionnel        backgroundColor: Colors.transparent,

        final response = await authService.signIn(        elevation: 0,

          email: _emailController.text.trim(),        leading: IconButton(

          password: _passwordController.text,          icon: const Icon(Icons.arrow_back, color: Colors.black87),

        );          onPressed: () => Navigator.pop(context),

        ),

        if (response['success'] && mounted) {      ),

          final userData = response['user'];      body: SafeArea(

          if (userData['user_type'] == 'professional') {        child: SingleChildScrollView(

            Navigator.of(context).pushReplacement(          padding: const EdgeInsets.all(24.0),

              MaterialPageRoute(builder: (context) => const ProfessionalMainScreen()),          child: Form(

            );            key: _formKey,

          } else {            child: Column(

            _showError('Ce compte n\'est pas un compte professionnel');              crossAxisAlignment: CrossAxisAlignment.start,

          }              children: [

        }                const SizedBox(height: 20),

      } else {

        // Inscription professionnel                // Titre et sous-titre

        final response = await authService.signUp(                Text(

          email: _emailController.text.trim(),                  _isLogin ? 'Espace Professionnel' : 'Rejoignez-nous',

          password: _passwordController.text,                  style: const TextStyle(

          name: _nameController.text.trim(),                    fontSize: 28,

          phone: _phoneController.text.trim(),                    fontWeight: FontWeight.bold,

          userType: 'professional',                    color: Color(0xFF2E7D32),

        );                  ),

                ),

        if (response['success'] && mounted) {

          // Créer le profil professionnel                const SizedBox(height: 8),

          await _createProfessionalProfile(

            userId: response['user_id'],                Text(

            specialty: _selectedSpecialty,                  _isLogin

            licenseNumber: _licenseController.text.trim(),                      ? 'Connectez-vous à votre espace professionnel'

          );                      : 'Créez votre compte professionnel de santé',

                  style: const TextStyle(fontSize: 16, color: Colors.grey),

          ScaffoldMessenger.of(context).showSnackBar(                ),

            const SnackBar(

              content: Text('Compte créé avec succès. En attente de validation.'),                const SizedBox(height: 40),

              backgroundColor: Colors.green,

            ),                // Champs du formulaire

          );                if (!_isLogin) ...[

                  _buildInputField(

          // Retourner à l'écran de connexion                    controller: _nameController,

          setState(() => _isLogin = true);                    label: 'Nom complet',

        }                    icon: Icons.person_outline,

      }                    validator: (value) {

    } catch (e) {                      if (value == null || value.isEmpty) {

      _showError(e.toString());                        return 'Veuillez entrer votre nom';

    } finally {                      }

      if (mounted) {                      return null;

        setState(() => _isLoading = false);                    },

      }                  ),

    }                  const SizedBox(height: 20),

  }

                  // Sélecteur de spécialité

  Future<void> _createProfessionalProfile({                  DropdownButtonFormField<String>(

    required String userId,                    initialValue: _selectedSpecialty,

    required String specialty,                    decoration: InputDecoration(

    required String licenseNumber,                      labelText: 'Spécialité',

  }) async {                      prefixIcon: const Icon(

    try {                        Icons.medical_services,

      await SupabaseConfig.client.from('professionals').insert({                        color: Color(0xFF2E7D32),

        'user_id': userId,                      ),

        'specialty': specialty,                      border: OutlineInputBorder(

        'license_number': licenseNumber,                        borderRadius: BorderRadius.circular(12),

        'status': 'pending',                        borderSide: BorderSide(color: Colors.grey.shade300),

        'verified': false,                      ),

      });                      enabledBorder: OutlineInputBorder(

    } catch (e) {                        borderRadius: BorderRadius.circular(12),

      throw 'Erreur création profil professionnel: $e';                        borderSide: BorderSide(color: Colors.grey.shade300),

    }                      ),

  }                      focusedBorder: OutlineInputBorder(

                        borderRadius: BorderRadius.circular(12),

  void _showError(String message) {                        borderSide: const BorderSide(

    ScaffoldMessenger.of(context).showSnackBar(                          color: Color(0xFF2E7D32),

      SnackBar(                          width: 2,

        content: Text(message),                        ),

        backgroundColor: Colors.red,                      ),

      ),                      filled: true,

    );                      fillColor: Colors.grey.shade50,

  }                    ),

                    items: _specialties.map((String specialty) {

  @override                      return DropdownMenuItem<String>(

  Widget build(BuildContext context) {                        value: specialty,

    return Scaffold(                        child: Text(specialty),

      backgroundColor: Colors.white,                      );

      body: SafeArea(                    }).toList(),

        child: SingleChildScrollView(                    onChanged: (String? newValue) {

          padding: const EdgeInsets.all(24.0),                      setState(() {

          child: Form(                        _selectedSpecialty = newValue!;

            key: _formKey,                      });

            child: Column(                    },

              crossAxisAlignment: CrossAxisAlignment.stretch,                    validator: (value) {

              children: [                      if (value == null || value.isEmpty) {

                const SizedBox(height: 40),                        return 'Veuillez sélectionner une spécialité';

                      }

                // Logo et titre                      return null;

                Center(                    },

                  child: Column(                  ),

                    children: [                  const SizedBox(height: 20),

                      Container(

                        width: 100,                  _buildInputField(

                        height: 100,                    controller: _licenseController,

                        decoration: BoxDecoration(                    label: 'Numéro de licence professionnelle',

                          color: const Color(0xFF4CAF50).withOpacity(0.1),                    icon: Icons.badge_outlined,

                          shape: BoxShape.circle,                    validator: (value) {

                        ),                      if (value == null || value.isEmpty) {

                        child: const Icon(                        return 'Veuillez entrer votre numéro de licence';

                          Icons.medical_services,                      }

                          size: 50,                      return null;

                          color: Color(0xFF4CAF50),                    },

                        ),                  ),

                      ),                  const SizedBox(height: 20),

                      const SizedBox(height: 20),

                      Text(                  _buildInputField(

                        _isLogin ? 'Connexion Professionnel' : 'Inscription Professionnel',                    controller: _phoneController,

                        style: const TextStyle(                    label: 'Numéro de téléphone',

                          fontSize: 24,                    icon: Icons.phone_outlined,

                          fontWeight: FontWeight.bold,                    keyboardType: TextInputType.phone,

                          color: Color(0xFF333333),                    validator: (value) {

                        ),                      if (value == null || value.isEmpty) {

                      ),                        return 'Veuillez entrer votre numéro de téléphone';

                    ],                      }

                  ),                      return null;

                ),                    },

                  ),

                const SizedBox(height: 40),                  const SizedBox(height: 20),

                ],

                // Champs du formulaire

                if (!_isLogin) ...[                _buildInputField(

                  _buildTextField(                  controller: _emailController,

                    controller: _nameController,                  label: 'Email professionnel',

                    label: 'Nom complet',                  icon: Icons.email_outlined,

                    icon: Icons.person_outline,                  keyboardType: TextInputType.emailAddress,

                    validator: (value) {                  validator: (value) {

                      if (value == null || value.isEmpty) {                    if (value == null || value.isEmpty) {

                        return 'Veuillez entrer votre nom';                      return 'Veuillez entrer votre email';

                      }                    }

                      return null;                    if (!RegExp(

                    },                      r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',

                  ),                    ).hasMatch(value)) {

                  const SizedBox(height: 16),                      return 'Email invalide';

                  _buildTextField(                    }

                    controller: _phoneController,                    return null;

                    label: 'Téléphone',                  },

                    icon: Icons.phone_outlined,                ),

                    keyboardType: TextInputType.phone,

                    validator: (value) {                const SizedBox(height: 20),

                      if (value == null || value.isEmpty) {

                        return 'Veuillez entrer votre numéro de téléphone';                _buildInputField(

                      }                  controller: _passwordController,

                      return null;                  label: 'Mot de passe',

                    },                  icon: Icons.lock_outline,

                  ),                  obscureText: _obscurePassword,

                  const SizedBox(height: 16),                  suffixIcon: IconButton(

                  // Spécialité                    icon: Icon(

                  DropdownButtonFormField<String>(                      _obscurePassword

                    value: _selectedSpecialty,                          ? Icons.visibility

                    decoration: InputDecoration(                          : Icons.visibility_off,

                      labelText: 'Spécialité',                      color: Colors.grey,

                      border: OutlineInputBorder(                    ),

                        borderRadius: BorderRadius.circular(12),                    onPressed: () {

                      ),                      setState(() {

                      prefixIcon: const Icon(Icons.medical_services_outlined),                        _obscurePassword = !_obscurePassword;

                    ),                      });

                    items: _specialties.map((String value) {                    },

                      return DropdownMenuItem<String>(                  ),

                        value: value,                  validator: (value) {

                        child: Text(value),                    if (value == null || value.isEmpty) {

                      );                      return 'Veuillez entrer votre mot de passe';

                    }).toList(),                    }

                    onChanged: (String? newValue) {                    if (!_isLogin && value.length < 6) {

                      if (newValue != null) {                      return 'Le mot de passe doit contenir au moins 6 caractères';

                        setState(() {                    }

                          _selectedSpecialty = newValue;                    return null;

                        });                  },

                      }                ),

                    },

                  ),                if (!_isLogin) ...[

                  const SizedBox(height: 16),                  const SizedBox(height: 20),

                  _buildTextField(                  // Note de vérification

                    controller: _licenseController,                  Container(

                    label: 'Numéro de licence',                    padding: const EdgeInsets.all(16),

                    icon: Icons.badge_outlined,                    decoration: BoxDecoration(

                    validator: (value) {                      color: Colors.orange.shade50,

                      if (value == null || value.isEmpty) {                      borderRadius: BorderRadius.circular(12),

                        return 'Veuillez entrer votre numéro de licence';                      border: Border.all(color: Colors.orange.shade200),

                      }                    ),

                      return null;                    child: Row(

                    },                      children: [

                  ),                        Icon(Icons.info_outline, color: Colors.orange.shade700),

                  const SizedBox(height: 16),                        const SizedBox(width: 12),

                ],                        Expanded(

                          child: Text(

                _buildTextField(                            'Votre compte sera vérifié par notre équipe avant activation.',

                  controller: _emailController,                            style: TextStyle(

                  label: 'Email professionnel',                              color: Colors.orange.shade700,

                  icon: Icons.email_outlined,                              fontSize: 14,

                  keyboardType: TextInputType.emailAddress,                            ),

                  validator: (value) {                          ),

                    if (value == null || value.isEmpty) {                        ),

                      return 'Veuillez entrer votre email';                      ],

                    }                    ),

                    if (!value.contains('@')) {                  ),

                      return 'Veuillez entrer un email valide';                ],

                    }

                    return null;                const SizedBox(height: 32),

                  },

                ),                // Bouton principal

                SizedBox(

                const SizedBox(height: 16),                  width: double.infinity,

                  height: 56,

                _buildTextField(                  child: ElevatedButton(

                  controller: _passwordController,                    onPressed: _isLoading ? null : _submitForm,

                  label: 'Mot de passe',                    style: ElevatedButton.styleFrom(

                  icon: Icons.lock_outline,                      backgroundColor: const Color(0xFF2E7D32),

                  obscureText: _obscurePassword,                      foregroundColor: Colors.white,

                  isPassword: true,                      shape: RoundedRectangleBorder(

                  onTogglePassword: () => setState(() => _obscurePassword = !_obscurePassword),                        borderRadius: BorderRadius.circular(16),

                  validator: (value) {                      ),

                    if (value == null || value.isEmpty) {                      elevation: 0,

                      return 'Veuillez entrer votre mot de passe';                    ),

                    }                    child: _isLoading

                    if (!_isLogin && value.length < 6) {                        ? const SizedBox(

                      return 'Le mot de passe doit contenir au moins 6 caractères';                            width: 24,

                    }                            height: 24,

                    return null;                            child: CircularProgressIndicator(

                  },                              color: Colors.white,

                ),                              strokeWidth: 2,

                            ),

                const SizedBox(height: 24),                          )

                        : Text(

                // Bouton principal                            _isLogin ? 'Se connecter' : 'Créer mon compte',

                SizedBox(                            style: const TextStyle(

                  height: 50,                              fontSize: 18,

                  child: ElevatedButton(                              fontWeight: FontWeight.bold,

                    onPressed: _isLoading ? null : _handleAuth,                            ),

                    style: ElevatedButton.styleFrom(                          ),

                      backgroundColor: const Color(0xFF4CAF50),                  ),

                      shape: RoundedRectangleBorder(                ),

                        borderRadius: BorderRadius.circular(25),

                      ),                const SizedBox(height: 24),

                    ),

                    child: _isLoading                // Lien pour changer de mode

                        ? const CircularProgressIndicator(color: Colors.white)                Center(

                        : Text(                  child: TextButton(

                            _isLogin ? 'Se connecter' : 'S\'inscrire',                    onPressed: () {

                            style: const TextStyle(                      setState(() {

                              fontSize: 16,                        _isLogin = !_isLogin;

                              color: Colors.white,                        _clearForm();

                            ),                      });

                          ),                    },

                  ),                    child: RichText(

                ),                      text: TextSpan(

                        text: _isLogin

                const SizedBox(height: 20),                            ? 'Pas encore de compte ? '

                            : 'Déjà un compte ? ',

                // Switch Login/Register                        style: const TextStyle(

                Row(                          color: Colors.grey,

                  mainAxisAlignment: MainAxisAlignment.center,                          fontSize: 16,

                  children: [                        ),

                    Text(                        children: [

                      _isLogin                          TextSpan(

                          ? 'Vous n\'avez pas de compte ? '                            text: _isLogin ? 'S\'inscrire' : 'Se connecter',

                          : 'Vous avez déjà un compte ? ',                            style: const TextStyle(

                      style: TextStyle(color: Colors.grey[600]),                              color: Color(0xFF2E7D32),

                    ),                              fontWeight: FontWeight.bold,

                    GestureDetector(                            ),

                      onTap: () => setState(() => _isLogin = !_isLogin),                          ),

                      child: Text(                        ],

                        _isLogin ? 'S\'inscrire' : 'Se connecter',                      ),

                        style: const TextStyle(                    ),

                          color: Color(0xFF4CAF50),                  ),

                          fontWeight: FontWeight.bold,                ),

                        ),

                      ),                if (_isLogin) ...[

                    ),                  const SizedBox(height: 16),

                  ],                  Center(

                ),                    child: TextButton(

              ],                      onPressed: () {

            ),                        // TODO: Implémenter mot de passe oublié

          ),                        ScaffoldMessenger.of(context).showSnackBar(

        ),                          const SnackBar(

      ),                            content: Text(

    );                              'Fonctionnalité en cours de développement',

  }                            ),

                          ),

  Widget _buildTextField({                        );

    required TextEditingController controller,                      },

    required String label,                      child: const Text(

    required IconData icon,                        'Mot de passe oublié ?',

    bool obscureText = false,                        style: TextStyle(color: Colors.grey, fontSize: 14),

    bool isPassword = false,                      ),

    VoidCallback? onTogglePassword,                    ),

    TextInputType? keyboardType,                  ),

    String? Function(String?)? validator,                ],

  }) {              ],

    return TextFormField(            ),

      controller: controller,          ),

      obscureText: obscureText,        ),

      keyboardType: keyboardType,      ),

      validator: validator,    );

      decoration: InputDecoration(  }

        labelText: label,

        prefixIcon: Icon(icon, color: const Color(0xFF4CAF50)),  Widget _buildInputField({

        suffixIcon: isPassword && onTogglePassword != null    required TextEditingController controller,

            ? IconButton(    required String label,

                icon: Icon(    required IconData icon,

                  obscureText ? Icons.visibility : Icons.visibility_off,    bool obscureText = false,

                  color: Colors.grey,    TextInputType? keyboardType,

                ),    Widget? suffixIcon,

                onPressed: onTogglePassword,    String? Function(String?)? validator,

              )  }) {

            : null,    return TextFormField(

        border: OutlineInputBorder(      controller: controller,

          borderRadius: BorderRadius.circular(12),      obscureText: obscureText,

          borderSide: BorderSide(color: Colors.grey[300]!),      keyboardType: keyboardType,

        ),      validator: validator,

        focusedBorder: OutlineInputBorder(      decoration: InputDecoration(

          borderRadius: BorderRadius.circular(12),        labelText: label,

          borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2),        prefixIcon: Icon(icon, color: const Color(0xFF2E7D32)),

        ),        suffixIcon: suffixIcon,

        filled: true,        border: OutlineInputBorder(

        fillColor: Colors.grey[50],          borderRadius: BorderRadius.circular(12),

      ),          borderSide: BorderSide(color: Colors.grey.shade300),

    );        ),

  }        enabledBorder: OutlineInputBorder(

}          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2E7D32), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
    );
  }

  void _clearForm() {
    _emailController.clear();
    _passwordController.clear();
    _nameController.clear();
    _phoneController.clear();
    _specialtyController.clear();
    _licenseController.clear();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // TODO: Implémenter l'authentification avec AuthService
      await Future.delayed(const Duration(seconds: 2)); // Simulation

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const ProfessionalMainScreen(),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _licenseController.dispose();
    super.dispose();
  }
}
