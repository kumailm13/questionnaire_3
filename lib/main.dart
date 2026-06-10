import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:whatsapp_unilink/whatsapp_unilink.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Initialize Firebase
  runApp(MyApp()); // Start the app
}

Future<void> shareToWhatsApp(BuildContext context, String message) async {
  final link = WhatsAppUnilink(text: message);
  try {
    print('Trying to launch WhatsApp with message: $message');
    await launchUrl(link.asUri(), mode: LaunchMode.externalApplication);
  } catch (e) {
    print('Error: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('WhatsApp not installed or cannot be launched')),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Group Questionnaire',
      theme: ThemeData(
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.teal,
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 20),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.teal,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          labelStyle: TextStyle(color: Colors.white), // Label text in white
          hintStyle: TextStyle(color: Colors.grey[500]), // Hint text in grey
          enabledBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.white), // Border for enabled state
            borderRadius: BorderRadius.circular(12),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: Colors.teal, width: 2.0), // Border for focused state
            borderRadius: BorderRadius.circular(12),
          ),
          filled: true, // Enable background fill
          fillColor: Colors.grey[800], // Dark background for text fields
          contentPadding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 12.0),
        ),
      ),
      home: GroupHomeScreen(), // Home screen of the app
    );
  }
}

class GroupHomeScreen extends StatefulWidget {
  const GroupHomeScreen({super.key});

  @override
  _GroupHomeScreenState createState() => _GroupHomeScreenState();
}

class _GroupHomeScreenState extends State<GroupHomeScreen> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance; // Firestore instance
  final TextEditingController groupCodeController =
      TextEditingController(); // Controller for group code input
  String currentGroupCode = ''; // Stores the current group code
  bool isGroupJoined = false; // Indicates whether the user has joined a group

  // Generate a random group code
  String generateShortGroupCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[Random().nextInt(chars.length)]).join();
  }

  // Create a new group and store it in Firestore
  Future<void> createGroup() async {
    String newGroupCode = generateShortGroupCode();
    await _firestore.collection('groups').doc(newGroupCode).set({
      'questions': [], // Initialize the group with an empty list of questions
    });
    setState(() {
      currentGroupCode = newGroupCode;
      isGroupJoined = true; // Mark that the group has been created and joined
    });
  }

  // Join an existing group
  Future<void> joinGroup(String groupCode) async {
    DocumentSnapshot groupDoc =
        await _firestore.collection('groups').doc(groupCode).get();
    if (groupDoc.exists) {
      setState(() {
        currentGroupCode = groupCode;
        isGroupJoined = true; // Successfully joined the group
      });
    } else {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Group not found')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: isGroupJoined
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () {
                  setState(() {
                    currentGroupCode = ''; // Reset the group code
                    isGroupJoined = false; // Mark as not joined
                  });
                },
              )
            : null,
        title: isGroupJoined
            ? GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(
                      text: currentGroupCode)); // Copy group code to clipboard
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Group Code Copied!')),
                  );
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Group Code: $currentGroupCode',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    Icon(Icons.copy, size: 16, color: Colors.white),
                    // Share button in the AppBar
                    IconButton(
                      icon: Icon(Icons.share, size: 16, color: Colors.white),
                      onPressed: () async {
                        String message = "Join my group on Group Questionnaire! Use the code: $currentGroupCode";
                        print('Share button pressed'); // Debug log
                        await shareToWhatsApp(context, message); // Call the share function
                      },
                    ),



                  ],
                ),
              )
            : Text('Groups'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isGroupJoined
            ? GroupQuestionScreen(
                groupCode: currentGroupCode) // Navigate to question screen if the group is joined
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: groupCodeController,
                    decoration: InputDecoration(
                      labelText: 'Enter Group Code',
                      hintText: 'e.g. ABC123',
                    ),
                    style: TextStyle(color: Colors.white),
                    cursorColor: Colors.teal,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      joinGroup(groupCodeController.text); // Join group by code
                    },
                    icon: Icon(Icons.group_add),
                    label: Text('Join Group'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton.icon(
                    onPressed: createGroup, // Create a new group
                    icon: Icon(Icons.add_circle),
                    label: Text('Create Group'),
                  ),
                ],
              ),
      ),
    );
  }
}

class GroupQuestionScreen extends StatefulWidget {
  final String groupCode;

  const GroupQuestionScreen({super.key, required this.groupCode});

