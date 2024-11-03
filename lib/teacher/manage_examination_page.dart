// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'add_exam_page.dart';
import 'add_exam_subject_page.dart';
import 'edit_exam_page.dart';
import 'enter_score_page.dart';
import '../pdf_viewer_page.dart';

class ManageExaminationPage extends StatefulWidget {
  const ManageExaminationPage({super.key});

  @override
  _ManageExaminationPageState createState() => _ManageExaminationPageState();
}

class _ManageExaminationPageState extends State<ManageExaminationPage> {
  final DatabaseReference _examRef = FirebaseDatabase.instance.ref().child('Exam');

  List<Map<String, dynamic>> examinations = [];
  List<Map<String, dynamic>> filteredExaminations = []; // List for filtered examinations
  String searchQuery = ''; // Search query

  @override
  void initState() {
    super.initState();
    _fetchExaminations();
  }

  Future<void> _fetchExaminations() async {
    try {
      final snapshot = await _examRef.get();
      if (snapshot.exists) {
        final examData = snapshot.value as Map<Object?, Object?>?;
        if (examData != null) {
          setState(() {
            examinations = examData.entries.map((entry) {
              final examMap = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
              return {
                'key': entry.key,
                ...examMap,
              };
            }).toList();
            filteredExaminations = List.from(examinations); // Initialize filtered list with all examinations
          });
        }
      }
    } catch (e) {
      print('Error fetching examinations: $e');
    }
  }

  void _filterExaminations(String query) {
    setState(() {
      searchQuery = query;
      filteredExaminations = examinations.where((exam) {
        final title = exam['title']?.toLowerCase() ?? '';
        return title.contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.pinkAccent,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(
          padding: const EdgeInsets.only(right: 48.0),
          alignment: Alignment.center,
          child: const Text(
            'Manage Examination',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                minimumSize: const Size(double.infinity, 50), // Make the button take the full width
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AddExamPage()),
                ).then((_) => _fetchExaminations());
              },
              child: const Text(
                'Add New Exam',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16.0),
            child: Text('List of Examinations', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 16),

          // Search bar for filtering examinations
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              onChanged: _filterExaminations,
              decoration: InputDecoration(
                labelText: 'Search Examination',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                prefixIcon: const Icon(Icons.search),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: filteredExaminations.length,
              itemBuilder: (context, index) {
                final exam = filteredExaminations[index];
                return Card(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent), // This removes the line
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16.0), // Add padding here
                      childrenPadding: EdgeInsets.zero, // Remove padding around children
                      title: Text(
                        exam['title'] ?? 'No Title',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color.fromARGB(255, 32, 32, 32),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0), // Add a little space between title and subtitle
                        child: Text(
                          exam['description'] ?? 'No Description',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color.fromARGB(179, 63, 61, 61),
                          ),
                        ),
                      ),
                      children: [
                        ListTile(
                          title: const Text('Enter Scores'),
                          trailing: const Icon(Icons.edit),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EnterScorePage(examId: exam['key']),
                              ),
                            );
                          },
                        ),
                        if (exam['subjects'] != null)
                          ...exam['subjects'].entries.map((entry) {
                            final subjectKey = entry.key;
                            final subjectData = entry.value as Map<dynamic, dynamic>?;
                            final subjectTitle = subjectData?['title'] as String? ?? 'No Title';
                            final fileUrl = subjectData?['fileUrl'] as String? ?? '';

                            return ListTile(
                              title: Text(subjectTitle),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_red_eye, color: Colors.blue),
                                    onPressed: () {
                                      if (fileUrl.isNotEmpty) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PDFViewerPage(fileUrl: fileUrl),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit, color: Colors.green),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => EditExamPage(examId: exam['key'], subjectId: subjectKey),
                                        ),
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () {
                                      _examRef.child(exam['key']).child('subjects').child(subjectKey).remove();
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ListTile(
                          title: const Text('Add Subject'),
                          trailing: const Icon(Icons.add),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddExamSubjectPage(examId: exam['key']),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
