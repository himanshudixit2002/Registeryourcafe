import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/app_logger.dart';

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Uploads image bytes to Firebase Storage under an automatically generated path.
  /// Returns the download URL when the upload completes.
  Future<String> uploadStockImage(
    Uint8List data, {
    required String itemId,
    required bool isMerchandise,
    required String fileExt,
  }) async {
    final folder = isMerchandise ? 'merchandise' : 'cafe';
    final ext = fileExt.toLowerCase();
    final path = 'stock_images/$folder/$itemId.$ext';
    final ref = _storage.ref().child(path);

    final mime = _mimeTypeFromExtension(ext);

    final uploadTask = ref.putData(data, SettableMetadata(contentType: mime));

    await uploadTask;
    return await ref.getDownloadURL();
  }

  /// Cover image for [publicVenues] listing (anonymous landing).
  Future<String> uploadPublicVenueCover({
    required Uint8List data,
    required String companyId,
    required String fileExt,
  }) async {
    final ext = fileExt.toLowerCase();
    final path = 'public_venues/$companyId/cover.$ext';
    final ref = _storage.ref().child(path);
    final mime = _mimeTypeFromExtension(ext);
    final uploadTask = ref.putData(data, SettableMetadata(contentType: mime));
    await uploadTask;
    return await ref.getDownloadURL();
  }

  /// Image for a document in [public_menu_items].
  Future<String> uploadPublicMenuItemImage({
    required Uint8List data,
    required String companyId,
    required String itemId,
    required String fileExt,
  }) async {
    final ext = fileExt.toLowerCase();
    final path = 'public_menu_images/$companyId/$itemId.$ext';
    final ref = _storage.ref().child(path);
    final mime = _mimeTypeFromExtension(ext);
    final uploadTask = ref.putData(data, SettableMetadata(contentType: mime));
    await uploadTask;
    return await ref.getDownloadURL();
  }

  Future<String> uploadCompanyLogo({
    required Uint8List data,
    required String companyId,
    required String fileExt,
  }) async {
    final ext = fileExt.toLowerCase();
    final path = 'company_logos/$companyId/logo.$ext';
    final ref = _storage.ref().child(path);
    final mime = _mimeTypeFromExtension(ext);
    final uploadTask = ref.putData(data, SettableMetadata(contentType: mime));
    await uploadTask;
    return await ref.getDownloadURL();
  }

  /// Deletes an image from Firebase Storage using its full download URL.
  Future<void> deleteImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;
    try {
      final ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } on FirebaseException catch (e) {
      // It's okay if the file doesn't exist - silently ignore
      if (e.code != 'object-not-found') {
        AppLogger.warning('Error deleting image: $e', tag: 'StorageService');
      }
    } catch (e) {
      AppLogger.warning(
        'Unexpected error deleting image: $e',
        tag: 'StorageService',
      );
    }
  }

  String _mimeTypeFromExtension(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'svg':
        return 'image/svg+xml';
      default:
        return 'application/octet-stream';
    }
  }
}

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);
