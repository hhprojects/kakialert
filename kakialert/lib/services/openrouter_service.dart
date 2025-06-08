import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenRouterService {
  static const String _baseUrl = 'https://openrouter.ai/api/v1';
  late String _apiKey;
  
  OpenRouterService() {
    _apiKey = dotenv.env['OPENROUTER_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('OpenRouter API key not found in .env file');
    }
  }

  // Get list of available models
  Future<List<Map<String, dynamic>>> getAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/models'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data']);
      } else {
        throw Exception('Failed to fetch models: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching models: $e');
    }
  }

  // Send chat completion request
  Future<String> sendChatMessage({
    required String message,
    String model = 'gpt-3.5-turbo', // Default model
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
    int maxTokens = 1000,
  }) async {
    try {
      // Build messages array
      List<Map<String, String>> messages = [];
      
      // Add conversation history if provided
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }
      
      // Add current message
      messages.add({
        'role': 'user',
        'content': message,
      });

      final requestBody = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': false,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'your-app-name', // Optional: for OpenRouter stats
          'X-Title': 'Your App Name', // Optional: for OpenRouter stats
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        final errorData = json.decode(response.body);
        throw Exception('API Error: ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('Error sending message: $e');
    }
  }

  // Stream chat completion (real-time response)
  Stream<String> sendChatMessageStream({
    required String message,
    String model = 'gpt-3.5-turbo',
    List<Map<String, String>>? conversationHistory,
    double temperature = 0.7,
    int maxTokens = 1000,
  }) async* {
    try {
      List<Map<String, String>> messages = [];
      
      if (conversationHistory != null) {
        messages.addAll(conversationHistory);
      }
      
      messages.add({
        'role': 'user',
        'content': message,
      });

      final requestBody = {
        'model': model,
        'messages': messages,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true,
      };

      final request = http.Request('POST', Uri.parse('$_baseUrl/chat/completions'));
      request.headers.addAll({
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
        'HTTP-Referer': 'your-app-name',
        'X-Title': 'Your App Name',
      });
      request.body = json.encode(requestBody);

      final streamedResponse = await request.send();
      
      if (streamedResponse.statusCode == 200) {
        await for (final chunk in streamedResponse.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
          
          if (chunk.startsWith('data: ')) {
            final jsonData = chunk.substring(6);
            if (jsonData.trim() == '[DONE]') break;
            
            try {
              final data = json.decode(jsonData);
              final content = data['choices'][0]['delta']['content'];
              if (content != null) {
                yield content;
              }
            } catch (e) {
              // Skip malformed chunks
              continue;
            }
          }
        }
      } else {
        throw Exception('Stream Error: ${streamedResponse.statusCode}');
      }
    } catch (e) {
      throw Exception('Error streaming message: $e');
    }
  }

  Future<String> analyzeImage({
    required String imagePath,
    required String prompt,
    String model = 'openai/gpt-4-vision-preview',
  }) async {
    try {
      // Convert image to base64
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);
      
      final requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': prompt,
              },
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,$base64Image',
                },
              },
            ],
          },
        ],
        'max_tokens': 1000,
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['choices'][0]['message']['content'];
      } else {
        throw Exception('Failed to analyze image');
      }
    } catch (e) {
      throw Exception('Error analyzing image: $e');
    }
  }
}