  @override
  _GroupQuestionScreenState createState() => _GroupQuestionScreenState();
}

class _GroupQuestionScreenState extends State<GroupQuestionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController questionController = TextEditingController();
  final TextEditingController option1Controller = TextEditingController();
  final TextEditingController option2Controller = TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController commentController = TextEditingController();

  // Add a new question to the group
  Future<void> addQuestion() async {
    String question = questionController.text.trim();
    String option1 = option1Controller.text.trim();
    String option2 = option2Controller.text.trim();

    if (question.isEmpty || option1.isEmpty || option2.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please fill in all fields')));
      return;
    }

    await _firestore.collection('groups').doc(widget.groupCode).update({
      'questions': FieldValue.arrayUnion([
        {
          'questionText': question,
          'option1': option1,
          'option2': option2,
          'option1Votes': [],
          'option2Votes': [],
        }
      ])
    });

    questionController.clear();
    option1Controller.clear();
    option2Controller.clear();
  }

  // Cast a vote for a question
  Future<void> vote(int questionIndex, String option) async {
    String name = nameController.text.trim();
    String comment = commentController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Please enter your name')));
      return;
    }

    var groupDoc = await _firestore.collection('groups').doc(widget.groupCode).get();
    var questions = groupDoc['questions'];
    var question = questions[questionIndex];

    bool alreadyVoted =
        question['option1Votes'].any((vote) => vote['name'] == name) ||
            question['option2Votes'].any((vote) => vote['name'] == name);

    if (alreadyVoted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('You have already voted')));
      return;
    }

    String voteField = option == 'option1' ? 'option1Votes' : 'option2Votes';

    await _firestore.collection('groups').doc(widget.groupCode).update({
      'questions': FieldValue.arrayRemove([question]) // Remove old question data
    });

    question[voteField].add({
      'name': name,
      'comment': comment.isEmpty ? 'No comment' : comment,
    });

    await _firestore.collection('groups').doc(widget.groupCode).update({
      'questions': FieldValue.arrayUnion([question]) // Add updated question data with votes
    });

    nameController.clear();
    commentController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Group: ${widget.groupCode}')),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _firestore
                  .collection('groups')
                  .doc(widget.groupCode)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());

                var groupData = snapshot.data!.data() as Map<String, dynamic>;
                var questions = groupData['questions'] ?? [];

                return ListView.builder(
                  itemCount: questions.length,
                  itemBuilder: (context, index) {
                    var question = questions[index];
                    var option1Votes = question['option1Votes'];
                    var option2Votes = question['option2Votes'];

                    int totalVotes = option1Votes.length + option2Votes.length;
                    double option1Percentage = totalVotes == 0
                        ? 0
                        : (option1Votes.length / totalVotes) * 100;
                    double option2Percentage = totalVotes == 0
                        ? 0
                        : (option2Votes.length / totalVotes) * 100;

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(question['questionText'],
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18, color: Colors.teal)),
                            SizedBox(height: 8),
                            Text('Option 1: ${question['option1']}', style: TextStyle(color: Colors.teal)),
                            Text('Option 2: ${question['option2']}', style: TextStyle(color: Colors.teal)),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: option1Percentage / 100,
                                    backgroundColor: Colors.grey[600],
                                    color: Colors.teal,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('${option1Percentage.toStringAsFixed(1)}%', style: TextStyle(color: Colors.teal)),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: LinearProgressIndicator(
                                    value: option2Percentage / 100,
                                    backgroundColor: Colors.grey[600],
                                    color: Colors.yellow,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('${option2Percentage.toStringAsFixed(1)}%', style: TextStyle(color: Colors.teal)),
                              ],
                            ),
                            TextField(
                              controller: nameController,
                               style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Your Name',
                                hintText: 'Enter your name',
                              ),
                            ),
                            SizedBox(height: 8),
                            TextField(
                              controller: commentController,
                              style: TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Comment (Optional)',
                                hintText: 'Enter your comment',
                              ),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => vote(index, 'option1'),
                              child: Text('Vote for Option 1'),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => vote(index, 'option2'),
                              child: Text('Vote for Option 2'),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: questionController,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New Question',
                hintText: 'Enter a new question',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: option1Controller,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Option 1',
                hintText: 'Enter option 1',
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: option2Controller,
              style: TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Option 2',
                hintText: 'Enter option 2',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: addQuestion,
            child: Text('Add Question'),
          ),
        ],
      ),
    );
  }
}