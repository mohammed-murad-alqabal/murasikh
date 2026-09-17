with open("frontend/lib/services/api_service.dart", "r") as f:
    content = f.read()

submit_rating_method = """
  /// إرسال تقييم التطبيق
  Future<void> submitRating(int rating, String? feedback) async {
    final headers = await getHeaders();
    final body = <String, dynamic>{'rating': rating};
    if (feedback != null && feedback.isNotEmpty) {
      body['feedback'] = feedback;
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/home/rating'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to submit rating: ${response.statusCode}');
    }
  }
"""

# Insert before  // ============================================================
insert_index = content.find("  // ============================================================")
if insert_index != -1:
    new_content = content[:insert_index] + submit_rating_method + "\n" + content[insert_index:]
    with open("frontend/lib/services/api_service.dart", "w") as f:
        f.write(new_content)
else:
    print("Could not find insertion point in api_service.dart")
