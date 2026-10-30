enum VaultItemType { text, richText, image, video, file }

class VaultDeletionPlan {
  VaultDeletionPlan({
    required Set<String> folderIds,
    required Set<String> itemIds,
  }) : folderIds = Set.unmodifiable(folderIds),
       itemIds = Set.unmodifiable(itemIds);

  final Set<String> folderIds;
  final Set<String> itemIds;
  bool get isEmpty => folderIds.isEmpty && itemIds.isEmpty;
}

class VaultFolder {
  const VaultFolder({
    required this.id,
    required this.name,
    required this.createdAt,
    this.parentId,
    this.coverRelativePath,
  });

  final String id;
  final String name;
  final String? parentId;
  final DateTime createdAt;
  final String? coverRelativePath;

  VaultFolder withName(String value) => VaultFolder(
    id: id,
    name: value,
    parentId: parentId,
    createdAt: createdAt,
    coverRelativePath: coverRelativePath,
  );

  VaultFolder withCover(String? relativePath) => VaultFolder(
    id: id,
    name: name,
    createdAt: createdAt,
    parentId: parentId,
    coverRelativePath: relativePath,
  );

  factory VaultFolder.fromJson(Map<String, dynamic> json) => VaultFolder(
    id: json['id'] as String,
    name: json['name'] as String,
    parentId: json['parentId'] as String?,
    coverRelativePath: json['coverRelativePath'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'parentId': parentId,
    'coverRelativePath': coverRelativePath,
    'createdAt': createdAt.toIso8601String(),
  };
}

class VaultItem {
  const VaultItem({
    required this.id,
    required this.folderId,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.text = '',
    this.delta,
    this.relativePath,
    this.size = 0,
  });

  final String id;
  final String folderId;
  final String name;
  final VaultItemType type;
  final String text;
  final List<dynamic>? delta;
  final String? relativePath;
  final int size;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isNote =>
      type == VaultItemType.text || type == VaultItemType.richText;

  VaultItem withName(String value) => VaultItem(
    id: id,
    folderId: folderId,
    name: value,
    type: type,
    text: text,
    delta: delta,
    relativePath: relativePath,
    size: size,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );

  factory VaultItem.fromJson(Map<String, dynamic> json) => VaultItem(
    id: json['id'] as String,
    folderId: json['folderId'] as String,
    name: json['name'] as String,
    type: VaultItemType.values.byName(json['type'] as String),
    text: json['text'] as String? ?? '',
    delta: json['delta'] as List<dynamic>?,
    relativePath: json['relativePath'] as String?,
    size: json['size'] as int? ?? 0,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'folderId': folderId,
    'name': name,
    'type': type.name,
    'text': text,
    'delta': delta,
    'relativePath': relativePath,
    'size': size,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };
}
