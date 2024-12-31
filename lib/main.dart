import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'To-Do List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow.shade700,
          brightness: Brightness.light,
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 18.0),
        ),
        useMaterial3: true,
      ),
      home: const TodoListScreen(),
    );
  }
}

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  _TodoListScreenState createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen> {
  final List<Map<String, dynamic>> _todoList = []; // 할 일 리스트

  String _filter = 'all'; // 필터 구분 값 (all, active, completed)
  bool _autoDeleteCompleted = false; // 자동 삭제 옵션 활성화 구분
  DateTime _focusedDay = DateTime.now(); // 캘린더 오늘 날짜
  DateTime? _selectedDay; // 캘린더 선택된 날짜
  CalendarFormat _calendarFormat = CalendarFormat.month; // 캘린더 보기 구분
  final GlobalKey calendarKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadTodoList(); // 저장된 할 일 목록 리스트 로드
    _loadAutoDeleteSetting(); // 저장된 자동 삭제 옵션 구분값 로드
  }

  Future<void> _loadTodoList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('todoList');
    if (jsonString != null) {
      final List<dynamic> jsonData = jsonDecode(jsonString);
      setState(() {
        _todoList.clear();
        _todoList.addAll(jsonData.cast<Map<String, dynamic>>());
      });
    }
  }

  Future<void> _saveTodoList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_todoList);
    await prefs.setString('todoList', jsonString);
  }

  Future<void> _loadAutoDeleteSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _autoDeleteCompleted = prefs.getBool('autoDeleteCompleted') ?? false;
    });
  }

  Future<void> _saveAutoDeleteSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoDeleteCompleted', _autoDeleteCompleted);
  }

  List<Map<String, dynamic>> _getFilteredTodos() {
    final today = _normalizeDate(DateTime.now());
    return _todoList.where((item) {
      final itemDate = _normalizeDate(DateTime.parse(item['date']));
      if (_filter == 'all') {
        return itemDate == today;
      } else if (_filter == 'active') {
        return itemDate == today && !item['isCompleted'];
      } else if (_filter == 'completed') {
        return itemDate == today && item['isCompleted'];
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day) {
    final dateKey = _normalizeDate(day);
    return _todoList.where((item) {
      final itemDate = _normalizeDate(DateTime.parse(item['date']));
      return itemDate == dateKey;
    }).toList();
  }

  void _addTodoItem(String task, {required DateTime date}) {
    setState(() {
      _todoList.add({
        'task': task,
        'isCompleted': false,
        'date': _normalizeDate(date).toIso8601String(),
      });
    });
    _saveTodoList();
    setState(() {
      calendarKey.currentState?.setState(() {});
    });
  }

  void _deleteTodoItem(int index) {
    setState(() {
      _todoList.removeAt(index);
    });
    _saveTodoList();
    _updateTableCalendarEvents();
  }

  void _editTodoItem(int index, String newTask) {
    setState(() {
      _todoList[index]['task'] = newTask;
    });
    _saveTodoList();
    _updateTableCalendarEvents();
  }

  void _toggleTodoStatus(int index) {
    setState(() {
      _todoList[index]['isCompleted'] = !_todoList[index]['isCompleted'];
      if (_autoDeleteCompleted && _todoList[index]['isCompleted']) {
        _todoList.removeAt(index);
      }
    });
    _saveTodoList();
  }

  void _updateTableCalendarEvents() {
    setState(() {});
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatKoreanTimeOfDay(TimeOfDay time) {
    final period = time.period == DayPeriod.am ? '오전' : '오후';
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    return '$period $hour:${time.minute.toString().padLeft(2, '0')}';
  }

  void _showAddTodoDialog(BuildContext context, {required DateTime date}) {
    String newTask = "";
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("새로운 할 일 추가"),
          content: TextField(
            decoration: const InputDecoration(hintText: "할 일을 입력하세요"),
            onChanged: (value) => newTask = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                if (newTask.isNotEmpty) {
                  _addTodoItem(newTask, date: date);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("추가"),
            ),
          ],
        );
      },
    );

    setState(() {
      calendarKey.currentState?.setState(() {});
    });
  }

  Future<void> _showEditTodoDialog(BuildContext context, int index) async {
    String editedTask = _todoList[index]['task'];
    TextEditingController controller = TextEditingController(text: editedTask);

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("할 일 수정"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "할 일을 수정하세요"),
            onChanged: (value) => editedTask = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                if (editedTask.isNotEmpty) {
                  _editTodoItem(index, editedTask);
                  Navigator.of(context).pop();
                }
              },
              child: const Text("저장"),
            ),
          ],
        );
      },
    );
  }

  void _showAddTodoDialogInModal(
      BuildContext context, DateTime date, StateSetter setModalState) {
    String newTask = "";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("새로운 할 일 추가"),
          content: TextField(
            decoration: const InputDecoration(hintText: "할 일을 입력하세요"),
            onChanged: (value) => newTask = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                if (newTask.isNotEmpty) {
                  setState(() {
                    _addTodoItem(newTask, date: date);
                  });

                  setModalState(() {}); // 모달 상태 업데이트
                  Navigator.of(context).pop();
                }
              },
              child: const Text("추가"),
            ),
          ],
        );
      },
    );
  }

  void _showCalendar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        DateTime selectedDay = _selectedDay ?? _focusedDay;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final tasksForSelectedDay = _getEventsForDay(selectedDay);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            _focusedDay = DateTime.now();
                            selectedDay = DateTime.now();
                          });
                        },
                        child: const Text(
                          '오늘',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Text(
                        '캘린더',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const Divider(),
                  TableCalendar(
                    key: calendarKey,
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        final hasEvents = _todoList.any((todo) {
                          final todoDate =
                              _normalizeDate(DateTime.parse(todo['date']));
                          return isSameDay(todoDate, day);
                        });

                        if (hasEvents) {
                          return Positioned(
                            bottom: 1,
                            child: Container(
                              width: 8.0,
                              height: 8.0,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                    focusedDay: _focusedDay,
                    firstDay: DateTime(2000),
                    lastDay: DateTime(2100),
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                    onDaySelected: (selected, focused) {
                      setModalState(() {
                        selectedDay = selected;
                        _focusedDay = focused;
                      });
                    },
                    onFormatChanged: (format) {
                      setModalState(() {
                        _calendarFormat = format;
                      });
                    },
                  ),
                  const Divider(),
                  Expanded(
                    child: StatefulBuilder(
                      builder:
                          (BuildContext context, StateSetter setModalState) {
                        final tasksForSelectedDay =
                            _getEventsForDay(selectedDay);
                        return tasksForSelectedDay.isEmpty
                            ? const Center(
                                child: Text(
                                  '선택한 날짜에 할 일이 없습니다!',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: tasksForSelectedDay.length,
                                itemBuilder: (context, index) {
                                  final task = tasksForSelectedDay[index];
                                  return Card(
                                    elevation: 4.0,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4.0),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12.0),
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.all(10.0),
                                      leading: Checkbox(
                                        value: task['isCompleted'],
                                        onChanged: (value) {
                                          setState(() {
                                            final taskIndex =
                                                _todoList.indexOf(task);
                                            _toggleTodoStatus(taskIndex);
                                          });
                                          setModalState(() {});
                                        },
                                      ),
                                      title: Text(
                                        task['task'],
                                        style: TextStyle(
                                          decoration: task['isCompleted']
                                              ? TextDecoration.lineThrough
                                              : TextDecoration.none,
                                        ),
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // 캘린더 날짜별 할 일 목록 편집버튼
                                          IconButton(
                                            icon: const Icon(Icons.edit),
                                            color: Colors.blue.shade300,
                                            onPressed: () async {
                                              final taskIndex =
                                                  _todoList.indexOf(task);
                                              await _showEditTodoDialog(
                                                  context, taskIndex);
                                              setModalState(
                                                () {
                                                  tasksForSelectedDay[index]
                                                          ['task'] =
                                                      _todoList[taskIndex]
                                                          ['task'];
                                                },
                                              );
                                            },
                                          ),
                                          // 캘린더 날짜별 할 일 목록 삭제버튼
                                          IconButton(
                                            icon: const Icon(Icons.delete),
                                            color: Colors.red.shade300,
                                            onPressed: () {
                                              final taskIndex =
                                                  _todoList.indexOf(task);
                                              _deleteTodoItem(taskIndex);

                                              setModalState(() {
                                                tasksForSelectedDay
                                                    .removeAt(index);
                                              });

                                              // 이벤트 상태 업데이트
                                              setState(() {
                                                calendarKey.currentState
                                                    ?.setState(() {});
                                              });
                                            },
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
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _showAddTodoDialogInModal(
                            context, selectedDay, setModalState);
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('할 일 추가'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTodos = _getFilteredTodos();

    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<DateTime>(
          stream: Stream.periodic(
              const Duration(seconds: 1), (_) => DateTime.now()),
          builder: (context, snapshot) {
            final now = snapshot.data ?? DateTime.now();
            return Text(
              '${now.toLocal().toString().split(' ')[0]} – ${_formatKoreanTimeOfDay(TimeOfDay.fromDateTime(now))}',
              style:
                  const TextStyle(fontSize: 18.0, fontWeight: FontWeight.bold),
            );
          },
        ),
        backgroundColor: Colors.yellow.shade600,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _showCalendar,
          ),
          PopupMenuButton<String>(
            onSelected: (value) => setState(() => _filter = value),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('전체 보기')),
              const PopupMenuItem(value: 'active', child: Text('미완료 보기')),
              const PopupMenuItem(value: 'completed', child: Text('완료 보기')),
              PopupMenuItem(
                enabled: false, // 클릭 불가
                child: StatefulBuilder(
                    builder: (BuildContext context, StateSetter setState) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "완료 자동 삭제",
                        style: TextStyle(color: Colors.black),
                      ),
                      Switch(
                        value: _autoDeleteCompleted,
                        onChanged: (value) {
                          setState(() {
                            _autoDeleteCompleted = value;
                          });
                          _saveAutoDeleteSetting();
                        },
                      ),
                    ],
                  );
                }),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: filteredTodos.isEmpty
                ? const Center(child: Text('항목이 없습니다!'))
                : ListView.builder(
                    itemCount: filteredTodos.length,
                    itemBuilder: (context, index) {
                      final todoItem = filteredTodos[index];
                      final actualIndex = _todoList.indexOf(todoItem);
                      return Card(
                        elevation: 4.0,
                        margin: const EdgeInsets.symmetric(vertical: 8.0),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16.0),
                          title: Text(
                            todoItem['task'],
                            style: TextStyle(
                              decoration: todoItem['isCompleted']
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          leading: Checkbox(
                            value: todoItem['isCompleted'],
                            onChanged: (value) =>
                                _toggleTodoStatus(actualIndex),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit),
                                color: Colors.blue.shade300,
                                onPressed: () =>
                                    _showEditTodoDialog(context, actualIndex),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete),
                                color: Colors.red.shade300,
                                onPressed: () => _deleteTodoItem(actualIndex),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: () =>
                  _showAddTodoDialog(context, date: DateTime.now()),
              style: ElevatedButton.styleFrom(
                elevation: 8.0,
                backgroundColor: Colors.yellow.shade600,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
                padding: const EdgeInsets.symmetric(
                    vertical: 16.0, horizontal: 32.0),
              ),
              child: const Text(
                '+ 할 일 추가',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
