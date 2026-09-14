import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'chunked_model_downloader.dart';

enum ModelType {
  voiceAgent,
  textCompletion,
  lineExplainer,
  codeCorrector,
  translation,
  docReader,
  documentScanner,
}

class AIModel {
  final String id;
  final String name;
  final String description;
  final String huggingFaceRepo;
  final String quantizationFile;
  final String targetFileName;
  final int approximateSizeMB;
  final ModelType type;
  final bool isMandatory;
  final String iconEmoji;

  AIModel({
    required this.id,
    required this.name,
    required this.description,
    required this.huggingFaceRepo,
    required this.quantizationFile,
    required this.targetFileName,
    required this.approximateSizeMB,
    required this.type,
    required this.isMandatory,
    required this.iconEmoji,
  });

  String get downloadUrl => 
      'https://huggingface.co/$huggingFaceRepo/resolve/main/$quantizationFile?download=true';

  String get sizeFormatted => '${approximateSizeMB} MB';
}

class AIModelManager {
  static final AIModelManager _instance = AIModelManager._internal();
  factory AIModelManager() => _instance;
  AIModelManager._internal();

  final ChunkedModelDownloader _downloader = ChunkedModelDownloader();
  final Map<String, double> _downloadProgress = {};
  final Map<String, String> _downloadStatus = {};
  final Map<String, bool> _isDownloading = {};

  List<AIModel> get availableModels => [
    // 1. Auto-Call Voice Agent (Mandatory)
    AIModel(
      id: 'voice_agent',
      name: 'Auto-Call Voice Agent',
      description: 'Drives ultra-fast, low-latency conversational audio calls over WebRTC on lower-end devices.',
      huggingFaceRepo: 'microsoft/Phi-3-mini-4k-instruct-gguf',
      quantizationFile: 'Phi-3-mini-4k-instruct-q4.gguf',
      targetFileName: 'autocall_agent.gguf',
      approximateSizeMB: 230,
      type: ModelType.voiceAgent,
      isMandatory: true,
      iconEmoji: '🎤',
    ),
    // 2. Text Auto-Completion & Spell Correction (Optional)
    AIModel(
      id: 'text_completion',
      name: 'Text Auto-Completion',
      description: 'Generates real-time word completions, grammar fixes, and autocomplete suggestions while staff type notices.',
      huggingFaceRepo: 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
      quantizationFile: 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      targetFileName: 'text_completion.gguf',
      approximateSizeMB: 650,
      type: ModelType.textCompletion,
      isMandatory: false,
      iconEmoji: '✍️',
    ),
    // 3. Line Explainer & Dictionary (Optional)
    AIModel(
      id: 'line_explainer',
      name: 'Line Explainer & Dictionary',
      description: 'Explains selected text passages, defines complex institutional jargon, and summarizes circulars in plain language.',
      huggingFaceRepo: 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
      quantizationFile: 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      targetFileName: 'line_explainer.gguf',
      approximateSizeMB: 390,
      type: ModelType.lineExplainer,
      isMandatory: false,
      iconEmoji: '📖',
    ),
    // 4. Code Syntax Corrector (Optional)
    AIModel(
      id: 'code_corrector',
      name: 'Code Syntax Corrector',
      description: 'Fixes syntax errors, validates scripts, and assists inside your embedded flutter_code_editor widget.',
      huggingFaceRepo: 'Qwen/Qwen2.5-Coder-0.5B-Instruct-GGUF',
      quantizationFile: 'qwen2.5-coder-0.5b-instruct-q4_k_m.gguf',
      targetFileName: 'code_corrector.gguf',
      approximateSizeMB: 380,
      type: ModelType.codeCorrector,
      isMandatory: false,
      iconEmoji: '💻',
    ),
    // 5. Document Reader Lite (Optional)
    AIModel(
      id: 'doc_reader_lite',
      name: 'Document Reader Lite',
      description: 'Reads and explains documents, books, and long text passages. 32K token context window. Qwen2.5-1.5B.',
      huggingFaceRepo: 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
      quantizationFile: 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      targetFileName: 'doc_reader_lite.gguf',
      approximateSizeMB: 1100,
      type: ModelType.docReader,
      isMandatory: false,
      iconEmoji: '📄',
    ),
    // 6. Document Reader Pro (Optional)
    AIModel(
      id: 'doc_reader_pro',
      name: 'Document Reader Pro',
      description: 'Large-context document reader with 128K token window. Reads full chapters, long-form content, and entire articles. Llama-3.2-3B.',
      huggingFaceRepo: 'bartowski/Llama-3.2-3B-Instruct-GGUF',
      quantizationFile: 'Llama-3.2-3B-Instruct-Q4_K_M.gguf',
      targetFileName: 'doc_reader_pro.gguf',
      approximateSizeMB: 2000,
      type: ModelType.docReader,
      isMandatory: false,
      iconEmoji: '📚',
    ),
    // 7. Document Scanner AI (Optional)
    AIModel(
      id: 'document_scanner',
      name: 'Document Scanner AI',
      description: 'Processes scanned document text — extracts fields, corrects OCR errors, and identifies document types. Runs entirely offline. Llama-3.2-1B.',
      huggingFaceRepo: 'bartowski/Llama-3.2-1B-Instruct-GGUF',
      quantizationFile: 'Llama-3.2-1B-Instruct-Q4_K_M.gguf',
      targetFileName: 'document_scanner.gguf',
      approximateSizeMB: 700,
      type: ModelType.documentScanner,
      isMandatory: false,
      iconEmoji: '🔍',
    ),
  ];

