import 'package:flutter/material.dart';
import 'package:orocloud/pages/login_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/auth_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:orocloud/utils/image_helper.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  String? _userEmail;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);

    // Get basic user info
    final email = _authService.getUserEmail();

    // Get additional user profile from the database
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      try {
        final userRecord =
            await Supabase.instance.client
                .from('users')
                .select('*')
                .eq('id', userId)
                .single();

        setState(() {
          _userEmail = email;
          _userProfile = userRecord;
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _userEmail = email;
          _isLoading = false;
        });
      }
    } else {
      setState(() {
        _userEmail = email;
        _isLoading = false;
      });
    }
  }

  Future<void> _changeProfilePicture() async {
    setState(() => _isLoading = true);

    try {
      // Use our helper method
      final File? croppedImageFile = await ImageHelper.pickAndCropImage(
        square: true,
        title: 'Crop Profile Picture',
      );

      // If user cancelled or cropping failed, just return
      if (croppedImageFile == null) {
        setState(() => _isLoading = false);
        return;
      }

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // CHANGED: Update path structure to comply with RLS policies
      final String filePath = "$userId/profile_pictures/profile.jpg";

      // Upload the file to Supabase Storage
      await Supabase.instance.client.storage
          .from('user_files')
          .uploadBinary(
            filePath,
            await croppedImageFile.readAsBytes(),
            fileOptions: FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      // Get the public URL
      final String publicUrl = Supabase.instance.client.storage
          .from('user_files')
          .getPublicUrl(filePath);

      // Update the user's profile in the database
      await Supabase.instance.client
          .from('users')
          .update({'profile_picture': publicUrl})
          .eq('id', userId);

      // Show success message and refresh data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        await _loadUserData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile picture: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<File?> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile != null) {
      return File(pickedFile.path);
    }

    return null;
  }

  Future<File?> _cropImage(File imageFile) async {
    CroppedFile? croppedFile = await ImageCropper().cropImage(
      sourcePath: imageFile.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 80,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Picture',
          toolbarColor: Colors.blue,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop Profile Picture',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );

    if (croppedFile != null) {
      return File(croppedFile.path);
    }

    return null;
  }

  Future<String?> _uploadProfilePicture(File imageFile) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Define the file path in storage - use consistent path for overwriting
      final String filePath = "profile_pictures/$userId/profile.jpg";

      // Upload the file to Supabase Storage
      await Supabase.instance.client.storage
          .from('user_files')
          .uploadBinary(
            filePath,
            await imageFile.readAsBytes(),
            fileOptions: FileOptions(
              contentType: 'image/jpeg',
              upsert: true, // This ensures it will overwrite any existing file
            ),
          );

      // Get the public URL
      final String publicUrl = Supabase.instance.client.storage
          .from('user_files')
          .getPublicUrl(filePath);

      // Update the user's profile in the database
      await Supabase.instance.client
          .from('users')
          .update({'profile_picture': publicUrl})
          .eq('id', userId);

      return publicUrl;
    } catch (e) {
      print('Error uploading profile picture: $e');
      throw e;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              await _authService.signOut();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (_) => false,
                );
              }
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    // Profile avatar
                    GestureDetector(
                      onTap: _changeProfilePicture,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.blue,
                            backgroundImage:
                                _userProfile != null &&
                                        _userProfile!['profile_picture'] != null
                                    ? NetworkImage(
                                      _userProfile!['profile_picture'],
                                    )
                                    : null,
                            child:
                                _userProfile != null &&
                                        _userProfile!['profile_picture'] != null
                                    ? null
                                    : const Icon(
                                      Icons.person,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              padding: const EdgeInsets.all(4),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // User email
                    if (_userEmail != null)
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              const Icon(Icons.email, color: Colors.blue),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Email',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _userEmail!,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // User storage info
                    if (_userProfile != null)
                      Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.storage, color: Colors.blue),
                                  const SizedBox(width: 16),
                                  const Expanded(
                                    child: Text(
                                      'Storage Used',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              LinearProgressIndicator(
                                value:
                                    (_userProfile!['storage_used'] ?? 0) /
                                    1000000000, // 1GB max
                                backgroundColor: Colors.grey[200],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${((_userProfile!['storage_used'] ?? 0) / 1000000).toStringAsFixed(2)} MB used of 1 GB',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/document_scanner_page');
                      },
                      child: const Text('Go to Document Scanner'),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      onPressed: () async {
                        await _authService.signOut();
                        if (mounted) {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LoginPage(),
                            ),
                            (_) => false,
                          );
                        }
                      },
                      child: const Text('Sign Out'),
                    ),
                  ],
                ),
              ),
    );
  }
}
