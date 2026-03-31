// ignore_for_file: library_private_types_in_public_api, prefer_const_constructors, prefer_const_literals_to_create_immutables, use_build_context_synchronously, use_key_in_widget_constructors, deprecated_member_use, prefer_const_constructors_in_immutables

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  final int studentId;
  ProfileScreen({required this.studentId});
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isEditMode = false;
  bool _isSaving = false;
  String? _error;
  Map<String, dynamic>? _profileData;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _bloodGroupController = TextEditingController();
  final TextEditingController _parentPhoneController = TextEditingController();
  final TextEditingController _parentEmailController = TextEditingController();

  String? _originalEmail;
  String? _originalPhone;
  String? _originalParentPhone;
  String? _originalParentEmail;

  // ──────────────────────────────────────────────────────────
  // FIX 1: resolve photo URL from whichever field is present
  // ──────────────────────────────────────────────────────────
  String? _resolvePhotoUrl(Map<String, dynamic> profile) {
    // Prefer the pre-built URL if the backend sent it
    final urlField = profile['profile_photo_url'];
    if (urlField != null && urlField.toString().isNotEmpty) {
      return urlField.toString();
    }

    // Fall back to profile_photo and normalise if needed
    final raw = profile['profile_photo'];
    if (raw == null || raw.toString().isEmpty) return null;

    final s = raw.toString();
    if (s.startsWith('http')) return s;

    // Relative path → prepend base
    const base = 'https://lantechschools.org';
    final clean = s.replaceAll(RegExp(r'^/+'), '').replaceAll(RegExp(r'^uploads/'), '');
    return '$base/uploads/$clean';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bloodGroupController.dispose();
    _parentPhoneController.dispose();
    _parentEmailController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim() == _originalEmail) return null;
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) return 'Invalid email format';
    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (value.trim() == _originalPhone) return null;
    final cleanPhone = value.replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (!RegExp(r'^\+?\d+$').hasMatch(cleanPhone)) return 'Phone number can only contain digits';
    if (cleanPhone.length < 10 || cleanPhone.length > 15) return 'Phone number must be 10-15 digits';
    return null;
  }

  Future<void> _loadProfile() async {
    if (!mounted) return;
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final response = await ApiService.getStudentProfile(widget.studentId);
      if (!mounted) return;

      if (response['success'] == true && response['data'] != null) {
        _applyProfileData(response['data']);
        setState(() => _isLoading = false);
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load profile';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Centralised helper — populates _profileData + controllers
  // ─────────────────────────────────────────────────────────────
  void _applyProfileData(Map<String, dynamic> data) {
    _profileData = data;
    _emailController.text       = data['email']        ?? '';
    _phoneController.text       = data['phone']        ?? '';
    _addressController.text     = data['address']      ?? '';
    _bloodGroupController.text  = data['blood_group']  ?? '';
    _parentPhoneController.text = data['parent_phone'] ?? '';
    _parentEmailController.text = data['parent_email'] ?? '';

    _originalEmail       = data['email']        ?? '';
    _originalPhone       = data['phone']        ?? '';
    _originalParentPhone = data['parent_phone'] ?? '';
    _originalParentEmail = data['parent_email'] ?? '';
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty || dateString == 'Not Set') return 'Not Set';
    try {
      final dateOnly = dateString.split('T')[0];
      final parts = dateOnly.split('-');
      final year  = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day   = int.parse(parts[2]);
      const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${months[month]} $day, $year';
    } catch (_) {
      return dateString;
    }
  }

 Future<void> _saveProfile() async {
  if (!mounted) return;

  final emailError       = _validateEmail(_emailController.text.trim());
  final phoneError       = _validatePhone(_phoneController.text.trim());
  final parentPhoneError = _validatePhone(_parentPhoneController.text.trim());
  final parentEmailError = _validateEmail(_parentEmailController.text.trim());

  for (final err in [emailError, phoneError, parentPhoneError, parentEmailError]) {
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $err'), backgroundColor: Colors.red),
      );
      return;
    }
  }

  try {
    setState(() => _isSaving = true);

    final response = await ApiService.updateStudentProfile(
      widget.studentId,
      email:       _emailController.text.trim(),
      phone:       _phoneController.text.trim(),
      address:     _addressController.text.trim(),
      bloodGroup:  _bloodGroupController.text.trim(),
      parentPhone: _parentPhoneController.text.trim(),
      parentEmail: _parentEmailController.text.trim(),
    );

    if (!mounted) return;

    if (response['success'] == true) {
      setState(() => _isEditMode = false);
      
      // ✅ FIX: reload from server so UI always shows latest data
      await _loadProfile();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Profile updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ ${response['message'] ?? 'Update failed'}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('❌ Error: ${e.toString()}'), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) setState(() => _isSaving = false);
  }
}

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6200EE)),
            SizedBox(height: 16),
            Text('Loading profile...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red),
            SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadProfile,
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6200EE)),
            ),
          ],
        ),
      );
    }

    final profile = _profileData ?? {};

    return SizedBox.expand(
      child: Container(
        color: Color(0xFFF5F5F5),
        child: Stack(
          children: [
           RefreshIndicator(
  onRefresh: _loadProfile,
  color: Color(0xFF6200EE),
  child: SingleChildScrollView(
    physics: AlwaysScrollableScrollPhysics(), 
    child: Column(
      children: [
        _buildProfileHeader(profile),
        SizedBox(height: 16),
        _buildStudentInfo(profile),
        SizedBox(height: 12),
        _buildParentInfo(profile),
        SizedBox(height: _isEditMode ? 120 : 80),
      ],
    ),
  ),
),
            // Edit FAB
            if (!_isEditMode && !_isSaving)
              Positioned(
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                child: FloatingActionButton.extended(
                  onPressed: () => setState(() => _isEditMode = true),
                  backgroundColor: Color(0xFF6200EE),
                  icon: Icon(Icons.edit, color: Colors.white),
                  label: Text('Edit Profile', style: TextStyle(color: Colors.white)),
                ),
              ),

            // Save / Cancel bar
            if (_isEditMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.of(context).padding.bottom,
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2))],
                  ),
                  child: SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _isSaving ? null : () {
                              setState(() => _isEditMode = false);
                              // Restore controllers to last saved values (no API call)
                              _emailController.text       = _profileData?['email']        ?? '';
                              _phoneController.text       = _profileData?['phone']        ?? '';
                              _addressController.text     = _profileData?['address']      ?? '';
                              _bloodGroupController.text  = _profileData?['blood_group']  ?? '';
                              _parentPhoneController.text = _profileData?['parent_phone'] ?? '';
                              _parentEmailController.text = _profileData?['parent_email'] ?? '';
                            },
                            icon: Icon(Icons.close),
                            label: Text('Cancel'),
                            style: OutlinedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Icon(Icons.save, color: Colors.white),
                            label: Text(
                              _isSaving ? 'Saving...' : 'Save',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF6200EE),
                              padding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HEADER — uses _resolvePhotoUrl for reliable image display
  // ─────────────────────────────────────────────────────────────
  Widget _buildProfileHeader(Map<String, dynamic> profile) {
    final photoUrl = _resolvePhotoUrl(profile); // ← FIX 1 applied here

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      // Show spinner while loading
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            value: progress.expectedTotalBytes != null
                                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                : null,
                            color: Color(0xFF6200EE),
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('❌ Photo load error: $error  url=$photoUrl');
                        return Icon(Icons.person, size: 60, color: Color(0xFF6200EE));
                      },
                    )
                  : Icon(Icons.person, size: 60, color: Color(0xFF6200EE)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}'.trim(),
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _chip('Class: ${profile['class_name'] ?? 'N/A'}'),
              SizedBox(width: 8),
              _chip('Section: ${profile['section_name'] ?? 'N/A'}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label) => Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
  );

  Widget _buildStudentInfo(Map<String, dynamic> profile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Student Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              SizedBox(height: 16),

              if (!_isEditMode) ...[
                _buildViewField('Name', '${profile['first_name'] ?? ''} ${profile['last_name'] ?? ''}', Icons.person),
                SizedBox(height: 12),
                _buildViewField('Class',       profile['class_name']              ?? 'Not Set', Icons.class_),
                SizedBox(height: 12),
                _buildViewField('Section',     profile['section_name']            ?? 'Not Set', Icons.group),
                SizedBox(height: 12),
                _buildViewField('Roll Number', profile['roll_number']?.toString() ?? 'Not Set', Icons.numbers),
                SizedBox(height: 12),
                _buildViewField('Date of Birth', _formatDate(profile['date_of_birth']), Icons.cake),
                SizedBox(height: 12),
              ],

              if (_isEditMode)
                _buildEditField('Email', _emailController, Icons.email, keyboardType: TextInputType.emailAddress)
              else
                _buildViewField('Email', profile['email'] ?? 'Not Set', Icons.email),
              SizedBox(height: 12),

              if (_isEditMode)
                _buildEditField('Phone', _phoneController, Icons.phone, keyboardType: TextInputType.phone)
              else
                _buildViewField('Phone', profile['phone'] ?? 'Not Set', Icons.phone),
              SizedBox(height: 12),

              if (_isEditMode)
                _buildEditField('Blood Group', _bloodGroupController, Icons.local_hospital)
              else
                _buildViewField('Blood Group', profile['blood_group'] ?? 'Not Set', Icons.local_hospital),
              SizedBox(height: 12),

              if (_isEditMode)
                _buildEditField('Address', _addressController, Icons.home, maxLines: 3)
              else
                _buildViewField('Address', profile['address'] ?? 'Not Set', Icons.home),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParentInfo(Map<String, dynamic> profile) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Parent Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800])),
              SizedBox(height: 16),

              if (!_isEditMode) ...[
                _buildViewField('Father Name', profile['father_name'] ?? 'Not Set', Icons.person_outline),
                SizedBox(height: 12),
                _buildViewField('Mother Name', profile['mother_name'] ?? 'Not Set', Icons.person_outline),
                SizedBox(height: 12),
              ],

              if (_isEditMode)
                _buildEditField('Parent Phone', _parentPhoneController, Icons.phone,
                    keyboardType: TextInputType.phone)
              else
                _buildViewField('Parent Phone', profile['parent_phone'] ?? 'Not Set', Icons.phone),
              SizedBox(height: 12),

              if (_isEditMode)
                _buildEditField('Parent Email', _parentEmailController, Icons.email,
                    keyboardType: TextInputType.emailAddress)
              else
                _buildViewField('Parent Email', profile['parent_email'] ?? 'Not Set', Icons.email),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewField(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF6200EE), size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                SizedBox(height: 4),
                Text(value,
                  style: TextStyle(fontSize: 16, color: Colors.grey[800], fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditField(
    String label,
    TextEditingController controller,
    IconData icon, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: Color(0xFF6200EE)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Color(0xFF6200EE), width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }
}