import 'dart:io';

import 'package:path/path.dart' as p;

class VaultStorageStats {
  const VaultStorageStats({
    this.fileBytes = 0,
    this.coverBytes = 0,
    this.databaseBytes = 0,
    this.otherBytes = 0,
  });

  final int fileBytes;
  final int coverBytes;
  final int databaseBytes;
  final int otherBytes;
  int get totalBytes => fileBytes + coverBytes + databaseBytes + otherBytes;

  static Future<VaultStorageStats> measure(Directory directory) async {
    var files = 0;
    var covers = 0;
    var database = 0;
    var other = 0;
    await for (final entry in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entry is! File) continue;
      final relative = p.relative(entry.path, from: directory.path);
      final bytes = await entry.length();
      if ([
        'vault.db',
        'vault.db-wal',
        'vault.db-shm',
        'vault.db-journal',
      ].contains(relative)) {
        database += bytes;
      } else if (p.split(relative).first == 'covers') {
        covers += bytes;
      } else if (['files', 'demo'].contains(p.split(relative).first)) {
        files += bytes;
      } else {
        other += bytes;
      }
    }
    return VaultStorageStats(
      fileBytes: files,
      coverBytes: covers,
      databaseBytes: database,
      otherBytes: other,
    );
  }
}
