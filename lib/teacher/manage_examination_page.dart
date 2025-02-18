// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'add_exam_page.dart';
import 'add_exam_subject_page.dart';
import 'edit_exam_page.dart';
import 'enter_score_page.dart';
import '../pdf_viewer_page.dart';
import 'package:http/http.dart' as http;

class ManageExaminationPage extends StatefulWidget {
  const ManageExaminationPage({super.key});

  @override
  _ManageExaminationPageState createState() => _ManageExaminationPageState();
}

class _ManageExaminationPageState extends State<ManageExaminationPage> {
  final DatabaseReference _examRef = FirebaseDatabase.instance.ref().child('Exam');
  final DatabaseReference _progressRef = FirebaseDatabase.instance.ref().child('Progress');

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

  Future<void> _deleteExam(String examId) async {
    // Show confirmation dialog
    bool confirmDelete = await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Deletion'),
          content: const Text('Are you sure you want to delete this exam? All related progress records will also be deleted. This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirmDelete) return;

    try {
      // First, query and delete all progress entries related to this exam
      final progressSnapshot = await _progressRef
          .orderByChild('examId')
          .equalTo(examId)
          .get();

      if (progressSnapshot.exists) {
        final progressData = progressSnapshot.value as Map<Object?, Object?>;
        // Delete each progress entry
        for (var entry in progressData.entries) {
          await _progressRef.child(entry.key.toString()).remove();
        }
      }

      // Then delete the exam itself
      await _examRef.child(examId).remove();
      
      setState(() {
        examinations.removeWhere((exam) => exam['key'] == examId);
        filteredExaminations.removeWhere((exam) => exam['key'] == examId);
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Exam and related scores deleted successfully',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            bottom: 20,
            right: 20,
            left: 20,
            top: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      print('Error deleting exam: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Failed to delete exam and scores',
            style: TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            bottom: 20,
            right: 20,
            left: 20,
            top: 20,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C6B58),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Container(
          padding: const EdgeInsets.only(right: 48.0),
          alignment: Alignment.center,
          child: const Text(
            'Manage Examination',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh examination data
          await _fetchExaminations();
          return Future.delayed(const Duration(milliseconds: 500));
        },
        color: const Color(0xFF0C6B58),
        child: ListView(  // Changed from Column to ListView
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0C6B58),
                  minimumSize: const Size(double.infinity, 50),
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
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10.0),
                    borderSide: const BorderSide(color: Color(0xFF0C6B58)),
                  ),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF0C6B58)),
                ),
              ),
            ),

            const SizedBox(height: 16),
            
            filteredExaminations.isEmpty
                ? SizedBox(
                    height: MediaQuery.of(context).size.height - 300,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.assignment_outlined,
                            size: 70,
                            color: Colors.grey,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            searchQuery.isEmpty
                                ? 'No Exams Added'
                                : 'No Exams Found',
                            style: const TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: filteredExaminations.length,
                    padding: const EdgeInsets.all(16.0),
                    itemBuilder: (context, index) {
                      final exam = filteredExaminations[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16.0),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF0C6B58),
                              Color(0xFF094A3D),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 2,
                              blurRadius: 5,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _buildExamCard(exam),
                      );
                    },
                  ),
            // Add extra padding at the bottom
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExamCard(Map<String, dynamic> exam) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        colorScheme: ColorScheme.fromSwatch().copyWith(
          secondary: Colors.white,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: ExpansionTile(
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.quiz_outlined,
              color: Colors.white,
            ),
          ),
          title: Text(
            exam['title'] ?? 'No Title',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                exam['description'] ?? 'No Description',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.delete,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () => _deleteExam(exam['key']),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.expand_more,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          children: [
            Container(
              color: Colors.white.withOpacity(0.1),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.white),
                    title: const Text(
                      'Enter Scores',
                      style: TextStyle(color: Colors.white),
                    ),
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

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          border: Border(
                            top: BorderSide(color: Colors.white.withOpacity(0.1)),
                          ),
                        ),
                        child: ListTile(
                          title: Text(
                            subjectTitle,
                            style: const TextStyle(color: Colors.white),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_red_eye, color: Colors.white),
                                onPressed: () async {
                                  if (fileUrl.isNotEmpty) {
                                    try {
                                      // Show loading dialog
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (BuildContext context) {
                                          return const Center(
                                            child: CircularProgressIndicator(
                                              color: Color(0xFF0C6B58),
                                            ),
                                          );
                                        },
                                      );

                                      if (fileUrl.contains('firebasestorage.googleapis.com')) {
                                        // Add a timestamp to force URL refresh
                                        final refreshedUrl = '$fileUrl?t=${DateTime.now().millisecondsSinceEpoch}';
                                        
                                        if (!mounted) return;
                                        Navigator.pop(context); // Dismiss loading dialog
                                        
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => PDFViewerPage(fileUrl: refreshedUrl),
                                          ),
                                        );
                                      } else {
                                        // For other URLs, keep the existing verification
                                        final response = await http.head(Uri.parse(fileUrl));
                                        
                                        if (!mounted) return;
                                        Navigator.pop(context); // Dismiss loading dialog

                                        if (response.statusCode == 200) {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PDFViewerPage(fileUrl: fileUrl),
                                            ),
                                          );
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text(
                                                'PDF file is not accessible',
                                                style: TextStyle(color: Colors.white),
                                                textAlign: TextAlign.center,
                                              ),
                                              backgroundColor: Colors.red,
                                              behavior: SnackBarBehavior.floating,
                                              margin: const EdgeInsets.all(20),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                            ),
                                          );
                                        }
                                      }
                                    } catch (e) {
                                      if (!mounted) return;
                                      Navigator.pop(context); // Dismiss loading dialog
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text(
                                            'Error accessing PDF file',
                                            style: TextStyle(color: Colors.white),
                                            textAlign: TextAlign.center,
                                          ),
                                          backgroundColor: Colors.red,
                                          behavior: SnackBarBehavior.floating,
                                          margin: const EdgeInsets.all(20),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                      );
                                    }
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'No PDF file available',
                                          style: TextStyle(color: Colors.white),
                                          textAlign: TextAlign.center,
                                        ),
                                        backgroundColor: Colors.orange,
                                        behavior: SnackBarBehavior.floating,
                                        margin: const EdgeInsets.all(20),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditExamPage(
                                        examId: exam['key'],
                                        subjectId: subjectKey,
                                      ),
                                    ),
                                  ).then((_) => _fetchExaminations());
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.white),
                                onPressed: () {
                                  _examRef
                                      .child(exam['key'])
                                      .child('subjects')
                                      .child(subjectKey)
                                      .remove();
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ListTile(
                    leading: const Icon(Icons.add, color: Colors.white),
                    title: const Text(
                      'Add Subject',
                      style: TextStyle(color: Colors.white),
                    ),
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
          ],
        ),
      ),
    );
  }
}
