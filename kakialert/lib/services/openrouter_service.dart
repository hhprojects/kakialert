import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/incident_model.dart';

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

      // Extract TITLE
      final titleMatch = RegExp(r'TITLE:\s*(.+?)(?:\n|$)', multiLine: true).firstMatch(analysisText);
      if (titleMatch != null) {
        result['title'] = titleMatch.group(1)?.trim() ?? '';
      }

      // Extract DESCRIPTION
      final descriptionMatch = RegExp(r'DESCRIPTION:\s*(.+?)(?:\n|$)', multiLine: true).firstMatch(analysisText);
      if (descriptionMatch != null) {
        result['description'] = descriptionMatch.group(1)?.trim() ?? '';
      }

    } catch (e) {
      print('Error parsing analysis response: $e');
    }

    return result;
  }

  // Validate if images actually show an incident
  Future<Map<String, dynamic>> validateIncidentImages({
    required List<String> imagePaths,
    String model = 'openai/gpt-4o-mini',
  }) async {
    try {
      if (imagePaths.isEmpty) {
        throw Exception('No images provided for validation');
      }

      // Convert images to base64
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

      // Build validation prompt
      List<Map<String, dynamic>> content = [
        {
          'type': 'text',
          'text': '''You are an AI content moderator for an emergency incident reporting system. Your job is to determine if the submitted images show genuine incidents that warrant emergency response or community awareness.

TASK: Analyze the provided images and determine if they show a legitimate incident.

LEGITIMATE INCIDENTS include:
- Medical emergencies (injuries, accidents, health crises)
- Fires or smoke (building fires, vehicle fires, hazardous smoke)
- Traffic accidents (vehicle collisions, road incidents)
- Violence or crime (fights, vandalism, suspicious activity)
- Rescue situations (people trapped, emergency evacuations)
- Infrastructure issues (flooding, building damage, power outages)
- Public safety concerns (dangerous conditions, hazards)
- MRT/transport disruptions (train breakdowns, platform incidents)

NON-INCIDENTS include:
- Everyday photos (selfies, food, landscapes, buildings)
- Social media content (memes, screenshots, random photos)
- Normal activities (people walking, traffic, construction)
- Weather photos (unless showing dangerous conditions)
- Test images or inappropriate content
- Old news screenshots or downloaded images
- Promotional or advertising content

ANALYSIS CRITERIA:
1. Does the image show clear signs of an emergency, danger, or unusual situation?
2. Would this require immediate attention from authorities or community awareness?
3. Is there visible evidence of damage, injury, hazard, or disruption?
4. Are there emergency vehicles, responders, or concerned people present?

Respond with this exact format:

VALIDATION: [VALID/INVALID]
CONFIDENCE: [High/Medium/Low]
REASON: [Brief explanation of why this is/isn't a legitimate incident]
DETECTED_ELEMENTS: [List key elements you see that support your decision]
RECOMMENDATIONS: [If invalid, suggest what type of content this appears to be]

Be strict but fair. If in doubt and the image could reasonably be an incident, err on the side of VALID.'''
        },
        ...imageContent,
      ];

      final requestBody = {
        'model': model,
        'messages': [
          {
            'role': 'user',
            'content': content,
          }
        ],
        'max_tokens': 500,
        'temperature': 0.3, // Lower temperature for more consistent validation
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
        final validationText = data['choices'][0]['message']['content'];
        
        // Parse the validation response
        return _parseValidationResponse(validationText);
      } else {
        final errorData = json.decode(response.body);
        throw Exception('API Error: ${errorData['error']['message']}');
      }
    } catch (e) {
      throw Exception('Error validating incident images: $e');
    }
  }

  // Parse the AI validation response
  Map<String, dynamic> _parseValidationResponse(String validationText) {
    Map<String, dynamic> result = {
      'isValid': false,
      'confidence': 'Low',
      'reason': 'Failed to parse AI response',
      'detectedElements': <String>[],
      'recommendations': '',
      'rawResponse': validationText,
    };

    try {
      // Extract VALIDATION
      final validationMatch = RegExp(r'VALIDATION:\s*(VALID|INVALID)', multiLine: true, caseSensitive: false)
          .firstMatch(validationText);
      if (validationMatch != null) {
        result['isValid'] = validationMatch.group(1)?.toUpperCase() == 'VALID';
      }

      // Extract CONFIDENCE
      final confidenceMatch = RegExp(r'CONFIDENCE:\s*(High|Medium|Low)', multiLine: true, caseSensitive: false)
          .firstMatch(validationText);
      if (confidenceMatch != null) {
        result['confidence'] = confidenceMatch.group(1) ?? 'Low';
      }

      // Extract REASON
      final reasonMatch = RegExp(r'REASON:\s*(.+?)(?=\n[A-Z]+:|$)', multiLine: true, dotAll: true)
          .firstMatch(validationText);
      if (reasonMatch != null) {
        result['reason'] = reasonMatch.group(1)?.trim() ?? 'No reason provided';
      }

      // Extract DETECTED_ELEMENTS
      final elementsMatch = RegExp(r'DETECTED_ELEMENTS:\s*(.+?)(?=\n[A-Z]+:|$)', multiLine: true, dotAll: true)
          .firstMatch(validationText);
      if (elementsMatch != null) {
        final elementsText = elementsMatch.group(1)?.trim() ?? '';
        result['detectedElements'] = elementsText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      // Extract RECOMMENDATIONS
      final recommendationsMatch = RegExp(r'RECOMMENDATIONS:\s*(.+?)(?=\n[A-Z]+:|$)', multiLine: true, dotAll: true)
          .firstMatch(validationText);
      if (recommendationsMatch != null) {
        result['recommendations'] = recommendationsMatch.group(1)?.trim() ?? '';
      }

    } catch (e) {
      print('Error parsing validation response: $e');
    }

    return result;
  }

  /// Compare similarity between two incidents
  Future<Map<String, dynamic>> compareIncidentSimilarity({
    required Incident incident1,
    required Incident incident2,
  }) async {
    try {
      // Prepare content for comparison
      List<Map<String, dynamic>> content = [
        {
          'type': 'text',
          'text': '''Compare these two incident reports and determine if they are describing the same event:

INCIDENT 1:
Type: ${incident1.incident}
Location: ${incident1.location}
Description: ${incident1.description}
Time: ${incident1.datetime?.toIso8601String() ?? 'Unknown'}

INCIDENT 2:
Type: ${incident2.incident}
Location: ${incident2.location}
Description: ${incident2.description}
Time: ${incident2.datetime?.toIso8601String() ?? 'Unknown'}

Analyze these factors:
1. Are they describing the same type of incident?
2. Are the locations similar or the same?
3. Are the descriptions talking about the same event?
4. Are the timestamps close enough to be the same incident?
5. Do any unique identifiers match (vehicle plates, building names, etc.)?

Respond with this exact format:
SIMILARITY: [0.0 to 1.0 - how similar they are]
SAME_INCIDENT: [YES/NO - are they the same incident?]
CONFIDENCE: [High/Medium/Low]
REASONING: [Brief explanation of why they are/aren't the same]
KEY_FACTORS: [List the main factors that influenced your decision]'''
        }
      ];

      final requestBody = {
        'model': 'openai/gpt-4o-mini',
        'messages': [
          {
            'role': 'user',
            'content': content,
          }
        ],
        'max_tokens': 400,
        'temperature': 0.1, // Very low temperature for consistent analysis
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
        final analysisText = data['choices'][0]['message']['content'];
        
        return _parseSimilarityResponse(analysisText);
      } else {
        throw Exception('API Error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error comparing incident similarity: $e');
    }
  }

  /// Parse the AI similarity response
  Map<String, dynamic> _parseSimilarityResponse(String analysisText) {
    Map<String, dynamic> result = {
      'similarity': 0.0,
      'sameIncident': false,
      'confidence': 'Low',
      'reasoning': 'Failed to parse response',
      'keyFactors': <String>[],
    };

    try {
      // Extract similarity score
      final similarityMatch = RegExp(r'SIMILARITY:\s*([0-9.]+)').firstMatch(analysisText);
      if (similarityMatch != null) {
        result['similarity'] = double.tryParse(similarityMatch.group(1) ?? '0') ?? 0.0;
      }

      // Extract same incident determination
      final sameIncidentMatch = RegExp(r'SAME_INCIDENT:\s*(YES|NO)', caseSensitive: false)
          .firstMatch(analysisText);
      if (sameIncidentMatch != null) {
        result['sameIncident'] = sameIncidentMatch.group(1)?.toUpperCase() == 'YES';
      }

      // Extract confidence
      final confidenceMatch = RegExp(r'CONFIDENCE:\s*(High|Medium|Low)', caseSensitive: false)
          .firstMatch(analysisText);
      if (confidenceMatch != null) {
        result['confidence'] = confidenceMatch.group(1) ?? 'Low';
      }

      // Extract reasoning
      final reasoningMatch = RegExp(r'REASONING:\s*(.+?)(?=\nKEY_FACTORS:|$)', dotAll: true)
          .firstMatch(analysisText);
      if (reasoningMatch != null) {
        result['reasoning'] = reasoningMatch.group(1)?.trim() ?? '';
      }

      // Extract key factors
      final factorsMatch = RegExp(r'KEY_FACTORS:\s*(.+?)$', dotAll: true)
          .firstMatch(analysisText);
      if (factorsMatch != null) {
        final factorsText = factorsMatch.group(1)?.trim() ?? '';
        result['keyFactors'] = factorsText
            .split('\n')
            .map((line) => line.replaceAll(RegExp(r'^[•\-*]\s*'), '').trim())
            .where((line) => line.isNotEmpty)
            .toList();
      }

    } catch (e) {
      print('Error parsing similarity response: $e');
    }

    return result;
  }
}
