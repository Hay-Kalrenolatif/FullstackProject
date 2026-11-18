/// Profil pengguna dan pengumuman broadcast.
library;

import 'asset_enums.dart';
import 'row.dart';

class Profile {
  Profile({
    required this.id,
    required this.username,
    required this.fullName,
    required this.description,
    required this.role,
    required this.isActive,
    this.avatarPath,
    this.createdAt,
    this.updatedAt,
  });

  final String id;

  /// Username login, bukan email: email sintetis `username@sibal.my.id`
  /// sengaja tidak ditampilkan di UI.
  final String username;
  final String fullName;
  final String description;
  final AppRole role;
  final bool isActive;

  /// object name di Storage, bukan URL — lihat 0001 §4.
  final String? avatarPath;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Profile.fromRow(Row r) => Profile(
        id: s(r, 'id'),
        username: s(r, 'username'),
        fullName: s(r, 'full_name'),
        description: s(r, 'description'),
        role: AppRole.parse(sOrNull(r, 'role')),
        isActive: b(r, 'is_active', fallback: true),
        avatarPath: sOrNull(r, 'avatar_path'),
        createdAt: dt(r, 'created_at'),
        updatedAt: dt(r, 'updated_at'),
      );

  static List<Profile> rows(List<Row> rs) => rs.map(Profile.fromRow).toList();

  Row toJson() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'description': description,
        'role': role.wire,
        'is_active': isActive,
        'avatar_path': avatarPath,
        'created_at': createdAt?.toIso8601String(),
        'updated_at': updatedAt?.toIso8601String(),
      };

  bool get isAdmin => role == AppRole.admin && isActive;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    String take2(String s) => s.length <= 2 ? s.toUpperCase() : s.substring(0, 2).toUpperCase();
    if (parts.isEmpty) return take2(username);
    if (parts.length == 1) return take2(parts.first);
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class Announcement {
  Announcement({
    required this.id,
    required this.title,
    required this.body,
    required this.level,
    required this.isPublished,
    this.publishedAt,
    this.expiresAt,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final AnnouncementLevel level;
  final bool isPublished;
  final DateTime? publishedAt;
  final DateTime? expiresAt;
  final String? createdBy;
  final DateTime? createdAt;

  factory Announcement.fromRow(Row r) => Announcement(
        id: s(r, 'id'),
        title: s(r, 'title'),
        body: s(r, 'body'),
        level: AnnouncementLevel.parseOr(sOrNull(r, 'level')),
        isPublished: b(r, 'is_published'),
        publishedAt: dt(r, 'published_at'),
        expiresAt: dt(r, 'expires_at'),
        createdBy: sOrNull(r, 'created_by'),
        createdAt: dt(r, 'created_at'),
      );

  static List<Announcement> rows(List<Row> rs) => rs.map(Announcement.fromRow).toList();

  Row toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'level': level.wire,
        'is_published': isPublished,
        'published_at': publishedAt?.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
        'created_by': createdBy,
        'created_at': createdAt?.toIso8601String(),
      };

  /// Jendela tayang disaring di klien karena expires_at memakai now() yang tidak
  /// boleh masuk index (lihat 0001 §9).
  bool masihTayang([DateTime? now]) {
    if (!isPublished) return false;
    final t = now ?? DateTime.now().toUtc();
    if (expiresAt != null && !t.isBefore(expiresAt!)) return false;
    if (publishedAt != null && t.isBefore(publishedAt!)) return false;
    return true;
  }
}
