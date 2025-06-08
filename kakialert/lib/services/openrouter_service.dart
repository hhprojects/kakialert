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

  // Analyze multiple images for incident reporting
  Future<Map<String, String>> analyzeIncidentImages({
    required List<String> imagePaths,
    String model = 'openai/gpt-4o-mini',
  }) async {
    try {
      if (imagePaths.isEmpty) {
        throw Exception('No images provided for analysis');
      }

      // Convert images to base64 (no video filtering needed)
      List<Map<String, dynamic>> imageContent = [];
      
      for (String imagePath in imagePaths) {
        final bytes = await File(imagePath).readAsBytes();
        final base64Image = base64Encode(bytes);
        imageContent.add({
          'type': 'image_url',
          'image_url': {
            'url': 'data:image/jpeg;base64,$base64Image',
          },
        });
      }

      // Build content array with prompt and images
      List<Map<String, dynamic>> content = [
        {
          'type': 'text',
          'text': '''You are an AI assistant that helps create engaging social media-style incident reports. Analyze the provided images and answer the following three questions with responses that sound natural and engaging.

CONTEXT: You're creating posts for a community incident reporting app. The content should be relatable, engaging, and encourage people to comment or react - similar to Reddit posts or viral tweets.

INSTRUCTIONS: 
Look at the images carefully and provide answers that would get people talking and sharing.

---

1. INCIDENT SUBJECT CLASSIFICATION
Based on what you see, pick the category that best fits:
- Medical: Health emergencies, injuries, medical situations, ambulance responses
- Fire: Fires, smoke, fire damage, fire department responses  
- Accident: Vehicle accidents, workplace accidents, falls, collisions
- Violence: Physical altercations, vandalism, criminal activity, security incidents
- Rescue: Search and rescue operations, people trapped, emergency evacuations
- HDB Facilities: Public housing issues, building maintenance, infrastructure problems, utility failures
- MRT: Train delays, breakdowns, platform incidents, railway-related issues
- Others: Any incident that doesn't fit the above categories

Answer format: "SUBJECT: [selected category]"

---

2. CATCHY INCIDENT TITLE
Write a compelling title that would make people want to click and read more. Think social media headlines that grab attention:
- Keep it 3-8 words
- Make it dramatic but not clickbait
- Use everyday language people actually use
- Focus on the most shocking or interesting aspect

Examples of good titles:
- "Massive fire breaks out downtown"
- "Car crashes into storefront"
- "Flood turns street into river"
- "Construction accident blocks traffic"

Answer format: "TITLE: [your catchy title]"

---

3. ENGAGING DESCRIPTION
Write a description that reads like someone posting on social media who witnessed the event. Make it:
- Conversational and relatable
- Include what you'd naturally notice and mention
- Sound like you're telling a friend what happened
- Use casual language but stay informative
- End with something that invites comments or reactions
- 2-4 sentences max

Examples of good descriptions:
- "Just saw this huge fire at the apartment complex on Main St. Firefighters are everywhere and you can see the smoke from blocks away! Hope everyone got out safely 🙏"
- "This car just plowed straight into the coffee shop window. Glass everywhere and the whole front is destroyed. Anyone know if the driver is okay?"
- "The whole street is flooded from that broken water main. Cars are literally floating and people are wading through knee-deep water. Wild scene!"

Answer format: "DESCRIPTION: [your engaging description]"

---

IMPORTANT:
- Write naturally like a real person would post
- NO asterisks, bullet points, or formal formatting
- Use everyday language and contractions
- Make it sound authentic and engaging
- Focus on what would make people care and want to comment

Analyze the images now and create your social media-style report.''',
        },
        ...imageContent,
      ];

      final requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': content,
          },
        ],
        'max_tokens': 1500,
        'temperature': 0.3, // Lower temperature for more consistent analysis
      };

      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
          'HTTP-Referer': 'KakiAlert-App',
          'X-Title': 'KakiAlert Incident Analysis',
        },
        body: json.encode(requestBody),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final analysisText = data['choices'][0]['message']['content'];
        
        // Parse the structured response
        return _parseAnalysisResponse(analysisText);
      } else {
        final errorData = json.decode(response.body);
        throw Exception('API Error: ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('Error analyzing incident images: $e');
    }
  }

  // Parse the AI response to extract subject, title, and description
  Map<String, String> _parseAnalysisResponse(String analysisText) {
    Map<String, String> result = {
      'subject': '',
      'title': '',
      'description': '',
    };

    try {
      // Extract SUBJECT
      final subjectMatch = RegExp(r'SUBJECT:\s*(.+?)(?:\n|$)', multiLine: true).firstMatch(analysisText);
      if (subjectMatch != null) {
        String subject = subjectMatch.group(1)?.trim() ?? '';
        // Convert to lowercase ID format
        subject = subject.toLowerCase().replaceAll(' ', '_');
        // Map to our subject IDs
        if (subject.contains('medical')) {
          result['subject'] = 'medical';
        } else if (subject.contains('fire')) {
          result['subject'] = 'fire';
        } else if (subject.contains('accident')) {
          result['subject'] = 'accident';
        } else if (subject.contains('violence')) {
          result['subject'] = 'violence';
        } else if (subject.contains('rescue')) {
          result['subject'] = 'rescue';
        } else if (subject.contains('hdb') || subject.contains('facilities')) {
          result['subject'] = 'hdb_facilities';
        } else if (subject.contains('mrt') || subject.contains('train')) {
          result['subject'] = 'mrt';
        } else {
          result['subject'] = 'others';
        }
      }

      // Extract TITLE and clean formatting
      final titleMatch = RegExp(r'TITLE:\s*(.+?)(?:\n|$)', multiLine: true).firstMatch(analysisText);
      if (titleMatch != null) {
        String title = titleMatch.group(1)?.trim() ?? '';
        // Remove asterisks, quotes, and other formatting characters
        title = title.replaceAll('*', '').replaceAll('"', '').replaceAll("'", '').replaceAll('`', '').trim();
        result['title'] = title;
      }

      // Extract DESCRIPTION and clean formatting
      final descriptionMatch = RegExp(r'DESCRIPTION:\s*(.+?)(?:\n\n|$)', multiLine: true, dotAll: true).firstMatch(analysisText);
      if (descriptionMatch != null) {
        String description = descriptionMatch.group(1)?.trim() ?? '';
        // Remove asterisks, markdown formatting, and extra whitespace
        description = description
            .replaceAll('*', '') // Remove asterisks
            .replaceAll('_', '') // Remove underscores
            .replaceAll('`', '') // Remove backticks
            .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
            .trim();
        result['description'] = description;
      }

      return result;
    } catch (e) {
      print('Error parsing analysis response: $e');
      // Return partial results or defaults
      return {
        'subject': 'others',
        'title': 'Something happening here',
        'description': 'Check out what I just saw! Anyone know more details?',
      };
    }
  }
}