  Future<bool> isModelInstalled(String modelId) async {
    final model = availableModels.firstWhere((m) => m.id == modelId);
    final fileExists = await _downloader.isModelDownloaded(model.targetFileName);
    final prefsStatus = await getModelInstallationStatus(modelId);
    
    // Debug logging
    print('🔍 Checking model $modelId:');
    print('  - Target file: ${model.targetFileName}');
    print('  - File exists: $fileExists');
    print('  - Prefs status: $prefsStatus');
    
    // Use file existence as primary check, fallback to prefs
    if (fileExists) {
      await _saveModelInstallationStatus(modelId, true);
      return true;
    }
    return prefsStatus;
  }

  Future<bool> isModelDownloading(String modelId) async {
    return _isDownloading[modelId] ?? false;
  }

  double getDownloadProgress(String modelId) {
    return _downloadProgress[modelId] ?? 0.0;
  }

  String getDownloadStatus(String modelId) {
    return _downloadStatus[modelId] ?? 'Not started';
  }

  Future<File?> downloadModel({
    required String modelId,
    required Function(double progress) onProgress,
    required Function(String status) onStatus,
  }) async {
    final model = availableModels.firstWhere((m) => m.id == modelId);
    
    _isDownloading[modelId] = true;
    _downloadProgress[modelId] = 0.0;
    _downloadStatus[modelId] = 'Initializing...';

    final file = await _downloader.downloadInChunks(
      modelUrl: model.downloadUrl,
      targetFileName: model.targetFileName,
      onProgress: (progress) {
        _downloadProgress[modelId] = progress;
        onProgress(progress);
      },
      onStatusUpdate: (status) {
        _downloadStatus[modelId] = status;
        onStatus(status);
      },
    );

    _isDownloading[modelId] = false;
    
    if (file != null) {
      await _saveModelInstallationStatus(modelId, true);
      _downloadStatus[modelId] = 'Installed';
    } else {
      _downloadStatus[modelId] = 'Failed';
    }

    return file;
  }

  Future<void> cancelDownload(String modelId) async {
    final model = availableModels.firstWhere((m) => m.id == modelId);
    await _downloader.cancelDownload(model.targetFileName);
    _isDownloading[modelId] = false;
    _downloadProgress[modelId] = 0.0;
    _downloadStatus[modelId] = 'Cancelled';
  }

  Future<void> pauseDownload(String modelId) async {
    final model = availableModels.firstWhere((m) => m.id == modelId);
    _downloader.requestPause(model.targetFileName);
    _isDownloading[modelId] = false;
    _downloadStatus[modelId] = 'Paused';
  }

  Future<bool> canResumeDownload(String modelId) async {
    final model = availableModels.firstWhere((m) => m.id == modelId);
    return await _downloader.canResumeDownload(model.targetFileName);
  }

  Future<String?> getPendingDownload() async {
    final appDir = await getApplicationSupportDirectory();
    final modelsDirectory = Directory('${appDir.path}/local_models');
    if (!await modelsDirectory.exists()) return null;

    final files = await modelsDirectory.list().toList();
    for (final model in availableModels) {
      final installed = await isModelInstalled(model.id);
      if (installed) continue;
      final hasTemp = files.any((f) => f.path.endsWith('${model.targetFileName}.tmp'));
      final hasProgress = await _downloader.canResumeDownload(model.targetFileName);
      if (hasTemp || hasProgress) return model.id;
    }
    return null;
  }

  Future<void> deleteModel(String modelId) async {
    final model = availableModels.firstWhere((m) => m.id == modelId);
    await _downloader.deleteModel(model.targetFileName);
    await _saveModelInstallationStatus(modelId, false);
    _downloadProgress[modelId] = 0.0;
    _downloadStatus[modelId] = 'Not installed';
  }

  Future<void> _saveModelInstallationStatus(String modelId, bool installed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('model_$modelId', installed);
  }

  Future<bool> getModelInstallationStatus(String modelId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('model_$modelId') ?? false;
  }

  Future<void> checkAllModelsStatus() async {
    for (final model in availableModels) {
      final isInstalled = await isModelInstalled(model.id);
      await _saveModelInstallationStatus(model.id, isInstalled);
      _downloadStatus[model.id] = isInstalled ? 'Installed' : 'Not installed';
    }
  }

  Future<AIModel?> getMandatoryModel() async {
    return availableModels.firstWhere((m) => m.isMandatory);
  }

  Future<bool> isMandatoryModelInstalled() async {
    final mandatoryModel = await getMandatoryModel();
    if (mandatoryModel == null) return true;
    return await isModelInstalled(mandatoryModel.id);
  }

  Future<File?> getModelFile(String modelId) async {
    final model = availableModels.firstWhere((m) => m.id == modelId);
    final appDir = await getApplicationSupportDirectory();
    final modelsDirectory = Directory('${appDir.path}/local_models');
    final file = File('${modelsDirectory.path}/${model.targetFileName}');
    
    if (await file.exists()) {
      return file;
    }
    return null;
  }

  Future<int> getTotalInstalledSize() async {
    int totalSize = 0;
    for (final model in availableModels) {
      if (await isModelInstalled(model.id)) {
        totalSize += model.approximateSizeMB;
      }
    }
    return totalSize;
  }

  Future<int> getTotalDownloadableSize() async {
    int totalSize = 0;
    for (final model in availableModels) {
      if (!await isModelInstalled(model.id)) {
        totalSize += model.approximateSizeMB;
      }
    }
    return totalSize;
  }
}
