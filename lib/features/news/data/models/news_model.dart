import 'package:cloud_firestore/cloud_firestore.dart';

class NewsModel {
  const NewsModel({
    required this.id,
    required this.schoolId,
    required this.title,
    required this.content,
    required this.targetGroupIds,
    required this.authorId,
    required this.authorName,
    required this.authorEmail,
    required this.status,
    required this.publishedAt,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.expiresAt,
  });

  final String id;
  final String schoolId;
  final String title;
  final String content;
  final List<String> targetGroupIds;
  final String authorId;
  final String authorName;
  final String? authorEmail;
  final String status;
  final DateTime publishedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? imageUrl;
  final DateTime? expiresAt;

  bool get isExpired {
    final expires = expiresAt;
    return expires != null && expires.isBefore(DateTime.now());
  }

  factory NewsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data() ?? {};

    return NewsModel(
      id: snapshot.id,
      schoolId: data['schoolId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      content: data['content']?.toString() ?? '',
      targetGroupIds: _readStringList(data['targetGroupIds']),
      authorId: data['authorId']?.toString() ?? '',
      authorName: data['authorName']?.toString() ?? 'Administrador',
      authorEmail: data['authorEmail']?.toString(),
      status: data['status']?.toString() ?? 'published',
      publishedAt: _readDate(data['publishedAt']) ?? DateTime.now(),
      createdAt: _readDate(data['createdAt']) ?? DateTime.now(),
      updatedAt: _readDate(data['updatedAt']) ?? DateTime.now(),
      imageUrl: data['imageUrl']?.toString(),
      expiresAt: _readDate(data['expiresAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    final now = Timestamp.now();

    return {
      'schoolId': schoolId,
      'title': title.trim(),
      'content': content.trim(),
      'targetGroupIds': targetGroupIds,
      'visibility': targetGroupIds.contains('all') ? 'school' : 'groups',
      'authorId': authorId,
      'authorName': authorName,
      'authorEmail': authorEmail,
      'status': status,
      'publishedAt': Timestamp.fromDate(publishedAt),
      'expiresAt': expiresAt == null ? null : Timestamp.fromDate(expiresAt!),
      'imageUrl': imageUrl,
      'createdAt': now,
      'updatedAt': now,
    };
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.map((item) => item.toString()).toList(growable: false);
  }

  static DateTime? _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }
}
