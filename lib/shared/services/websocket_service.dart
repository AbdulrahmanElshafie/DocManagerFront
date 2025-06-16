import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../utils/logger.dart';
import '../services/secure_storage_service.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  WebSocketChannel? _channel;
  String? _currentDocumentId;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  bool _isConnected = false;
  int _reconnectAttempts = 0;
  
  // Stream controllers
  final _connectionStateController = StreamController<bool>.broadcast();
  final _saveStatusController = StreamController<SaveStatus>.broadcast();
  final _errorController = StreamController<String>.broadcast();
  final _documentUpdateController = StreamController<DocumentUpdate>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  
  // Public streams
  Stream<bool> get connectionState => _connectionStateController.stream;
  Stream<SaveStatus> get saveStatus => _saveStatusController.stream;
  Stream<String> get errors => _errorController.stream;
  Stream<DocumentUpdate> get documentUpdates => _documentUpdateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  
  // Getter for connection status
  bool get isConnected => _isConnected;
  
  // Debounce timer for content updates
  Timer? _debounceTimer;
  String? _pendingContent;
  String? _pendingContentType;

  Future<void> connect(String wsUrl) async {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );
      
      // Start ping timer to keep connection alive
      _startPingTimer();
      
      _isConnected = true;
      _reconnectAttempts = 0;
      _connectionStateController.add(true);
      
      LoggerUtil.info('WebSocket connected to: $wsUrl');
    } catch (e) {
      LoggerUtil.error('WebSocket connection error: $e');
      _errorController.add('Connection failed: $e');
      _scheduleReconnect();
    }
  }

  Future<void> connectToDocument(String documentId) async {
    try {
      // Disconnect from previous document if any
      if (_currentDocumentId != null && _currentDocumentId != documentId) {
        await disconnect();
      }
      
      _currentDocumentId = documentId;
      
      // Get authentication token from secure storage
      final secureStorage = SecureStorageService();
      final token = await secureStorage.readSecureData('authToken');
      
      if (token == null) {
        throw Exception('No authentication token available');
      }
      
      // Connect to WebSocket
      final wsUrl = 'ws://localhost:8000/ws/document/$documentId/?token=$token';
      await connect(wsUrl);
      
      LoggerUtil.info('WebSocket connected to document: $documentId');
    } catch (e) {
      LoggerUtil.error('WebSocket connection error: $e');
      _errorController.add('Connection failed: $e');
      _scheduleReconnect();
    }
  }
  
  void sendContentUpdate(String content, String contentType) {
    if (!_isConnected || _channel == null) {
      LoggerUtil.warning('WebSocket not connected, queuing update');
      _pendingContent = content;
      _pendingContentType = contentType;
      return;
    }
    
    // Cancel previous debounce timer
    _debounceTimer?.cancel();
    
    // Store pending content
    _pendingContent = content;
    _pendingContentType = contentType;
    
    // Create new debounce timer (send after 500ms of no changes)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_pendingContent != null && _pendingContentType != null) {
        sendMessage({
          'type': 'content_update',
          'content': _pendingContent,
          'content_type': _pendingContentType,
        });
        _pendingContent = null;
        _pendingContentType = null;
      }
    });
  }
  
  void forceSave() {
    if (!_isConnected || _channel == null) {
      LoggerUtil.warning('WebSocket not connected');
      return;
    }
    
    // Cancel debounce timer
    _debounceTimer?.cancel();
    
    if (_pendingContent != null && _pendingContentType != null) {
      sendMessage({
        'type': 'force_save',
        'content': _pendingContent,
        'content_type': _pendingContentType,
      });
      _pendingContent = null;
      _pendingContentType = null;
    } else {
      sendMessage({
        'type': 'force_save',
      });
    }
  }
  
  void sendMessage(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      LoggerUtil.error('Error sending WebSocket message: $e');
      _errorController.add('Failed to send message: $e');
    }
  }
  
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'] as String?;
      
      // Add to message stream for backward compatibility
      _messageController.add(data);
      
      switch (type) {
        case 'connection_established':
          LoggerUtil.info('WebSocket connection established');
          // Send any pending content
          if (_pendingContent != null && _pendingContentType != null) {
            sendContentUpdate(_pendingContent!, _pendingContentType!);
          }
          break;
          
        case 'update_received':
          // Content update acknowledged
          break;
          
        case 'auto_save_result':
        case 'save_result':
          final success = data['success'] as bool? ?? false;
          final timestamp = data['timestamp'] as String?;
          _saveStatusController.add(SaveStatus(
            success: success,
            timestamp: timestamp ?? DateTime.now().toIso8601String(),
            isAutoSave: type == 'auto_save_result',
          ));
          break;
          
        case 'document_updated_by_other':
          final userId = data['user_id'] as String?;
          final timestamp = data['timestamp'] as String?;
          _documentUpdateController.add(DocumentUpdate(
            userId: userId,
            timestamp: timestamp ?? DateTime.now().toIso8601String(),
          ));
          break;
          
        case 'error':
          final errorMessage = data['message'] as String?;
          LoggerUtil.error('WebSocket error: $errorMessage');
          _errorController.add(errorMessage ?? 'Unknown error');
          break;
          
        case 'pong':
          // Ping response received
          break;
          
        default:
          LoggerUtil.warning('Unknown WebSocket message type: $type');
      }
    } catch (e) {
      LoggerUtil.error('Error handling WebSocket message: $e');
    }
  }
  
  void _handleError(error) {
    LoggerUtil.error('WebSocket error: $error');
    _errorController.add('Connection error: $error');
    _isConnected = false;
    _connectionStateController.add(false);
    _scheduleReconnect();
  }
  
  void _handleDisconnect() {
    LoggerUtil.info('WebSocket disconnected');
    _isConnected = false;
    _connectionStateController.add(false);
    _stopPingTimer();
    
    // Save any pending content before disconnecting
    if (_pendingContent != null && _pendingContentType != null) {
      forceSave();
    }
    
    _scheduleReconnect();
  }
  
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) {
        sendMessage({'type': 'ping'});
      }
    });
  }
  
  void _stopPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }
  
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;
    if (_currentDocumentId == null) return;
    
    _reconnectAttempts++;
    final delay = Duration(seconds: _calculateReconnectDelay());
    
    LoggerUtil.info('Scheduling reconnect in ${delay.inSeconds} seconds (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(delay, () {
      if (_currentDocumentId != null) {
        connectToDocument(_currentDocumentId!);
      }
    });
  }
  
  int _calculateReconnectDelay() {
    // Exponential backoff with max delay of 60 seconds
    return (2 * _reconnectAttempts).clamp(2, 60);
  }
  
  Future<void> disconnect() async {
    LoggerUtil.info('Disconnecting WebSocket');
    
    // Cancel timers
    _debounceTimer?.cancel();
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    
    // Save any pending content
    if (_pendingContent != null && _pendingContentType != null) {
      forceSave();
    }
    
    // Close WebSocket connection
    await _channel?.sink.close();
    _channel = null;
    
    _currentDocumentId = null;
    _isConnected = false;
    _reconnectAttempts = 0;
    _connectionStateController.add(false);
  }
  
  void dispose() {
    disconnect();
    _connectionStateController.close();
    _saveStatusController.close();
    _errorController.close();
    _documentUpdateController.close();
    _messageController.close();
  }
}

class SaveStatus {
  final bool success;
  final String timestamp;
  final bool isAutoSave;
  
  SaveStatus({
    required this.success,
    required this.timestamp,
    required this.isAutoSave,
  });
}

class DocumentUpdate {
  final String? userId;
  final String timestamp;
  
  DocumentUpdate({
    this.userId,
    required this.timestamp,
  });
} 