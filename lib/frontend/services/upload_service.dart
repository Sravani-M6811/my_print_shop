import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Uploads a custom design image to Firebase Storage for sync across devices.
///
/// Storage rules allow each signed-in user to read/write only
/// `custom_designs/{uid}/...`. Guests (and anyone whose upload fails, e.g.
/// when Firebase isn't configured) keep using the local image reference so
/// the design still works on the current device/session.
///
/// Cross-platform note: bytes are read via [XFile.readAsBytes] and uploaded
/// with [Reference.putData], which work on both Android/iOS (native) and Web
/// (where `dart:io`/`File`/`putFile` are unavailable).
class UploadService {
  Future<String> uploadDesignImage(XFile image) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return image.path;

    try {
      final fileName =
          'design_${DateTime.now().millisecondsSinceEpoch}${_extension(image.path)}';
      final ref = FirebaseStorage.instance
          .ref('custom_designs/${user.uid}/$fileName');
      final bytes = await image.readAsBytes();
      final contentType = fileName.endsWith('.png') ? 'image/png' : 'image/jpeg';
      await ref.putData(bytes, SettableMetadata(contentType: contentType));
      return await ref.getDownloadURL();
    } catch (_) {
      // Firebase unavailable or upload rejected — fall back to the local ref.
      return image.path;
    }
  }

  /// Uploads the current picked design image (if any) before adding to cart.
  /// Returns the path/URL to store on the cart item.
  Future<String> prepareDesignPath(XFile? image) async {
    if (image == null) return '';
    if (image.path.startsWith('http')) return image.path;
    return uploadDesignImage(image);
  }

  String _extension(String path) {
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '.png';
    final ext = path.substring(dot).toLowerCase();
    return ext.length <= 5 ? ext : '.png';
  }
}
