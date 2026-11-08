import 'package:flutter_test/flutter_test.dart';
import 'package:titotech_multiuploader_mobile/models/processing_result.dart';
import 'package:titotech_multiuploader_mobile/models/upload_job.dart';
import 'package:titotech_multiuploader_mobile/models/video_metadata.dart';
import 'package:titotech_multiuploader_mobile/providers_api/base_provider.dart';
import 'package:titotech_multiuploader_mobile/services/storage_checker.dart';

void main() {
  group('Video Decision Tree Logic', () {
    test('MP4 with H.264 and AAC is ready for direct upload', () {
      const meta = VideoMetadata(
        filename: 'Bleach_Ep01.mp4',
        sourceUri: '/path/to/Bleach_Ep01.mp4',
        filesize: 100000000,
        durationSeconds: 1420.0,
        videoCodec: 'h264',
        audioCodec: 'aac',
        width: 1920,
        height: 1080,
        bitrateBps: 2500000,
        containerFormat: 'mov,mp4,m4a,3gp,3g2,mj2',
      );

      expect(meta.isH264, isTrue);
      expect(meta.isAac, isTrue);
      expect(meta.isMp4, isTrue);
      expect(meta.recommendedStrategy, 'ready');
    });

    test('MKV with H.264 and AAC recommends fast REMUX without transcoding', () {
      const meta = VideoMetadata(
        filename: 'Demon_Slayer.mkv',
        sourceUri: '/path/to/Demon_Slayer.mkv',
        filesize: 350000000,
        durationSeconds: 1420.0,
        videoCodec: 'h264',
        audioCodec: 'aac',
        width: 1920,
        height: 1080,
        bitrateBps: 4500000,
        containerFormat: 'matroska,webm',
      );

      expect(meta.isH264, isTrue);
      expect(meta.isAac, isTrue);
      expect(meta.isMkv, isTrue);
      expect(meta.recommendedStrategy, 'remux');
    });

    test('H.264 with AC3 audio recommends video stream copy and audio AAC transcode', () {
      const meta = VideoMetadata(
        filename: 'Movie_5.1.mkv',
        sourceUri: '/path/to/Movie_5.1.mkv',
        filesize: 1200000000,
        durationSeconds: 7200.0,
        videoCodec: 'h264',
        audioCodec: 'ac3',
        width: 1920,
        height: 1080,
        bitrateBps: 6000000,
        containerFormat: 'matroska',
      );

      expect(meta.isH264, isTrue);
      expect(meta.isAac, isFalse);
      expect(meta.recommendedStrategy, 'video_copy_audio_aac');
    });

    test('HEVC / H.265 recommends hardware MediaCodec transcode', () {
      const meta = VideoMetadata(
        filename: 'Anime_x265_10bit.mkv',
        sourceUri: '/path/to/Anime_x265_10bit.mkv',
        filesize: 250000000,
        durationSeconds: 1420.0,
        videoCodec: 'hevc',
        audioCodec: 'opus',
        width: 1920,
        height: 1080,
        bitrateBps: 2000000,
        containerFormat: 'matroska',
      );

      expect(meta.isH264, isFalse);
      expect(meta.recommendedStrategy, 'mediacodec_transcode');
    });
  });

  group('Storage and Metrics Formatting', () {
    test('Format bytes accurately', () {
      expect(StorageCheckResult.formatBytes(500), '500.0 B');
      expect(StorageCheckResult.formatBytes(1024 * 1024), '1.0 MB');
      expect(StorageCheckResult.formatBytes(2500 * 1024 * 1024), '2.4 GB');
    });

    test('Calculate processing savings percent and bytes', () {
      const result = ProcessingResult(
        success: true,
        outputPath: '/tmp/out.mp4',
        outputFilesize: 200000000,
        processingTimeMs: 15000,
        averageFps: 95.0,
        speedMultiplier: 3.8,
        modeUsed: 'mediacodec',
      );

      expect(result.savedBytes(400000000), 200000000);
      expect(result.savingsPercent(400000000), 50.0);
    });
  });

  group('Folder Token Normalization', () {
    test('Canonical deduplication strips stopwords and sorts tokens', () {
      final norm1 = normalizeFolderTokens('Solo Leveling y las Sombras');
      final norm2 = normalizeFolderTokens('las Sombras de Solo Leveling');
      expect(norm1, equals(norm2));
      expect(norm1, 'levelingsolosombras');
    });
  });

  group('UploadJob Model', () {
    test('Creates and serializes correctly', () {
      final job = UploadJob(
        id: 'job-123',
        overallStatus: OverallStatus.pending,
        filename: 'test.mp4',
        sourceUri: '/test.mp4',
        filesize: 1024,
        processedFilesize: 0,
        durationSeconds: 60,
        seriesId: 's1',
        seriesTitle: 'Series 1',
        season: 1,
        episode: 1,
        title: 'Title',
        folderName: 'Folder',
        processingMode: ProcessingMode.auto,
        processingState: 'idle',
        conversionFps: 0,
        conversionSpeed: 0,
        conversionProgress: 0,
        providers: {},
        syncState: SyncState.pending,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = job.toMap();
      expect(map['id'], 'job-123');
      expect(map['filename'], 'test.mp4');
      expect(map['overall_status'], 'pending');

      final fromMap = UploadJob.fromMap(map);
      expect(fromMap.id, 'job-123');
      expect(fromMap.filename, 'test.mp4');
    });
  });
}
