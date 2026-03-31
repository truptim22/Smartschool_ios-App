/*import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_filex/open_filex.dart';

class DownloadService {
  static Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      // For Android 13+ (API 33+), we don't need storage permissions
      if (Platform.version.contains('SDK 33') || 
          Platform.version.contains('SDK 34')) {
        print('✅ Android 13+: No storage permission needed');
        return true;
      }

      // For Android 11-12 (API 30-32)
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        status = await Permission.storage.request();
      }

      if (!status.isGranted) {
        final manageStatus = await Permission.manageExternalStorage.request();
        return manageStatus.isGranted;
      }

      return status.isGranted;
    }
    return true;
  }

  // ✅ NEW HELPER: Generate unique filename if file exists
  static String _getUniqueFilename(Directory directory, String fileName) {
    final basePath = directory.path;
    File file = File('$basePath/$fileName');
    
    // If file doesn't exist, return original name
    if (!file.existsSync()) {
      return fileName;
    }

    // Extract name and extension
    final lastDot = fileName.lastIndexOf('.');
    final name = lastDot != -1 ? fileName.substring(0, lastDot) : fileName;
    final extension = lastDot != -1 ? fileName.substring(lastDot) : '';

    // Try appending (1), (2), (3) until we find a unique name
    int counter = 1;
    while (true) {
      final newFileName = '$name ($counter)$extension';
      file = File('$basePath/$newFileName');
      
      if (!file.existsSync()) {
        print('📝 Generated unique filename: $newFileName');
        return newFileName;
      }
      counter++;
    }
  }

  static Future<String?> downloadFile({
    required String url,
    required String fileName,
    required BuildContext context,
  }) async {
    try {
      print('📥 === DOWNLOAD START ===');
      print('   URL: $url');
      print('   Requested filename: $fileName');

      // Request permission
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        _showSnackbar(
          context,
          'Storage permission denied. Please enable it in settings.',
          isError: true,
        );
        return null;
      }

      // Show downloading message
      _showSnackbar(context, 'Downloading $fileName...');

      // Make the HTTP request
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      print('✅ Downloaded ${response.bodyBytes.length} bytes');

      // Get the Downloads directory
      Directory? directory;
      String locationMessage = '';
      
      if (Platform.isAndroid) {
        // Try external storage Downloads folder first
        directory = Directory('/storage/emulated/0/Download');
        
        if (!await directory.exists()) {
          // Fallback to app-specific external storage
          final externalDir = await getExternalStorageDirectory();
          if (externalDir != null) {
            directory = Directory('${externalDir.path}/Downloads');
            await directory.create(recursive: true);
            locationMessage = 'Internal Storage > Android > data > com.yourapp > files > Downloads';
          }
        } else {
          locationMessage = 'Internal Storage > Download';
        }
      } else {
        // For iOS
        directory = await getApplicationDocumentsDirectory();
        locationMessage = 'Documents folder';
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      print('📁 Directory: ${directory.path}');

      // ✅ FIX 1: Clean filename (remove invalid characters)
      String cleanFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
      
      // ✅ FIX 2: Ensure it has .pdf extension if it's a PDF
      if (!cleanFileName.toLowerCase().endsWith('.pdf') && 
          url.toLowerCase().contains('.pdf')) {
        cleanFileName = '$cleanFileName.pdf';
      }

      // ✅ FIX 3: Generate unique filename if file already exists
      final uniqueFileName = _getUniqueFilename(directory, cleanFileName);
      
      // Create full path
      final filePath = '${directory.path}/$uniqueFileName';
      final file = File(filePath);

      print('💾 Saving as: $uniqueFileName');
      print('   Full path: $filePath');

      // Write the file
      await file.writeAsBytes(response.bodyBytes);

      if (!await file.exists()) {
        throw Exception('File was not created successfully');
      }

      final fileSize = await file.length();
      print('✅ File saved successfully');
      print('   Size: $fileSize bytes');
      print('   Location: $filePath');
      print('📥 === DOWNLOAD COMPLETE ===\n');

      // Show detailed success dialog
      if (context.mounted) {
        _showDownloadSuccessDialog(
          context,
          fileName: uniqueFileName,  // ✅ Show unique filename
          filePath: filePath,
          locationMessage: locationMessage,
          fileSize: fileSize,  // ✅ Pass file size
        );
      }

      return filePath;
    } catch (e, stackTrace) {
      print('❌ Download error: $e');
      print('Stack trace: $stackTrace');
      
      if (context.mounted) {
        _showSnackbar(
          context,
          'Download failed: ${e.toString()}',
          isError: true,
        );
      }
      return null;
    }
  }

  static void _showDownloadSuccessDialog(
    BuildContext context, {
    required String fileName,
    required String filePath,
    required String locationMessage,
    required int fileSize,  // ✅ Added file size
  }) {
    // ✅ Format file size
    String formattedSize;
    if (fileSize < 1024) {
      formattedSize = '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      formattedSize = '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      formattedSize = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Download Complete',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'File Name:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Size: $formattedSize',  // ✅ Show file size
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Saved to:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          locationMessage,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[900],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Full path: $filePath',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Use a file manager app to browse your files',
                      style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openFile(filePath);
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('OPEN FILE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6200EE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> openFile(String filePath) async {
    try {
      print('📂 Opening file: $filePath');
      
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist');
        return;
      }

      final result = await OpenFilex.open(filePath);
      print('📄 Open file result: ${result.type} - ${result.message}');

      if (result.type != ResultType.done) {
        print('⚠️ Could not open file: ${result.message}');
      }
    } catch (e) {
      print('❌ Error opening file: $e');
    }
  }

  static void _showSnackbar(
    BuildContext context,
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF6200EE),
        behavior: SnackBarBehavior.floating,
        action: action,
        duration: Duration(seconds: isError ? 5 : 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}*/

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class DownloadService {

  static String _getUniqueFilename(Directory directory, String fileName) {
    final basePath = directory.path;
    File file = File('$basePath/$fileName');
    if (!file.existsSync()) return fileName;

    final lastDot = fileName.lastIndexOf('.');
    final name = lastDot != -1 ? fileName.substring(0, lastDot) : fileName;
    final extension = lastDot != -1 ? fileName.substring(lastDot) : '';

    int counter = 1;
    while (true) {
      final newFileName = '$name ($counter)$extension';
      file = File('$basePath/$newFileName');
      if (!file.existsSync()) {
        print('📝 Generated unique filename: $newFileName');
        return newFileName;
      }
      counter++;
    }
  }

  static Future<String?> downloadFile({
    required String url,
    required String fileName,
    required BuildContext context,
  }) async {
    try {
      print('📥 === DOWNLOAD START ===');
      print('   URL: $url');
      print('   Requested filename: $fileName');

      _showSnackbar(context, 'Downloading $fileName...');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      print('✅ Downloaded ${response.bodyBytes.length} bytes');

      // ✅ KEY FIX: Use app-specific external storage
      // This does NOT require MANAGE_EXTERNAL_STORAGE permission!
      // Files are visible in Files app under Android/data/com.package/files/SmartSchool/
      Directory? directory;
      String locationMessage = '';

      if (Platform.isAndroid) {
        final baseDir = await getExternalStorageDirectory();
        if (baseDir != null) {
          directory = Directory('${baseDir.path}/SmartSchool');
          await directory.create(recursive: true);
          locationMessage = 'Android > data > your app > files > SmartSchool';
        }
      } else {
        final docsDir = await getApplicationDocumentsDirectory();
        directory = Directory('${docsDir.path}/SmartSchool');
        await directory.create(recursive: true);
        locationMessage = 'Documents > SmartSchool';
      }

      if (directory == null) {
        throw Exception('Could not access storage directory');
      }

      print('📁 Directory: ${directory.path}');

      String cleanFileName = fileName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');

      if (!cleanFileName.toLowerCase().endsWith('.pdf') &&
          url.toLowerCase().contains('.pdf')) {
        cleanFileName = '$cleanFileName.pdf';
      }

      final uniqueFileName = _getUniqueFilename(directory, cleanFileName);
      final filePath = '${directory.path}/$uniqueFileName';
      final file = File(filePath);

      print('💾 Saving as: $uniqueFileName');
      print('   Full path: $filePath');

      await file.writeAsBytes(response.bodyBytes);

      if (!await file.exists()) {
        throw Exception('File was not created successfully');
      }

      final fileSize = await file.length();
      print('✅ File saved successfully');
      print('   Size: $fileSize bytes');
      print('📥 === DOWNLOAD COMPLETE ===\n');

      if (context.mounted) {
        _showDownloadSuccessDialog(
          context,
          fileName: uniqueFileName,
          filePath: filePath,
          locationMessage: locationMessage,
          fileSize: fileSize,
        );
      }

      return filePath;
    } catch (e, stackTrace) {
      print('❌ Download error: $e');
      print('Stack trace: $stackTrace');

      if (context.mounted) {
        _showSnackbar(context, 'Download failed: ${e.toString()}', isError: true);
      }
      return null;
    }
  }

  static Future<List<FileSystemEntity>> getDownloadedFiles() async {
    final baseDir = await getExternalStorageDirectory();
    if (baseDir == null) return [];

    final dir = Directory('${baseDir.path}/SmartSchool');
    if (!await dir.exists()) return [];

    final files = dir
        .listSync()
        .where((f) => f.path.toLowerCase().endsWith('.pdf'))
        .toList();

    files.sort((a, b) {
      return File(b.path).lastModifiedSync()
          .compareTo(File(a.path).lastModifiedSync());
    });

    return files;
  }

  static void _showDownloadSuccessDialog(
    BuildContext context, {
    required String fileName,
    required String filePath,
    required String locationMessage,
    required int fileSize,
  }) {
    String formattedSize;
    if (fileSize < 1024) {
      formattedSize = '$fileSize B';
    } else if (fileSize < 1024 * 1024) {
      formattedSize = '${(fileSize / 1024).toStringAsFixed(1)} KB';
    } else {
      formattedSize = '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 32),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Download Complete',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('File Name:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fileName, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Size: $formattedSize',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text('Saved to:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.folder, size: 16, color: Colors.blue[700]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          locationMessage,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue[900],
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Full path: $filePath',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 18, color: Colors.amber[800]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Open "My Downloads" in the app to view all saved files',
                      style: TextStyle(fontSize: 12, color: Colors.amber[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              openFile(filePath);
            },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('OPEN FILE'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6200EE),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> openFile(String filePath) async {
    try {
      print('📂 Opening file: $filePath');
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist');
        return;
      }
      final result = await OpenFilex.open(filePath);
      print('📄 Open file result: ${result.type} - ${result.message}');
      if (result.type != ResultType.done) {
        print('⚠️ Could not open file: ${result.message}');
      }
    } catch (e) {
      print('❌ Error opening file: $e');
    }
  }

  static void _showSnackbar(
    BuildContext context,
    String message, {
    bool isError = false,
    SnackBarAction? action,
  }) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF6200EE),
        behavior: SnackBarBehavior.floating,
        action: action,
        duration: Duration(seconds: isError ? 5 : 2),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}