import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'package:dutch_learn_app/data/services/audio_processor.dart';
import 'package:dutch_learn_app/data/services/gpt_service.dart';
import 'package:dutch_learn_app/data/services/whisper_service.dart';
import 'package:dutch_learn_app/presentation/providers/project_provider.dart';

/// Screen for recording audio or selecting files for processing.
class RecordScreen extends ConsumerStatefulWidget {
  const RecordScreen({super.key});

  @override
  ConsumerState<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends ConsumerState<RecordScreen> {
  final _audioRecorder = AudioRecorder();
  final _secureStorage = const FlutterSecureStorage();

  bool _isRecording = false;
  bool _isProcessing = false;
  String? _recordingPath;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  ProcessingStatus? _processingStatus;
  String? _apiKey;
  bool _apiKeyLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadApiKey();
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _loadApiKey() async {
    final key = await _secureStorage.read(key: 'openai_api_key');
    setState(() {
      _apiKey = key;
      _apiKeyLoaded = true;
    });
  }

  Future<void> _saveApiKey(String key) async {
    await _secureStorage.write(key: 'openai_api_key', value: key);
    setState(() {
      _apiKey = key;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Recording'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _showApiKeyDialog,
            tooltip: 'API Key Settings',
          ),
        ],
      ),
      body: _isProcessing
          ? _buildProcessingView(theme)
          : _buildMainView(theme),
    );
  }

  Widget _buildMainView(ThemeData theme) {
    if (!_apiKeyLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      return _buildApiKeyRequired(theme);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recording section
          _buildRecordingSection(theme),

          const SizedBox(height: 32),

          // Or divider
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'OR',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),

          const SizedBox(height: 32),

          // File picker section
          _buildFilePickerSection(theme),
        ],
      ),
    );
  }

  Widget _buildApiKeyRequired(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.key,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 24),
            Text(
              'API Key Required',
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'To process audio on your device, you need to configure your OpenAI API key.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showApiKeyDialog,
              icon: const Icon(Icons.settings),
              label: const Text('Configure API Key'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordingSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.mic,
              size: 48,
              color: _isRecording
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _isRecording ? 'Recording...' : 'Record Audio',
              style: theme.textTheme.titleLarge,
            ),
            if (_isRecording) ...[
              const SizedBox(height: 8),
              Text(
                _formatDuration(_recordingDuration),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontFamily: 'monospace',
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!_isRecording)
                  ElevatedButton.icon(
                    onPressed: _startRecording,
                    icon: const Icon(Icons.fiber_manual_record),
                    label: const Text('Start Recording'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                  )
                else ...[
                  ElevatedButton.icon(
                    onPressed: _stopRecording,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _cancelRecording,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: theme.colorScheme.secondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Select Audio/Video File',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Supported formats: MP3, WAV, M4A, MP4, MOV',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.upload_file),
              label: const Text('Choose File'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessingView(ThemeData theme) {
    final status = _processingStatus;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (status?.stage == ProcessingStage.error)
              Icon(
                Icons.error,
                size: 64,
                color: theme.colorScheme.error,
              )
            else
              const SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(),
              ),
            const SizedBox(height: 24),
            Text(
              _getStageTitle(status?.stage ?? ProcessingStage.extracting),
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              status?.message ?? 'Processing...',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            if (status?.stage != ProcessingStage.error &&
                status?.stage != ProcessingStage.complete) ...[
              const SizedBox(height: 24),
              LinearProgressIndicator(
                value: status?.progress ?? 0,
              ),
              const SizedBox(height: 8),
              Text(
                '${((status?.progress ?? 0) * 100).toInt()}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (status?.stage == ProcessingStage.error) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isProcessing = false;
                    _processingStatus = null;
                  });
                },
                child: const Text('Try Again'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getStageTitle(ProcessingStage stage) {
    switch (stage) {
      case ProcessingStage.extracting:
        return 'Extracting Audio';
      case ProcessingStage.transcribing:
        return 'Transcribing';
      case ProcessingStage.explaining:
        return 'Generating Explanations';
      case ProcessingStage.complete:
        return 'Complete!';
      case ProcessingStage.error:
        return 'Processing Failed';
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final appDir = await getApplicationDocumentsDirectory();
        final recordingDir = Directory('${appDir.path}/recordings');
        if (!recordingDir.existsSync()) {
          recordingDir.createSync(recursive: true);
        }

        final recordingId = const Uuid().v4();
        _recordingPath = '${recordingDir.path}/$recordingId.m4a';

        await _audioRecorder.start(
          const RecordConfig(encoder: AudioEncoder.aacLc),
          path: _recordingPath!,
        );

        setState(() {
          _isRecording = true;
          _recordingDuration = Duration.zero;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration += const Duration(seconds: 1);
          });
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Microphone permission required'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final path = await _audioRecorder.stop();

    setState(() {
      _isRecording = false;
    });

    if (path != null) {
      await _processFile(File(path));
    }
  }

  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _audioRecorder.stop();

    // Delete the recording file
    if (_recordingPath != null) {
      final file = File(_recordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    setState(() {
      _isRecording = false;
      _recordingPath = null;
      _recordingDuration = Duration.zero;
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'm4a', 'mp4', 'mov', 'mkv', 'webm'],
    );

    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        await _processFile(File(path));
      }
    }
  }

  Future<void> _processFile(File file) async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure your API key first')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingStatus = ProcessingStatus(
        stage: ProcessingStage.extracting,
        progress: 0,
        message: 'Starting...',
      );
    });

    try {
      final whisperService = WhisperService(apiKey: _apiKey!);
      final gptService = GptService(apiKey: _apiKey!);
      final processor = AudioProcessor(
        whisperService: whisperService,
        gptService: gptService,
      );

      final project = await processor.processFile(
        file,
        onProgress: (status) {
          setState(() {
            _processingStatus = status;
          });
        },
      );

      // Import the project
      final projectNotifier = ref.read(projectListProvider.notifier);
      await projectNotifier.importProcessedProject(project);

      setState(() {
        _isProcessing = false;
        _processingStatus = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Project "${project.name}" created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      setState(() {
        _processingStatus = ProcessingStatus(
          stage: ProcessingStage.error,
          progress: 0,
          message: e.toString(),
        );
      });
    }
  }

  void _showApiKeyDialog() {
    final controller = TextEditingController(text: _apiKey);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('OpenAI API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your OpenAI API key to enable audio processing on this device.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            Text(
              'Your key is stored securely on this device only.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _saveApiKey(controller.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
