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
  String _searchQuery = "";

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

  // Add this method to filter files based on navigation selection and search query
  List<DriveFile> _getFilteredFiles() {
    // Start with filtering by tab (Starred or All files)
    List<DriveFile> filteredFiles =
        _selectedNavIndex == 1
            ? files.where((file) => file.isStarred).toList()
            : List.from(files);

    // Apply search filter if query exists
    if (_searchQuery.isNotEmpty) {
      filteredFiles =
          filteredFiles
              .where(
                (file) => file.title.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
              )
              .toList();
    }

    return filteredFiles;
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

  void _toggleStar(int index) async {
    if (files[index].id == null) {
      showMessage("Cannot update file: ID not found", Colors.redAccent);
      return;
    }

    // Toggle the starred state locally for immediate feedback
    final bool newStarredState = !files[index].isStarred;

    // Update local state first for responsive UI
    setState(() {
      files[index] = DriveFile(
        id: files[index].id,
        icon: files[index].icon,
        iconColor: files[index].iconColor,
        title: files[index].title,
        date: files[index].date,
        size: files[index].size,
        directoryName: files[index].directoryName,
        directoryId: files[index].directoryId,
        previewUrl: files[index].previewUrl,
        isStarred: newStarredState,
      );
    });

    try {
      // Update the file's starred state in the database
      await FileUploadService.FileUploadService.updateFileStarred(
        files[index].id!,
        newStarredState,
      );

      // Show success message
      showMessage(
        newStarredState ? "Added to starred" : "Removed from starred",
        Colors.green,
      );
    } catch (e) {
      // Revert the local state if the update fails
      setState(() {
        files[index] = DriveFile(
          id: files[index].id,
          icon: files[index].icon,
          iconColor: files[index].iconColor,
          title: files[index].title,
          date: files[index].date,
          size: files[index].size,
          directoryName: files[index].directoryName,
          directoryId: files[index].directoryId,
          previewUrl: files[index].previewUrl,
          isStarred: !newStarredState,
        );
      });

      showMessage(
        "Failed to update star status: ${e.toString()}",
        Colors.redAccent,
      );
    }
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

  void _confirmDeleteFile(DriveFile file) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete File'),
          content: Text(
            'Are you sure you want to delete "${file.title}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog

                // Show loading indicator
                setState(() {
                  _isLoading = true;
                });

                try {
                  await FileUploadService.FileUploadService.deleteFile(
                    file.id!,
                  );

                  // Remove file from UI
                  setState(() {
                    files.removeWhere((f) => f.id == file.id);
                    _selectedFile = null; // Close preview
                  });

                  showMessage("File deleted successfully", Colors.green);
                } catch (e) {
                  showMessage(
                    "Failed to delete file: ${e.toString()}",
                    Colors.redAccent,
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _handleFileRename(DriveFile file) {
    // Extract the file name and extension
    final String fileName = file.title;
    final int lastDotIndex = fileName.lastIndexOf('.');
    final String fileExtension =
        lastDotIndex != -1 ? fileName.substring(lastDotIndex) : '';
    final String nameWithoutExtension =
        lastDotIndex != -1 ? fileName.substring(0, lastDotIndex) : fileName;

    // Create a controller with the current name (without extension)
    final TextEditingController nameController = TextEditingController(
      text: nameWithoutExtension,
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final bool isDarkMode =
            MediaQuery.of(context).platformBrightness == Brightness.dark;
        final Color textColor =
            isDarkMode ? const Color.fromARGB(221, 92, 92, 92) : Colors.black87;

        return AlertDialog(
          title: const Text('Rename File'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'File name',
              hintText: 'Enter new file name',
              suffixText: fileExtension,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                // Get the new name
                final String newName = nameController.text.trim();
                if (newName.isEmpty) {
                  showMessage("File name cannot be empty", Colors.redAccent);
                  return;
                }

                // Close dialog
                Navigator.of(context).pop();

                // Show loading indicator
                setState(() {
                  _isLoading = true;
                });

                try {
                  // Create the full new name with extension
                  final String fullNewName = '$newName$fileExtension';

                  // Rename the file
                  await FileUploadService.FileUploadService.renameFile(
                    file.id!,
                    fullNewName,
                  );

                  // Update the file in the UI
                  final int fileIndex = files.indexWhere(
                    (f) => f.id == file.id,
                  );
                  if (fileIndex != -1) {
                    setState(() {
                      files[fileIndex] = DriveFile(
                        id: file.id,
                        icon: file.icon,
                        iconColor: file.iconColor,
                        title: fullNewName,
                        date: file.date,
                        size: file.size,
                        directoryName: file.directoryName,
                        directoryId: file.directoryId,
                        previewUrl: file.previewUrl,
                        isStarred: file.isStarred,
                      );

                      // Update the selected file if it's the one being renamed
                      if (_selectedFile?.id == file.id) {
                        _selectedFile = files[fileIndex];
                      }
                    });

                    showMessage("File renamed successfully", Colors.green);
                  }
                } catch (e) {
                  showMessage(
                    "Failed to rename file: ${e.toString()}",
                    Colors.redAccent,
                  );
                } finally {
                  setState(() {
                    _isLoading = false;
                  });
                }
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );
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
                  // Integrated App Bar with search bar and menu button - always shown
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
                        // Search bar or Title based on selected tab
                        Expanded(
                          child:
                              _selectedNavIndex == 2
                                  ? Center(
                                    child: Text(
                                      "Profile",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  )
                                  : Focus(
                                    onFocusChange: (hasFocus) {
                                      setState(() {});
                                    },
                                    child: TextField(
                                      controller: _searchController,
                                      onChanged: (value) {
                                        setState(() {
                                          _searchQuery = value;
                                        });
                                      },
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
                                        // Add clear button when there's text
                                        suffixIcon:
                                            _searchQuery.isNotEmpty
                                                ? IconButton(
                                                  icon: Icon(
                                                    Icons.clear,
                                                    color: hintColor,
                                                  ),
                                                  onPressed: () {
                                                    setState(() {
                                                      _searchController.clear();
                                                      _searchQuery = "";
                                                    });
                                                  },
                                                )
                                                : null,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Colors.blue,
                                            width: 2,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            30,
                                          ),
                                          borderSide: BorderSide(
                                            color: Colors.grey.withOpacity(0.2),
                                            width: 1,
                                          ),
                                        ),
                                        filled: false,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
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

                  // Main content area - conditionally show different content
                  Expanded(
                    child:
                        _selectedNavIndex == 2
                            // Profile page content
                            ? _buildProfileContent(
                              isDarkMode: isDarkMode,
                              backgroundColor: backgroundColor,
                              cardColor: cardColor,
                              textColor: textColor,
                            )
                            // Files view (Files or Starred tabs)
                            : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0,
                                  ),
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
                                    _selectedNavIndex == 1
                                        ? "Starred Files"
                                        : "Files",
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
                                          : _getFilteredFiles().isEmpty
                                          ? Center(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  _selectedNavIndex == 1
                                                      ? Icons.star_border
                                                      : Icons.folder_open,
                                                  size: 64,
                                                  color:
                                                      isDarkMode
                                                          ? Colors.grey[600]
                                                          : Colors.grey[400],
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  _selectedNavIndex == 1
                                                      ? "No starred files"
                                                      : "No files found",
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    color:
                                                        isDarkMode
                                                            ? Colors.grey[400]
                                                            : Colors.grey[600],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                          : ListView.builder(
                                            physics:
                                                const BouncingScrollPhysics(),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16.0,
                                              vertical: 10.0,
                                            ),
                                            itemCount:
                                                _getFilteredFiles().length,
                                            itemBuilder: (context, index) {
                                              return GestureDetector(
                                                onTap:
                                                    () => _selectFile(
                                                      _getFilteredFiles()[index],
                                                    ),
                                                child: _buildFileItem(
                                                  file:
                                                      _getFilteredFiles()[index],
                                                  onStarToggle:
                                                      () => _toggleStar(
                                                        files.indexOf(
                                                          _getFilteredFiles()[index],
                                                        ),
                                                      ),
                                                  isSelected:
                                                      _selectedFile ==
                                                      _getFilteredFiles()[index],
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
                        onTap:
                            () => setState(() {
                              _selectedNavIndex = 0;
                              _selectedFile =
                                  null; // Clear selected file when changing tabs
                            }),
                        child: _buildBottomNavItem(
                          icon: Icons.description,
                          label: "Files",
                          isSelected: _selectedNavIndex == 0,
                        ),
                      ),
                      GestureDetector(
                        onTap:
                            () => setState(() {
                              _selectedNavIndex = 1;
                              _selectedFile =
                                  null; // Clear selected file when changing tabs
                            }),
                        child: _buildBottomNavItem(
                          icon: Icons.star_border,
                          label: "Starred",
                          isSelected: _selectedNavIndex == 1,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _selectedNavIndex = 2),
                        child: _buildBottomNavItem(
                          icon: Icons.person,
                          label: "Profile",
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
                  onTap: () => _handleFileRename(file),
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
                  onTap: () {
                    _confirmDeleteFile(file);
                  },
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

  Widget _buildProfileContent({
    required bool isDarkMode,
    required Color backgroundColor,
    required Color cardColor,
    required Color textColor,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final userProfile = snapshot.data;
          final userId = Supabase.instance.client.auth.currentUser?.id;
          final userEmail =
              Supabase.instance.client.auth.currentUser?.email ?? "No email";

          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              const SizedBox(height: 16),
              // Profile avatar
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, size: 50, color: Colors.white),
              ),
              const SizedBox(height: 24),

              // User email
              Card(
                color: cardColor,
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
                              userEmail,
                              style: TextStyle(fontSize: 16, color: textColor),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // User storage info
              if (userProfile != null)
                Card(
                  color: cardColor,
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
                            Expanded(
                              child: Text(
                                'Storage Used',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value:
                              (userProfile['used_space'] ?? 0) /
                              (userProfile['total_space'] ?? 10737418240),
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${FileUploadService.FileUploadService.formatFileSize(userProfile['used_space'] ?? 0)} used of ${FileUploadService.FileUploadService.formatFileSize(userProfile['total_space'] ?? 10737418240)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Account Info
              Card(
                color: cardColor,
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.account_circle, color: Colors.blue),
                          const SizedBox(width: 16),
                          Text(
                            'Account',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.security,
                          color: Colors.orange,
                        ),
                        title: Text(
                          'Security',
                          style: TextStyle(color: textColor),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.settings, color: Colors.grey),
                        title: Text(
                          'Settings',
                          style: TextStyle(color: textColor),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.help_outline,
                          color: Colors.blue,
                        ),
                        title: Text(
                          'Help & Support',
                          style: TextStyle(color: textColor),
                        ),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey,
                        ),
                        onTap: () {},
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.logout, color: Colors.red),
                        title: Text(
                          'Log Out',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () => _handleLogout(context),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>?> _getUserProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return null;

      final response =
          await Supabase.instance.client
              .from('users')
              .select('*')
              .eq('id', userId)
              .single();

      return response;
    } catch (e) {
      debugPrint("Error loading profile: $e");
      return null;
    }
  }
}
