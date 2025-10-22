import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';

class EncryptionService {
  static final String _encryptionKey =
      'Your32BitLongEncryptionKey123!'; // In production, use secure storage

  static String encryptMessage(String message) {
    final key = Key.fromUtf8(_encryptionKey);
    final iv = IV.fromLength(16);
    final encrypter = Encrypter(AES(key));
    final encrypted = encrypter.encrypt(message, iv: iv);
    return encrypted.base64;
  }

  static String decryptMessage(String encryptedMessage) {
    try {
      final key = Key.fromUtf8(_encryptionKey);
      final iv = IV.fromLength(16);
      final encrypter = Encrypter(AES(key));
      final decrypted = encrypter.decrypt64(encryptedMessage, iv: iv);
      return decrypted;
    } catch (e) {
      return '🔒 Encrypted Message';
    }
  }

  static String generateMessageHash(String message) {
    return sha256.convert(utf8.encode(message)).toString();
  }
}
