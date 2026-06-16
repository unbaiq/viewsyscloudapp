import 'package:http/http.dart' as http;

void main() async {
  try {
    final url = Uri.parse('https://viewsys.co.in/api/player/schedule?screen_id=51');
    print('Requesting: $url');
    final response = await http.get(
      url,
      headers: {'Accept': 'application/json'},
    );
    print('Status Code: ${response.statusCode}');
    print('Response Body:\n${response.body}');
  } catch (e) {
    print('Error: $e');
  }
}
