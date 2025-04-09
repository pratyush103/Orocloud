import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:orocloud/models/drive_file.dart'; // Import DriveFile model
import 'package:orocloud/pages/image_viewer_screen.dart';
import 'package:orocloud/pages/pdf_viewer_screen.dart';
import 'package:orocloud/services/file_upload_service.dart'
    as FileUploadService;
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Orocloud Drive',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFFF1F3F4),
      ),
      initialRoute: '/drive',
      routes: {
        '/': (context) => const HomePage(),
        '/drive': (context) => const DrivePage(),
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color backgroundColor =
        isDarkMode ? const Color(0xFF2E2E2E) : Colors.grey[50]!;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(title: const Text('Home'), elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.cloud, size: 40, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              "Orocloud",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            Text(
              "Secure cloud storage for everyone",
              style: TextStyle(
                fontSize: 14,
                color: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 200,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/drive');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                  shadowColor: Colors.blue.withOpacity(0.3),
                ),
                child: const Text(
                  'Open Drive',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DrivePage extends StatefulWidget {
  const DrivePage({super.key});

  @override
  State<DrivePage> createState() => _DrivePageState();
}

class _DrivePageState extends State<DrivePage> {
  final List<DriveFile> files = [];

  void _handleFileView(DriveFile file) {
    final fileExtension = file.title.split('.').last.toLowerCase();

    if (['jpg', 'jpeg', 'png', 'gif'].contains(fileExtension)) {
      // Handle image files
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ImageViewerScreen(imageUrl: file.previewUrl!),
        ),
      );
    } else if (fileExtension == 'pdf') {
      // Handle PDF files
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PDFViewerScreen(pdfUrl: file.previewUrl!),
        ),
      );
    } else {
      // Handle unsupported file types
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('This file type is not supported for viewing'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchUploadedFiles() async {
    setState(() => _isLoading = true);

    try {
      // Get current user ID
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Fetch both directories and files belonging to the user
      final directories = await Supabase.instance.client
          .from('directories')
          .select('id, name, parent_id, created_at')
          .eq('user_id', userId)
          .order('name');

      // Create a map for quick directory lookups
      Map<String, Map<String, dynamic>> directoryMap = {};
      for (var dir in directories) {
        directoryMap[dir['id']] = dir;
      }

      // Fetch files with directory information
      final response = await Supabase.instance.client
          .from('files')
          .select('*, directories(name)')
          .eq('user_id', userId)
          .order('modified_at', ascending: false);

      List<DriveFile> fetchedFiles =
          response.map<DriveFile>((file) {
            // Get directory name or "Unknown" if not found
            String directoryName = "Unknown";
            if (file['directories'] != null) {
              directoryName = file['directories']['name'] as String;
            }

            // Format date for display
            String formattedDate = "Unknown date";
            if (file['modified_at'] != null) {
              DateTime modifiedDate = DateTime.parse(
                file['modified_at'] as String,
              );
              final now = DateTime.now();
              final difference = now.difference(modifiedDate);

              if (difference.inDays == 0) {
                formattedDate = "Today";
              } else if (difference.inDays == 1) {
                formattedDate = "Yesterday";
              } else if (difference.inDays < 7) {
                formattedDate = "${difference.inDays} days ago";
              } else {
                formattedDate =
                    "${modifiedDate.day}/${modifiedDate.month}/${modifiedDate.year}";
              }
            }

            // Calculate file size for display
            String fileSize = "Unknown";
            if (file['size'] != null) {
              final sizeInBytes = file['size'] as int;
              if (sizeInBytes < 1024) {
                fileSize = "$sizeInBytes B";
              } else if (sizeInBytes < 1024 * 1024) {
                fileSize = "${(sizeInBytes / 1024).toStringAsFixed(1)} KB";
              } else if (sizeInBytes < 1024 * 1024 * 1024) {
                fileSize =
                    "${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB";
              } else {
                fileSize =
                    "${(sizeInBytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
              }
            }

            return DriveFile(
              id: file['id'] as String,
              icon: Icons.insert_drive_file, // Use a default icon for now
              iconColor: FileUploadService.FileUploadService.getFileIconColor(
                file['file_type'] as String? ?? '',
              ),
              title: file['name'] as String,
              date: formattedDate,
              previewUrl: file['shared_link'] as String?,
              size: fileSize,
              directoryName: directoryName,
              directoryId: file['directory_id'] as String?,
              isStarred: file['starred'] as bool? ?? false,
            );
          }).toList();

      setState(() {
        files.clear();
        files.addAll(fetchedFiles);
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _isLoading = false;
      });
      showMessage(
        "Error loading files: ${e.toString()}: $stackTrace",
        Colors.redAccent,
      );
      debugPrint('Stack trace: $stackTrace  ${e.toString()}');
    }
  }

  final TextEditingController _searchController = TextEditingController();
  bool _showUploadMenu = false;
  int _selectedNavIndex = 0;
  DriveFile? _selectedFile;
  bool _isLoading = false;
  String? _message;
  Color? _messageColor;
  bool _showMenu = false;

  @override
  void initState() {
    super.initState();
    _fetchUploadedFiles(); // Fetch files from Supabase on load
  }

  void _handleFileUpload() async {
    try {
      // Pick file using FilePicker
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        File selectedFile = File(result.files.single.path!);

        // Upload the file
        DriveFile? newFile = await FileUploadService
            .FileUploadService.uploadFile(selectedFile);

        if (newFile != null) {
          showMessage("File uploaded successfully", Colors.green);

          // Refresh file list after upload
          await _fetchUploadedFiles();
        }
      }
    } catch (e, stacktrace) {
      showMessage("Error: ${e.toString()}", Colors.redAccent);
      debugPrint("Error: $e \n StackTrace: $stacktrace");
    }
  }

  void _toggleUploadMenu() {
    setState(() {
      _showUploadMenu = !_showUploadMenu;
    });
  }

  void _selectFile(DriveFile file) {
    setState(() {
      _selectedFile = file;
    });
  }

  void _toggleStar(int index) {
    setState(() {
      files[index] = DriveFile(
        icon: files[index].icon,
        iconColor: files[index].iconColor,
        title: files[index].title,
        date: files[index].date,
        isStarred: !files[index].isStarred,
      );
    });
  }

  void showMessage(String message, Color color) {
    setState(() {
      _message = message;
      _messageColor = color;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _message = null;
        });
      }
    });
  }

  void _handleLogout(BuildContext context) async {
    // Close the menu
    setState(() {
      _showMenu = false;
    });

    // Show a loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => const Center(
            child: CircularProgressIndicator(color: Colors.blue),
          ),
    );

    try {
      // Sign out from Supabase
      await Supabase.instance.client.auth.signOut();

      // Close the loading dialog
      Navigator.pop(context);

      // Navigate to the login page or home page
      Navigator.pushReplacementNamed(context, '/');

      // Show success message
      showMessage("Logged out successfully", Colors.green);
    } catch (e, stacktrace) {
      // Close the loading dialog
      Navigator.pop(context);

      // Show error message
      showMessage("Failed to logout: ${e.toString()}", Colors.redAccent);
      debugPrint("Error: $e \n StackTrace: $stacktrace");
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDarkMode =
        MediaQuery.of(context).platformBrightness == Brightness.dark;
    final Color backgroundColor =
        isDarkMode ? const Color(0xFF2E2E2E) : const Color(0xFFF1F3F4);
    final Color cardColor = isDarkMode ? Colors.grey[800]! : Colors.white;
    final Color textColor = isDarkMode ? Colors.white : Colors.black87;
    final Color hintColor = isDarkMode ? Colors.grey[300]! : Colors.grey[700]!;

    return GestureDetector(
      // ✅ Dismiss keyboard when tapping outside
      onTap: () {
        FocusScope.of(context).unfocus(); // ✅ Remove focus from search bar
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Integrated App Bar with search bar and menu button
                  Container(
                    height: 70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16.0,
                      vertical: 12.0,
                    ),
                    decoration: BoxDecoration(
                      color: cardColor,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Menu button
                        Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(30),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(30),
                            onTap: () {
                              setState(() {
                                _showMenu = !_showMenu;
                              });
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              child: Icon(
                                Icons.menu,
                                color: textColor,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                        // Search bar takes remaining space
                        Expanded(
                          child: Focus(
                            onFocusChange: (hasFocus) {
                              // Force a rebuild when focus changes
                              setState(
                                () {},
                              ); // ✅ Ensure UI updates when focused
                            },
                            child: TextField(
                              controller: _searchController,
                              cursorColor: Colors.blue,
                              cursorWidth: 2,
                              cursorRadius: const Radius.circular(2),
                              decoration: InputDecoration(
                                hintText: "Search in Orocloud",
                                hintStyle: TextStyle(
                                  color:
                                      isDarkMode
                                          ? Colors.white70
                                          : Colors.black54,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: hintColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: const BorderSide(
                                    color: Colors.blue,
                                    width: 2,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide(
                                    color: Colors.grey.withOpacity(0.2),
                                    width: 1,
                                  ),
                                ),
                                filled: false,
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Message display
                  if (_message != null)
                    Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _messageColor!.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _messageColor == Colors.redAccent
                                ? Icons.error
                                : Icons.check_circle,
                            color: _messageColor,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _message!,
                              style: TextStyle(color: textColor),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Quick Access
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 8.0,
                    ),
                    child: Text(
                      "Quick Access",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),

                  // Quick Access Buttons
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickAccessButton(
                            icon: Icons.access_time,
                            label: "Recent files",
                            isDarkMode: isDarkMode,
                            cardColor: cardColor,
                            textColor: textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickAccessButton(
                            icon: Icons.folder_shared,
                            label: "Shared with me",
                            isDarkMode: isDarkMode,
                            cardColor: cardColor,
                            textColor: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildQuickAccessButton(
                            icon: Icons.star,
                            label: "Starred",
                            isDarkMode: isDarkMode,
                            cardColor: cardColor,
                            textColor: textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildQuickAccessButton(
                            icon: Icons.cloud_download,
                            label: "Offline files",
                            isDarkMode: isDarkMode,
                            cardColor: cardColor,
                            textColor: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Files Section
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20.0,
                      vertical: 16.0,
                    ),
                    child: Text(
                      "Files",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                      ),
                    ),
                  ),

                  // File List - FIXED SCROLLING SECTION
                  Expanded(
                    child:
                        _isLoading
                            ? const Center(
                              child: CircularProgressIndicator(
                                color: Colors.blue,
                              ),
                            )
                            : files.isEmpty
                            ? const Center(child: Text(""))
                            : ListView.builder(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 10.0,
                              ),
                              itemCount: files.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: () => _selectFile(files[index]),
                                  child: _buildFileItem(
                                    file: files[index],
                                    onStarToggle: () => _toggleStar(index),
                                    isSelected: _selectedFile == files[index],
                                    isDarkMode: isDarkMode,
                                    cardColor: cardColor,
                                    textColor: textColor,
                                  ),
                                );
                              },
                            ),
                  ),
                ],
              ),

              // File Preview (visible by default)
              if (_selectedFile != null)
                Positioned(
                  top: 100,
                  left: 40,
                  right: 40,
                  child: _buildFilePreview(
                    _selectedFile!,
                    isDarkMode: isDarkMode,
                    cardColor: cardColor,
                    textColor: textColor,
                  ),
                ),

              // Menu (only visible when menu button is clicked)
              // Menu (only visible when menu button is clicked)
              if (_showMenu)
                Positioned(
                  top: 70, // Position it just below the app bar
                  left: 16,
                  child: Container(
                    width: 150,
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: () {
                        // Handle logout action
                        _handleLogout(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: hintColor),
                            const SizedBox(width: 12),
                            Text("Logout", style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              if (_showUploadMenu)
                Positioned(
                  bottom: 120,
                  right: 20,
                  child: Container(
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          // Add InkWell for tap functionality
                          onTap: () {
                            _handleFileUpload();
                            _toggleUploadMenu(); // Close menu after selection
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.upload_file, color: hintColor),
                                const SizedBox(width: 16),
                                Text(
                                  "Upload from device",
                                  style: TextStyle(color: textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                        InkWell(
                          // Add InkWell for tap functionality
                          onTap: () {
                            // Handle scan to PDF action
                            _toggleUploadMenu(); // Close menu after selection
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.photo_camera, color: hintColor),
                                const SizedBox(width: 16),
                                Text(
                                  "Scan to PDF",
                                  style: TextStyle(color: textColor),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // FAB
              Positioned(
                bottom: 70,
                right: 20,
                child: FloatingActionButton(
                  onPressed:
                      _toggleUploadMenu, // Change this to toggle the menu
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 5,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),

              // Bottom Navigation
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 60,
                  decoration: BoxDecoration(
                    color: cardColor,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, -1),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedNavIndex = 0),
                        child: _buildBottomNavItem(
                          icon: Icons.description,
                          label: "Files",
                          isSelected: _selectedNavIndex == 0,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedNavIndex = 1),
                        child: _buildBottomNavItem(
                          icon: Icons.star_border,
                          label: "Starred",
                          isSelected: _selectedNavIndex == 1,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedNavIndex = 2),
                        child: _buildBottomNavItem(
                          icon: Icons.share,
                          label: "Shared",
                          isSelected: _selectedNavIndex == 2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilePreview(
    DriveFile file, {
    required bool isDarkMode,
    required Color cardColor,
    required Color textColor,
  }) {
    // Determine the preview content based on file type
    Widget previewContent;

    if (file.icon == Icons.image) {
      // Image preview
      previewContent = Column(
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[300],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Icon(Icons.image, size: 64, color: file.iconColor),
            ),
          ),
        ],
      );
    } else if (file.icon == Icons.folder) {
      // Folder preview
      previewContent = Column(
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.grey[700] : Colors.grey[200],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Icon(Icons.folder_open, size: 64, color: file.iconColor),
            ),
          ),
        ],
      );
    } else {
      // Document preview
      previewContent = Column(
        children: [
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(file.icon, size: 48, color: file.iconColor),
                  const SizedBox(height: 8),
                  Text(
                    file.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Lorem ipsum dolor sit amet, consectetur adipiscing elit.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.grey[300] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview title bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(file.icon, color: file.iconColor, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    file.title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20, color: textColor),
                  onPressed: () {
                    setState(() {
                      _selectedFile = null;
                    });
                  },
                ),
              ],
            ),
          ),

          // Preview content
          previewContent,

          // Preview actions
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildPreviewAction(
                  Icons.remove_red_eye,
                  "View",
                  textColor: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
                  onTap: () {
                    if (_selectedFile?.previewUrl != null) {
                      _handleFileView(_selectedFile!);
                    } else {
                      showMessage(
                        "Preview URL not available for this file",
                        Colors.redAccent,
                      );
                    }
                  },
                ),
                _buildPreviewAction(
                  Icons.edit,
                  "Edit",
                  textColor: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
                ),
                _buildPreviewAction(
                  Icons.share,
                  "Share",
                  textColor: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
                  onTap: () {
                    if (file.previewUrl != null) {
                      Share.share(
                        'Check out this file from Orocloud: ${file.previewUrl}',
                        subject: 'Sharing "${file.title}" from Orocloud',
                      );
                    } else {
                      showMessage(
                        "This file doesn't have a valid sharing URL",
                        Colors.redAccent,
                      );
                    }
                  },
                ),
                _buildPreviewAction(
                  Icons.delete_outline,
                  "Delete",
                  textColor: isDarkMode ? Colors.grey[300]! : Colors.grey[700]!,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewAction(
    IconData icon,
    String label, {
    required Color textColor,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: textColor, size: 20),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 12, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildQuickAccessButton({
    required IconData icon,
    required String label,
    required bool isDarkMode,
    required Color cardColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: isDarkMode ? Colors.grey[400] : Colors.grey[700]),
          const SizedBox(height: 8),
          Text(label, style: TextStyle(fontSize: 14, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildFileItem({
    required DriveFile file,
    required VoidCallback onStarToggle,
    required bool isDarkMode,
    required Color cardColor,
    required Color textColor,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10.0),
      decoration: BoxDecoration(
        color:
            isSelected
                ? Colors.blue.withOpacity(isDarkMode ? 0.2 : 0.05)
                : cardColor,
        borderRadius: BorderRadius.circular(10.0),
        border:
            isSelected
                ? Border.all(color: Colors.blue.withOpacity(0.5), width: 1.5)
                : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(file.icon, color: file.iconColor, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        file.date,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDarkMode ? Colors.grey[400] : Colors.grey[700],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (file.size != null)
                        Text(
                          "• ${file.size}",
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                        ),
                      const SizedBox(width: 8),
                      if (file.directoryName != null)
                        Text(
                          "• ${file.directoryName}",
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[700],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (file.isStarred)
              IconButton(
                icon: const Icon(Icons.star, color: Colors.amber, size: 22),
                onPressed: onStarToggle,
              )
            else
              IconButton(
                icon: Icon(
                  Icons.star_border,
                  color: isDarkMode ? Colors.grey[400] : Colors.grey,
                  size: 22,
                ),
                onPressed: onStarToggle,
              ),
            Icon(
              Icons.more_vert,
              color: isDarkMode ? Colors.grey[400] : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    bool isSelected = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: isSelected ? Colors.blue : Colors.grey, size: 24),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.blue : Colors.grey,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}
