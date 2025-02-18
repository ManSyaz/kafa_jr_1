// ignore_for_file: library_private_types_in_public_api, prefer_final_fields

import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewAcademicRecordPage extends StatefulWidget {
  const ViewAcademicRecordPage({super.key, String? studentId});

  @override
  _ViewAcademicRecordPageState createState() => _ViewAcademicRecordPageState();
}

class _ViewAcademicRecordPageState extends State<ViewAcademicRecordPage> {
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref().child('Student');
  final DatabaseReference _progressRef = FirebaseDatabase.instance.ref().child('Progress');
  final DatabaseReference _examRef = FirebaseDatabase.instance.ref().child('Exam');
  final DatabaseReference _subjectRef = FirebaseDatabase.instance.ref().child('Subject');

  String _selectedExam = 'Choose Exam';
  String _fullName = '';
  String _selectedStudentId = '';
  String? _selectedStudentEmail;
  Map<String, String> studentNames = {};
  Map<String, String> subjectCodes = {};
  List<Map<String, String>> exams = [];
  Map<String, Map<String, String>> studentsProgress = {};
  Map<String, Map<String, String>> studentProgressByExam = {};
  List<String> studentEmails = [];

  @override
  void initState() {
    super.initState();
    _fetchExams();
    _fetchStudentEmails();
    _fetchSubjects();
  }

