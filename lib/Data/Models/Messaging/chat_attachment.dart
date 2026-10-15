import 'chat_enums.dart';

/// A single attachment carried by a [ChatMessage].
class ChatAttachment {
  final String id;
  final String name;
  final MessageContentType type;
  final int sizeBytes;
  final String? mimeType;
  final String? localPath;
  final String? remoteUrl;
  final String? thumbnailUrl;
  final int? durationMs;
  final int? width;
  final int? height;
  final String? emojiShortcode;
  final double? latitude;
  final double? longitude;
  final String? contactName;
  final String? contactPhone;
  final String? caption;

  const ChatAttachment({
    required this.id,
    required this.name,
    required this.type,
    this.sizeBytes = 0,
    this.mimeType,
    this.localPath,
    this.remoteUrl,
    this.thumbnailUrl,
    this.durationMs,
    this.width,
    this.height,
    this.emojiShortcode,
    this.latitude,
    this.longitude,
    this.contactName,
    this.contactPhone,
    this.caption,
  });

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: MessageContentType.fromJson(json['type']?.toString()),
      sizeBytes: (json['size_bytes'] as num?)?.toInt() ?? 0,
      mimeType: json['mime_type']?.toString(),
      localPath: json['local_path']?.toString(),
      remoteUrl: json['remote_url']?.toString(),
      thumbnailUrl: json['thumbnail_url']?.toString(),
      durationMs: (json['duration_ms'] as num?)?.toInt(),
      width: (json['width'] as num?)?.toInt(),
      height: (json['height'] as num?)?.toInt(),
      emojiShortcode: json['emoji_shortcode']?.toString(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      contactName: json['contact_name']?.toString(),
      contactPhone: json['contact_phone']?.toString(),
      caption: json['caption']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.toJson(),
      'size_bytes': sizeBytes,
      'mime_type': mimeType,
      'local_path': localPath,
      'remote_url': remoteUrl,
      'thumbnail_url': thumbnailUrl,
      'duration_ms': durationMs,
      'width': width,
      'height': height,
      'emoji_shortcode': emojiShortcode,
      'latitude': latitude,
      'longitude': longitude,
      'contact_name': contactName,
      'contact_phone': contactPhone,
      'caption': caption,
    };
  }

  ChatAttachment copyWith({
    String? id,
    String? name,
    MessageContentType? type,
    int? sizeBytes,
    String? mimeType,
    String? localPath,
    String? remoteUrl,
    String? thumbnailUrl,
    int? durationMs,
    int? width,
    int? height,
    String? caption,
  }) {
    return ChatAttachment(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      mimeType: mimeType ?? this.mimeType,
      localPath: localPath ?? this.localPath,
      remoteUrl: remoteUrl ?? this.remoteUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      durationMs: durationMs ?? this.durationMs,
      width: width ?? this.width,
      height: height ?? this.height,
      emojiShortcode: emojiShortcode,
      latitude: latitude,
      longitude: longitude,
      contactName: contactName,
      contactPhone: contactPhone,
      caption: caption ?? this.caption,
    );
  }

  String get fileExtension {
    final dot = name.lastIndexOf('.');
    return dot == -1 ? '' : name.substring(dot + 1).toLowerCase();
  }
}
