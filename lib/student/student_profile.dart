// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:kafa_jr_1/auth/login_page.dart';

class StudentProfilePage extends StatefulWidget {
  const StudentProfilePage({super.key});

  @override
  _StudentProfilePageState createState() => _StudentProfilePageState();
}

class _StudentProfilePageState extends State<StudentProfilePage> {
  final DatabaseReference _studentRef = FirebaseDatabase.instance.ref().child('Student'); // Reference to Student table
  final User? _user = FirebaseAuth.instance.currentUser;

  // Add TextEditingControllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _icNumberController = TextEditingController(); // New controller for IC Number
  final TextEditingController _emailController = TextEditingController(); // New controller for Email
  final TextEditingController _currentPasswordController = TextEditingController(); // Controller for current password
  final TextEditingController _newPasswordController = TextEditingController(); // Controller for new password
  final TextEditingController _confirmPasswordController = TextEditingController(); // Controller for confirm password

  final _formKey = GlobalKey<FormState>();

  // Add a boolean to track if the user wants to change their password
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _fetchStudentData();
  }

  Future<void> _fetchStudentData() async {
    if (_user != null) {
      DatabaseEvent event = await _studentRef.child(_user.uid).once();
      DataSnapshot snapshot = event.snapshot; // Access the snapshot from the DatabaseEvent
      if (snapshot.exists) {
        final data = snapshot.value as Map<Object?, Object?>;
        setState(() {
          _fullNameController.text = data['fullName']?.toString() ?? '';
          _icNumberController.text = data['icNumber']?.toString() ?? ''; // Populate IC Number
          _emailController.text = data['email']?.toString() ?? ''; // Populate Email
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      // Prepare data to update for Student table
      Map<String, dynamic> studentUpdates = {
        'fullName': _fullNameController.text,
        'icNumber': _icNumberController.text, // Save IC Number
        'email': _emailController.text, // Save Email
      };

      // Update the Student table
      await _studentRef.child(_user!.uid).update(studentUpdates);

      // Prepare data to update for User table
      Map<String, dynamic> userUpdates = {
        'fullName': _fullNameController.text,
        'email': _emailController.text, // Update email in User table
        'icNumber': _icNumberController.text, // Update IC Number in User table
      };

      // Update the User table
      final DatabaseReference userRef = FirebaseDatabase.instance.ref().child('User');
      await userRef.child(_user.uid).update(userUpdates);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Profile updated successfully!',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            bottom: 20,
            right: 20,
            left: 20,
            top: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Check if password change is needed
      if (_isChangingPassword && _newPasswordController.text.isNotEmpty) {
        if (_currentPasswordController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'Please enter your current password to change it.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(
                bottom: 20,
                right: 20,
                left: 20,
                top: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }

        if (_newPasswordController.text != _confirmPasswordController.text) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'New password and confirm password do not match.',
                style: TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(
                bottom: 20,
                right: 20,
                left: 20,
                top: 20,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          );
          return;
        }
        
        await _changePassword();
      }
    }
  }

  Future<void> _changePassword() async {
    try {
      // Re-authenticate the user
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _currentPasswordController.text,
      );

      // Change the password
      await userCredential.user!.updatePassword(_newPasswordController.text);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Password changed successfully!',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            bottom: 20,
            right: 20,
            left: 20,
            top: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

      // Clear the password fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error changing password: $e',
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            bottom: 20,
            right: 20,
            left: 20,
            top: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  void _logout() async {
    await FirebaseAuth.instance.signOut();
    // Navigate to login page or perform any other action after logout
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const LoginPage()), // Adjust the route as needed
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pinkAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.pinkAccent, Colors.white],
            stops: [0.0, 0.3],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      spreadRadius: 2,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInputField(
                        title: 'Full Name',
                        controller: _fullNameController,
                        icon: Icons.person_outline,
                      ),
                      _buildInputField(
                        title: 'Identity Card Number',
                        controller: _icNumberController,
                        icon: Icons.assignment_ind,
                      ),
                      _buildInputField(
                        title: 'Email',
                        controller: _emailController,
                        icon: Icons.email_outlined,
                      ),
                      
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Switch(
                            value: _isChangingPassword,
                            onChanged: (value) {
                              setState(() {
                                _isChangingPassword = value;
                              });
                            },
                            activeColor: Colors.pinkAccent,
                          ),
                        ],
                      ),

                      if (_isChangingPassword) ...[
                        _buildInputField(
                          title: 'Current Password',
                          controller: _currentPasswordController,
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        _buildInputField(
                          title: 'New Password',
                          controller: _newPasswordController,
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        _buildInputField(
                          title: 'Confirm New Password',
                          controller: _confirmPasswordController,
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                      ],

                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: _saveProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String title,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 15),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.pinkAccent),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: Colors.pinkAccent),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
          ),
          validator: (value) => value!.isEmpty ? 'This field is required' : null,
        ),
      ],
    );
  }
}