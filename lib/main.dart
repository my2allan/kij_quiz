import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: EmailScreen(),
    );
  }
}

class EmailScreen extends StatefulWidget {
  @override
  _EmailScreenState createState() => _EmailScreenState();
}

class _EmailScreenState extends State<EmailScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(
      r'^[^@]+@kijaniforestry\.com$',
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address ending with @kijaniforestry.com';
    }
    return null;
  }

  void _submitEmail() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SurveyScreen(email: _emailController.text),
        ),
      ).then((value) => _emailController.clear());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Enter Your Email'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: _validateEmail,
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitEmail,
                child: Text('Submit'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SurveyScreen extends StatefulWidget {
  final String email;

  SurveyScreen({required this.email});

  @override
  _SurveyScreenState createState() => _SurveyScreenState();
}

class _SurveyScreenState extends State<SurveyScreen> {
  int _currentQuestion = 0;
  bool _isLoading = true;
  bool _hasError = false;
  List<Map<String, dynamic>> _questions = [];

  @override
  void initState() {
    super.initState();
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await http.get(Uri.parse(
          'https://kijani.store/end_p/get_questions.php?email=${widget.email}'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _questions = data.map((question) {
            return {
              'question_id': question['question_id'],
              'question_text': question['question_text'],
              'answers': (question['options'] as List<dynamic>)
                  .map((option) => {
                        'option_id': option['option_id'],
                        'option_text': option['option_text'],
                      })
                  .toList(),
              'selectedAnswer': null,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load questions');
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      print(e);
    }
  }

  void _handleAnswerSelected(int selectedIndex) {
    setState(() {
      _questions[_currentQuestion]['selectedAnswer'] = selectedIndex;
    });
  }

  void _nextQuestion() {
    if (_currentQuestion < _questions.length - 1) {
      setState(() {
        _currentQuestion++;
      });
    } else {
      _endSurvey();
    }
  }

  void _endSurvey() async {
    await _submitSurvey();
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => EmailScreen()),
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _submitSurvey() async {
    final answers = {
      for (var q in _questions)
        q['question_id'].toString(): q['selectedAnswer'] != null
            ? q['answers'][q['selectedAnswer']]['option_id']
            : null
    };

    try {
      final response = await http.post(
        Uri.parse('https://kijani.store/end_p/app_submit_survey.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': widget.email,
          'answers': answers,
        }),
      );

      if (response.statusCode != 200) {
        print('Failed to submit survey');
      }
    } catch (e) {
      print(e);
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Nursery Management Quiz'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Failed to load questions. Please try again.'),
                      SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _fetchQuestions,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        _questions[_currentQuestion]['question_text'],
                        style: TextStyle(fontSize: 18.0),
                      ),
                      SizedBox(height: 10.0),
                      ListView.builder(
                        shrinkWrap: true,
                        itemCount:
                            _questions[_currentQuestion]['answers'].length,
                        itemBuilder: (context, index) {
                          return RadioListTile(
                            title: Text(_questions[_currentQuestion]['answers']
                                [index]['option_text']),
                            value: index,
                            groupValue: _questions[_currentQuestion]
                                ['selectedAnswer'],
                            onChanged: (value) {
                              _handleAnswerSelected(value as int);
                            },
                          );
                        },
                      ),
                      if (_currentQuestion < _questions.length - 1)
                        ElevatedButton(
                          onPressed: _nextQuestion,
                          child: Text('Next Question'),
                        ),
                      if (_currentQuestion == _questions.length - 1)
                        ElevatedButton(
                          onPressed: _endSurvey,
                          child: Text('End Survey'),
                        ),
                    ],
                  ),
                ),
    );
  }
}
