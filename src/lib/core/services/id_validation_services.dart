part of raven_app;

class RavenIdService {
  static String _slug(String name) {
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return slug.isEmpty ? 'user' : slug;
  }

  static String createFromName(String name) {
    final random = Random.secure().nextInt(0xFFFFF).toRadixString(16).toUpperCase().padLeft(5, '0');
    return 'rvn_${_slug(name)}_$random';
  }

  static String stableFromName(String name) {
    final base = _slug(name);
    final checksum = name.codeUnits.fold<int>(17, (sum, value) => (sum * 31 + value) & 0xFFFFF);
    return 'rvn_${base}_${checksum.toRadixString(16).toUpperCase().padLeft(5, '0')}';
  }

  static String normalizeOrCreate(String value, String fallbackName) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return createFromName(fallbackName);
    final clean = trimmed.replaceAll(RegExp(r'\s+'), '_').toLowerCase();
    return clean.startsWith('rvn_') ? clean : 'rvn_$clean';
  }
}


class RavenValidation {
  static final RegExp emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp ravenIdPattern = RegExp(r'^rvn_[a-zA-Z0-9_-]{3,44}$');

  static bool isValidEmail(String value) {
    final clean = value.trim();
    return clean.isNotEmpty && clean.length <= 254 && emailPattern.hasMatch(clean);
  }

  static String? ravenIdError(String value, {String? ownRavenId}) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Enter a Raven ID.';
    if (clean.length > 48) return 'Raven ID is too long.';
    if (!ravenIdPattern.hasMatch(clean)) {
      return 'Invalid Raven ID. Use a format like rvn_name_8F3A2.';
    }
    if (ownRavenId != null && clean.toLowerCase() == ownRavenId.toLowerCase()) {
      return 'You cannot start a chat with yourself.';
    }
    return null;
  }

  static String? groupNameError(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Group name is required.';
    if (clean.length > 40) return 'Group name must be at most 40 characters.';
    return null;
  }

  static String? displayNameError(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return 'Display name is required.';
    if (clean.length < 2) return 'Display name must have at least 2 characters.';
    if (clean.length > 40) return 'Display name must be at most 40 characters.';
    return null;
  }

  static String? optionalPhotoUrlError(String value) {
    final clean = value.trim();
    if (clean.isEmpty) return null;
    final uri = Uri.tryParse(clean);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return 'Use a valid image URL, or leave this field empty.';
    }
    if (clean.length > 500) return 'Image URL must be at most 500 characters.';
    return null;
  }
}

class MessageSyncService {
  const MessageSyncService();

  Future<void> simulateOutgoingStatusFlow(Future<void> Function(MessageDeliveryStatus status) onStatus) async {
    await Future.delayed(const Duration(milliseconds: 650));
    await onStatus(MessageDeliveryStatus.sent);
    await Future.delayed(const Duration(milliseconds: 900));
    await onStatus(MessageDeliveryStatus.delivered);
  }
}