  Future<void> _fetchExams() async {
    try {
      final snapshot = await _examRef.get();
      if (snapshot.exists) {
        final examData = snapshot.value as Map<Object?, Object?>?;
        if (examData != null) {
          setState(() {
            exams = [
              {'id': 'Choose Exam', 'title': 'Choose Exam', 'description': 'Choose Exam'}
            ] + examData.entries.map((entry) {
              final examMap = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
              return {
                'id': entry.key?.toString() ?? 'Unknown',
                'title': examMap['title']?.toString() ?? 'Unknown',
                'description': examMap['description']?.toString() ?? 'Unknown',
              };
            }).toList();
          });
        }
      }
    } catch (e) {
      print('Error fetching exams: $e');
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

  Future<void> _fetchSubjects() async {
    try {
      final snapshot = await _subjectRef.get();
      if (snapshot.exists) {
        final subjectData = snapshot.value as Map<Object?, Object?>?;
        if (subjectData != null) {
          setState(() {
            subjectCodes = subjectData.entries.fold<Map<String, String>>(
              {},
              (map, entry) {
                final subjectMap = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
                final subjectId = entry.key?.toString() ?? 'Unknown';
                final subjectCode = subjectMap['code']?.toString() ?? 'Unknown';
                map[subjectId] = subjectCode;
                return map;
              },
            );
          });
        }
      }
    } catch (e) {
      print('Error fetching subjects: $e');
    }
  }

  Future<void> _fetchStudentProgressByExam(String examId) async {
    try {
      final exam = exams.firstWhere((exam) => exam['id'] == examId);
      final examDescription = exam['description'] ?? 'Unknown';

      final snapshot = await _progressRef
          .orderByChild('examDescription')
          .equalTo(exam['description'])
          .get();

      if (snapshot.exists) {
        final progressData = snapshot.value as Map<Object?, Object?>;

        final filteredProgress = progressData.entries.fold<Map<String, Map<String, String>>>(
          {},
          (map, entry) {
            final progress = Map<String, dynamic>.from(entry.value as Map<Object?, Object?>);
            final studentId = progress['studentId'] ?? '-';
            final subjectId = progress['subjectId'] ?? '-';
            final subjectCode = subjectCodes[subjectId] ?? 'Unknown';

            if (!map.containsKey(studentId)) {
              map[studentId] = {
                'examDescription': examDescription,
              };
            }

            map[studentId]![subjectCode] = progress['score']?.toString() ?? '-';
            return map;
          },
        );

        setState(() {
          studentsProgress = filteredProgress;
          studentProgressByExam[examId] = studentsProgress[_selectedStudentId] ?? {
            'examDescription': examDescription,
          };
        });
      } else {
        setState(() {
          studentsProgress = {
            _selectedStudentId: {
              'examDescription': examDescription,
            }
          };
          studentProgressByExam[examId] = studentsProgress[_selectedStudentId] ?? {};
        });
      }
    } catch (e) {
      print('Error fetching student progress by exam: $e');
    }
  }

  // Add helper method to get color based on score
  Color _getScoreColor(double score) {
    if (score >= 80) {
      return const Color(0xFF4CAF50); // Green for A
    } else if (score >= 60) {
      return const Color(0xFF2196F3); // Blue for B
    } else if (score >= 40) {
      return const Color(0xFFFFA726); // Orange for C
    } else {
      return const Color(0xFFE53935); // Red for D
    }
  }

  Widget _buildGraph() {
    if (studentProgressByExam.isEmpty) return Container();

    final subjectList = subjectCodes.values.toList();
    final examList = exams.where((exam) => exam['id'] != 'Choose Exam').toList();
    
    // Sort examList based on specific order
    examList.sort((a, b) {
      List<String> order = ['PAT', 'PPT', 'PUPPK'];
      String descA = a['description'] ?? '';
      String descB = b['description'] ?? '';
      int indexA = order.indexOf(descA);
      int indexB = order.indexOf(descB);
      // If both items are found in the order list, use their indices
      if (indexA != -1 && indexB != -1) {
        return indexA.compareTo(indexB);
      }
      // If one or both items are not in the order list, keep their relative order
      return 0;
    });

    return Column(
      children: [
        // Subject Legend Card
        Card(
          elevation: 4,
          margin: const EdgeInsets.only(bottom: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0C6B58).withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: const Color(0xFF0C6B58).withOpacity(0.8),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Subject Legend',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Color(0xFF0C6B58),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubjectLegendItem('SR', 'Sirah'),
                          _buildSubjectLegendItem('AS', 'Amali Solat'),
                          _buildSubjectLegendItem('US', 'Ulum Syari\'ah'),
                          _buildSubjectLegendItem('JK', 'Jawi & Khat'),
                        ],
                      ),
                    ),
                    // Right column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSubjectLegendItem('LQ', 'Lughatul Quran'),
                          _buildSubjectLegendItem('BAQ', 'Bidang Al-Quran'),
                          _buildSubjectLegendItem('AD', 'Adab'),
                          _buildSubjectLegendItem('PCHI', 'Penghayatan Cara Hidup Islam'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Scrollable Subject Cards
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: subjectList.map((subjectCode) {
              List<Map<String, dynamic>> examScores = examList.map((exam) {
                final examId = exam['id'] ?? '';
                final score = double.tryParse(
                    studentProgressByExam[examId]?[subjectCode] ?? '0') ?? 0;
                return {
                  'examId': examId,
                  'examDescription': exam['description'] ?? 'Unknown',
                  'examTitle': exam['title'] ?? 'Unknown',
                  'score': score,
                };
              }).toList();

              // Sort examScores to ensure the order is maintained
              examScores.sort((a, b) {
                List<String> order = ['PAT', 'PPT', 'PUPPK'];
                String descA = a['examDescription'] ?? '';
                String descB = b['examDescription'] ?? '';
                int indexA = order.indexOf(descA);
                int indexB = order.indexOf(descB);
                if (indexA != -1 && indexB != -1) {
                  return indexA.compareTo(indexB);
                }
                return 0;
              });

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: SizedBox(
                  width: 350, // Fixed width like in parent dashboard
                  child: Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(vertical: 8.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Subject: $subjectCode',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Wrap(
                              spacing: 16.0,
                              children: [
                                _buildLegendItem('A (≥80)', const Color(0xFF4CAF50)),
                                _buildLegendItem('B (≥60)', const Color(0xFF2196F3)),
                                _buildLegendItem('C (≥40)', const Color(0xFFFFA726)),
                                _buildLegendItem('D (<40)', const Color(0xFFE53935)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
                                maxY: 100,
                                barGroups: List.generate(
                                  examScores.length,
                                  (index) => BarChartGroupData(
                                    x: index,
                                    barRods: [
                                      BarChartRodData(
                                        toY: examScores[index]['score'],
                                        color: _getScoreColor(examScores[index]['score']),
                                        width: 30,
                                        borderRadius: BorderRadius.circular(4),
                                        backDrawRodData: BackgroundBarChartRodData(
                                          show: true,
                                          toY: 100,
                                          color: Colors.grey[200],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
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
                                        if (value >= 0 && value < examScores.length) {
                                          return Padding(
                                            padding: const EdgeInsets.only(top: 8.0),
                                            child: Text(
                                              examScores[value.toInt()]['examDescription'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
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
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
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
                                      final examData = examScores[group.x];
                                      final value = rod.toY.round();
                                      final grade = _getGradeText(value.toString());
                                      return BarTooltipItem(
                                        '${examData['examDescription']}\n$value% (Grade $grade)',
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
                          const SizedBox(height: 16),
                          // Add exam abbreviation legend below the graph
                          Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: const Text(
                              'PAT: Peperiksaan Awal Tahun\n'
                              'PPT: Peperiksaan Pertengahan Tahun\n'
                              'PUPPK: Percubaan Ujian Penilaian Kelas KAFA',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontStyle: FontStyle.italic,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Add helper widget for legend items
  Widget _buildLegendItem(String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  // Add this helper function to get the grade
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

  Widget _buildSubjectLegendItem(String code, String name) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
            decoration: BoxDecoration(
              color: const Color(0xFF0C6B58).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF0C6B58).withOpacity(0.2),
              ),
            ),
            child: Text(
              code,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0C6B58),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
            'View Academic Records',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Refresh all data sources
          await _fetchExams();
          await _fetchStudentEmails();
          await _fetchSubjects();
          if (_selectedExam != 'Choose Exam' && _selectedStudentId.isNotEmpty) {
            await _fetchStudentProgressByExam(_selectedExam);
          }
          return Future.delayed(const Duration(milliseconds: 500));
        },
        color: const Color(0xFF0C6B58),
        child: ListView(  // Changed from SingleChildScrollView to ListView
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          children: [
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Select Student Email',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: const BorderSide(color: Color(0xFF0C6B58)),
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
                    studentProgressByExam = {}; // Clear previous progress
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
                      'Full Name:\n${studentNames[_selectedStudentEmail]?.toUpperCase() ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'Choose Exam',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(color: Color(0xFF0C6B58)),
                  ),
                ),
                value: _selectedExam,
                items: exams.map((exam) {
                  return DropdownMenuItem<String>(
                    value: exam['id'],
                    child: Text(exam['title'] ?? 'Unknown'),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedExam = value!;
                    if (_selectedExam != 'Choose Exam') {
                      _fetchStudentProgressByExam(_selectedExam);
                    }
                  });
                },
              ),
              const SizedBox(height: 16.0),
              if (_selectedExam != 'Choose Exam') ...[
                if (studentProgressByExam.isNotEmpty) ...[
                  _buildGraph(),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Container(
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
                                    color: Color(0xFF0C6B58),
                                    fontSize: 14,
                                  ),
                                  dataTextStyle: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 14,
                                  ),
                                  headingRowColor: WidgetStateProperty.all(Colors.grey[100]),
                                  dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                                    (Set<WidgetState> states) {
                                      if (states.contains(WidgetState.selected)) {
                                        return Theme.of(context).colorScheme.primary.withOpacity(0.08);
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ),
                              child: DataTable(
                                columnSpacing: 24,
                                horizontalMargin: 12,
                                columns: [
                                  const DataColumn(label: Text('')),
                                  ...subjectCodes.values.map((code) => DataColumn(
                                    label: Container(
                                      alignment: Alignment.center,
                                      width: 100,
                                      child: Text(
                                        code,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  )),
                                ],
                                rows: studentProgressByExam.entries.map((entry) {
                                  return DataRow(
                                    cells: [
                                      DataCell(Text(
                                        entry.value['examDescription'] ?? 'Unknown',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      )),
                                      ...subjectCodes.values.map((code) => DataCell(
                                        Container(
                                          alignment: Alignment.center,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: _getScoreColor(double.tryParse(entry.value[code] ?? '0') ?? 0),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  entry.value[code] ?? '-',
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  _getGradeText(entry.value[code]),
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
                                      )),
                                    ],
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ] else
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'No data available for the selected exam.',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
              ],
            ],
            // Add extra padding at the bottom to ensure all content is scrollable
            const SizedBox(height: 32.0),
          ],
        ),
      ),
    );
  }
}