// ignore_for_file: library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewProgressStudentPage extends StatefulWidget {
  const ViewProgressStudentPage({super.key, String? studentId});

  @override
  _ViewProgressStudentPageState createState() => _ViewProgressStudentPageState();
}

class _ViewProgressStudentPageState extends State<ViewProgressStudentPage> {
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref().child('Student');
  final DatabaseReference _progressRef = FirebaseDatabase.instance.ref().child('Progress');
  final DatabaseReference _subjectRef = FirebaseDatabase.instance.ref().child('Subject');

  String _selectedSubject = 'Choose Subject';
  String _fullName = '';
  String _selectedStudentId = '';
  String? _selectedStudentEmail;
  Map<String, String> studentNames = {};
  List<Map<String, String>> subjects = [];
  Map<String, Map<String, String>> studentsProgress = {};
  List<String> studentEmails = [];

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
    _fetchStudentEmails();
  }

  Future<void> _fetchSubjects() async {
    try {
      final snapshot = await _subjectRef.get();
      if (snapshot.exists) {
        final subjectData = snapshot.value as Map<Object?, Object?>?;
        if (subjectData != null) {
          setState(() {
            subjects = [
              {'id': 'Choose Subject', 'name': 'Choose Subject'}
            ] + subjectData.entries.map((entry) {
              final subjectMap = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
              return {
                'id': entry.key?.toString() ?? 'Unknown',
                'name': subjectMap['name']?.toString() ?? 'Unknown',
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching subjects: $e');
    }
  }

  Future<void> _fetchStudentEmails() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final snapshot = await _userRef.get();
        if (snapshot.exists) {
          final studentData = snapshot.value as Map<Object?, Object?>?;
          if (studentData != null) {
            List<String> emails = [];
            studentData.forEach((key, value) {
              final student = Map<String, dynamic>.from(value as Map<Object?, Object?>);
              if (student['parentEmail'] == user.email) {
                emails.add(student['email']);
                studentNames[student['email']] = student['fullName'];
              }
            });
            setState(() {
              studentEmails = emails;
            });
          }
        }
      }
    } catch (e) {
      print('Error fetching student emails: $e');
    }
  }

  Future<String?> _getStudentIdByEmail(String email) async {
    try {
      final snapshot = await _userRef.get();
      if (snapshot.exists) {
        final studentData = snapshot.value as Map<Object?, Object?>?;
        if (studentData != null) {
          for (var entry in studentData.entries) {
            final student = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
            if (student['email'] == email) {
              return entry.key.toString();
            }
          }
        }
      }
    } catch (e) {
      print('Error getting student ID: $e');
    }
    return null;
  }

  Future<void> _fetchStudentProgressBySubject(String subjectId) async {
    if (_selectedStudentId.isEmpty) return; // Ensure student ID is set

    try {
      final snapshot = await _progressRef
          .orderByChild('studentId')
          .equalTo(_selectedStudentId)
          .get();

      if (snapshot.exists) {
        final progressData = snapshot.value as Map<Object?, Object?>;
        print('Progress Data for Student ID $_selectedStudentId: $progressData'); // Debugging output

        final filteredProgress = progressData.entries.fold<Map<String, Map<String, String>>>(
          {},
          (map, entry) {
            final progress = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
            print('Checking progress entry: $progress'); // Debugging output

            // Check if the progress entry matches the subjectId
            if (progress['subjectId'] == subjectId) {
              final studentId = progress['studentId'] ?? '-';
              if (!map.containsKey(studentId)) {
                map[studentId] = {
                  'UP1': '-',
                  'PPT': '-',
                  'UP2': '-',
                  'PAT': '-',
                  'PUPK': '-',
                };
              }
              // Update the progress for the corresponding exam description
              String examDescription = progress['examDescription'] ?? '';
              String score = progress['score']?.toString() ?? '0'; // Use score instead of percentage

              // Store the score for the exam description
              map[studentId]![examDescription] = score;
            }
            return map;
          },
        );

        setState(() {
          studentsProgress = filteredProgress; // Update state with fetched data
          if (studentsProgress.isEmpty) {
            print('No progress data available for the selected subject.'); // Debugging output
          }
        });
      } else {
        print('No progress data found for student ID: $_selectedStudentId'); // Debugging output
      }
    } catch (e) {
      print('Error fetching student progress: $e');
    }
  }

  Widget _buildGraph() {
    if (studentsProgress.isEmpty) return Container();

    // Define exam types and their indices
    final examTypes = ['UP1', 'PPT', 'UP2', 'PAT', 'PUPK'];
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFFC107), // Amber
      const Color(0xFFE91E63), // Pink
      const Color(0xFF9C27B0), // Purple
    ];

    final dataEntries = examTypes.asMap().entries.map((entry) {
      final index = entry.key;
      final examType = entry.value;
      
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: double.tryParse(studentsProgress.values.first[examType] ?? '0') ?? 0,
            color: colors[index % colors.length],
            width: 20,
            borderRadius: BorderRadius.circular(4),
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: 100,
              color: Colors.grey[200],
            ),
          ),
        ],
      );
    }).toList();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Exam Performance',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 400,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barGroups: dataEntries,
                  gridData: FlGridData(
                    show: true,
                    drawHorizontalLine: true,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey[300],
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        reservedSize: 40,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index >= 0 && index < examTypes.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                examTypes[index],
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          return const Text('');
                        },
                        reservedSize: 40,
                      ),
                    ),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final examType = examTypes[group.x.toInt()];
                        final value = rod.toY.round();
                        return BarTooltipItem(
                          '$examType\n$value%',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add helper functions for grade and color
  String _getGradeText(String? scoreStr) {
    final score = double.tryParse(scoreStr ?? '0') ?? 0;
    if (score >= 80 && score <= 100) {
      return 'A';
    } else if (score >= 60 && score < 80) {
      return 'B';
    } else if (score >= 40 && score < 60) {
      return 'C';
    } else if (score >= 1 && score < 40) {
      return 'D';
    } else {
      return 'N/A';
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.blue;
    if (score >= 40) return Colors.orange;
    return Colors.red;
  }

  Widget _buildDataTable() {
    if (studentsProgress.isEmpty) return Container();

    final examTypes = ['UP1', 'PPT', 'UP2', 'PAT', 'PUPK'];

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Scores',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Theme(
                data: Theme.of(context).copyWith(
                  dataTableTheme: DataTableThemeData(
                    headingTextStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    dataTextStyle: const TextStyle(
                      color: Colors.black87,
                      fontSize: 14,
                    ),
                    headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                  ),
                ),
                child: DataTable(
                  columnSpacing: 24,
                  horizontalMargin: 12,
                  columns: examTypes.map((type) => DataColumn(
                    label: Container(
                      alignment: Alignment.center,
                      width: 100,
                      child: Text(
                        type,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )).toList(),
                  rows: studentsProgress.entries.map((entry) {
                    return DataRow(
                      cells: examTypes.map((type) => DataCell(
                        Container(
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: _getScoreColor(double.tryParse(entry.value[type] ?? '0') ?? 0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  entry.value[type] ?? '-',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _getGradeText(entry.value[type]),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      )).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
            'View Student Progress',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Student Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              value: _selectedStudentEmail,
              items: studentEmails.map((String email) {
                return DropdownMenuItem<String>(
                  value: email,
                  child: Text(email),
                );
              }).toList(),
              onChanged: (String? newValue) async {
                if (newValue != null) {
                  final studentId = await _getStudentIdByEmail(newValue);
                  setState(() {
                    _selectedStudentEmail = newValue;
                    _fullName = studentNames[newValue] ?? '';
                    _selectedStudentId = studentId ?? '';
                    studentsProgress = {}; // Clear previous progress
                  });
                }
              },
            ),
            const SizedBox(height: 16.0),
            if (_fullName.isNotEmpty && _selectedStudentId.isNotEmpty) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Full Name:\n${studentNames[_selectedStudentEmail] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Choose Subject',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                value: _selectedSubject,
                items: subjects.map((subject) {
                  return DropdownMenuItem<String>(
                    value: subject['id'],
                    child: Text(subject['name'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedSubject = value!;
                    if (_selectedSubject != 'Choose Subject') {
                      _fetchStudentProgressBySubject(_selectedSubject);
                    } else {
                      studentsProgress = {}; // Clear progress if no subject is selected
                    }
                  });
                },
              ),
              const SizedBox(height: 16.0),
              if (studentsProgress.isNotEmpty) _buildGraph(),
              if (studentsProgress.isNotEmpty) _buildDataTable(),
              if (studentsProgress.isEmpty) const Center(child: Text('No data available for the selected subject.')),
            ],
          ],
        ),
      ),
    );
  }
}