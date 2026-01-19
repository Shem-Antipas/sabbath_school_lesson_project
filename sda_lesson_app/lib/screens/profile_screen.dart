import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart'; // ✅ Required for local saving

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _currentUser;
  bool _isLoading = false;
  final TextEditingController _nameController = TextEditingController();
  
  // Image Logic
  final ImagePicker _picker = ImagePicker();
  File? _localImageFile; // Stores the custom image locally

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _nameController.text = _currentUser?.displayName ?? "";
    _loadLocalImage(); // ✅ Load saved image on startup
  }

  // ---------------------------------------------------------------------------
  // ✅ 1. LOAD SAVED IMAGE FROM PHONE STORAGE
  // ---------------------------------------------------------------------------
  Future<void> _loadLocalImage() async {
    if (_currentUser == null) return;
    
    final prefs = await SharedPreferences.getInstance();
    // Unique key for this user so multiple users don't share photos
    final String key = 'profile_pic_${_currentUser!.uid}';
    final String? path = prefs.getString(key);

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        setState(() {
          _localImageFile = file;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // ✅ 2. PICK & SAVE IMAGE LOCALLY
  // ---------------------------------------------------------------------------
  Future<void> _pickAndSaveImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 50 // Compress to save space
      );
      
      if (pickedFile == null) return;

      setState(() => _isLoading = true);

      // 1. Get the app's private documents directory
      final directory = await getApplicationDocumentsDirectory();
      
      // 2. Create a unique path for this user
      final String newPath = '${directory.path}/profile_${_currentUser!.uid}.jpg';
      
      // 3. Copy the picked image to permanent storage
      final File savedImage = await File(pickedFile.path).copy(newPath);

      // 4. Save the path to Shared Preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_pic_${_currentUser!.uid}', newPath);

      // 5. Update UI
      setState(() {
        _localImageFile = savedImage;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Profile picture updated!"), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving image: $e")));
      }
    }
  }

  // --- NAME UPDATE LOGIC (Same as before) ---
  Future<void> _updateName() async {
    final newName = _nameController.text.trim();
    if (newName.isEmpty) return;
    setState(() => _isLoading = true);
    
    try {
      await _currentUser?.updateDisplayName(newName);
      await _currentUser?.reload(); 
      _finalizeUpdate("Name updated successfully!");
    } catch (e) {
      final errorString = e.toString();
      if (errorString.contains("Pigeon") || errorString.contains("List<Object?>")) {
        _finalizeUpdate("Name updated successfully!");
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _finalizeUpdate(String message) {
    if (!mounted) return;
    setState(() { _currentUser = FirebaseAuth.instance.currentUser; });
    if (Navigator.canPop(context)) Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  void _showEditNameDialog() {
    _nameController.text = _currentUser?.displayName ?? "";
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Edit Name"),
        content: TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Display Name", border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: _updateName, child: const Text("Save")),
        ],
      ),
    );
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Signed out successfully")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF06275C);
    
    // Fallback logic for name
    String displayName = "User";
    if (_nameController.text.isNotEmpty) {
      displayName = _nameController.text;
    } else if (_currentUser?.displayName != null && _currentUser!.displayName!.isNotEmpty) {
      displayName = _currentUser!.displayName!;
    } else if (_currentUser?.email != null) {
      displayName = "User"; // Fallback
    }

    final email = _currentUser?.email ?? "No Email";
    final googlePhotoUrl = _currentUser?.photoURL;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: Text("My Profile", style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: _currentUser == null
                  ? const Text("Not logged in")
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // -----------------------------------------------------
                        // ✅ AVATAR LOGIC (Priority: Local > Google > Initials)
                        // -----------------------------------------------------
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.grey[300],
                              // 1. Try Local File
                              backgroundImage: _localImageFile != null 
                                  ? FileImage(_localImageFile!) 
                                  // 2. Try Google Photo
                                  : (googlePhotoUrl != null ? NetworkImage(googlePhotoUrl) : null) as ImageProvider?,
                              child: (_localImageFile == null && googlePhotoUrl == null)
                                  ? Text(
                                      displayName.isNotEmpty ? displayName[0].toUpperCase() : "U",
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickAndSaveImage, // ✅ Triggers local save
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).primaryColor,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.camera_alt, size: 20, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // --- NAME & VERIFIED ---
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(child: Text(displayName, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis)),
                            const SizedBox(width: 8),
                            if (_currentUser!.emailVerified) const Icon(Icons.verified, color: Colors.blue, size: 20) else const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                            const SizedBox(width: 8),
                            IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.grey), onPressed: _showEditNameDialog),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        Text(email, style: TextStyle(fontSize: 16, color: Colors.grey[600])),

                        if (!_currentUser!.emailVerified) ...[
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () async {
                              await _currentUser!.sendEmailVerification();
                              if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Email sent!")));
                            },
                            icon: const Icon(Icons.mail_outline, size: 18, color: Colors.orange),
                            label: const Text("Verify Email Now", style: TextStyle(color: Colors.orange)),
                          ),
                        ],

                        const SizedBox(height: 40),
                        ElevatedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout),
                          label: const Text("Sign Out"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                        ),
                      ],
                    ),
            ),
    );
  }
}