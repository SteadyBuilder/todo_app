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
      debugShowCheckedModeBanner: false, // 디버그 배너 숨기기
      title: 'To-Do List',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.yellow.shade700, // 메인 색상 (테마의 주요 색상)
          brightness: Brightness.light, // 밝은 테마
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16.0),
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
  final List<Map<String, dynamic>> _todoList = []; // 완료/미완료 상태 포함
  String _filter = 'all'; // 필터 상태: 'all', 'active', 'completed'
  bool _autoDeleteCompleted = false; // 완료 항목 자동 삭제 옵션 상태
  final Map<DateTime, List<String>> _calendarEvents = {}; // 날짜별 이벤트 저장
  DateTime _focusedDay = DateTime.now(); // 오늘 날짜 기준
  DateTime? _selectedDay; // 선택된 날짜 저장
  CalendarFormat _calendarFormat = CalendarFormat.month; // 캘린더 보기 형식

  // 상태값 초기화
  @override
  void initState() {
    super.initState();
    _loadTodoList(); // 앱 시작 시 로컬 저장소에서 데이터 로드
    _loadAutoDeleteSetting(); // 앱 시작 시 로컬 저장소에서 완료항목 자동삭제 옵션상태값 로드
    _loadCalendarEvents(); // 앱 시작 시 로컬 저장소에서 캘린더 이벤트 로드
  }

  // 로컬 저장소에서 데이터를 불러오는 메서드
  Future<void> _loadTodoList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('todoList');
    if (jsonString != null) {
      final List<dynamic> jsonData = jsonDecode(jsonString);
      setState(() {
        _todoList.clear(); // 중복 방지, 메모리에 남은 데이터 초기화
        _todoList.addAll(jsonData.cast<Map<String, dynamic>>());

        // _calendarEvents와 동기화
        _calendarEvents.clear();
        for (var item in _todoList) {
          final dateKey = _normalizeDate(DateTime.parse(item['date']));
          _calendarEvents[dateKey] = _calendarEvents[dateKey] ?? [];
          _calendarEvents[dateKey]!.add(item['task']);
        }
      });
    }
  }

  // 로컬 저장소에서 완료항목 자동삭제 옵션상태값을 로드하는 메서드
  Future<void> _loadAutoDeleteSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(
      () {
        _autoDeleteCompleted = prefs.getBool('autoDeleteCompleted') ?? false;
      },
    );
  }

  // 로컬 저장소에서 날짜별 조회용 할일 데이터를 로드하는 메서드
  Future<void> _loadCalendarEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('calendarEvents');
    if (jsonString != null) {
      final Map<String, dynamic> jsonEvents = jsonDecode(jsonString);
      setState(() {
        _calendarEvents.clear();
        jsonEvents.forEach((key, value) {
          _calendarEvents[DateTime.parse(key)] = List<String>.from(value);
        });
      });
    }
  }

  // 로컬 저장소에 데이터를 저장하는 메서드
  Future<void> _saveTodoList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_todoList); // JSON 문자열로 변환
    await prefs.setString('todoList', jsonString); // JSON 데이터 저장
  }

  // 로컬 저장소에 완료항목 자동삭제 옵션상태값을 저장하는 메서드
  Future<void> _saveAutoDeleteSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoDeleteCompleted', _autoDeleteCompleted);
  }

  // 로컬 저장소에 날짜별 조회용 할일 데이터를 저장하는 메서드
  Future<void> _saveCalendarEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonEvents = _calendarEvents
        .map((key, value) => MapEntry(key.toIso8601String(), value));
    await prefs.setString('calendarEvents', jsonEncode(jsonEvents));
  }

  // 할 일 추가 메서드
  void _addTodoItem(String task) {
    final today = DateTime.now(); // 현재 날짜
    final dateKey = _normalizeDate(_selectedDay ?? today); // 선택된 날짜 또는 현재 날짜

    setState(() {
      // 새로운 할 일을 _todoList에 추가
      _todoList.add({
        'task': task,
        'isCompleted': false,
        'date': dateKey.toIso8601String(), // 선택된 날짜 사용
      });

      // 캘린더 이벤트 업데이트
      _calendarEvents[dateKey] = _calendarEvents[dateKey] ?? [];
      _calendarEvents[dateKey]!.add(task);
    });

    // 콘솔 출력 (디버깅용)
    print(_todoList.last);
    print("할 일을 추가했어요 !");
    print("캘린더 이벤트: $_calendarEvents"); // 날짜 키 표준화 로그 (확인 후 제거)

    // 데이터 저장
    _saveTodoList();
    _saveCalendarEvents(); // 캘린더 이벤트 저장
  }

  // 할 일 삭제 메서드
  void _deleteTodoItem(int index) {
    print(_todoList[index]);
    print("할 일을 삭제합니다 !");
    final todoItem = _todoList[index];
    final dateKey = _normalizeDate(DateTime.parse(todoItem['date']));

    setState(() {
      _todoList.removeAt(index);
      _calendarEvents[dateKey]?.remove(todoItem['task']);
      if (_calendarEvents[dateKey]?.isEmpty ?? true) {
        _calendarEvents.remove(dateKey);
      }
    });

    _saveTodoList();
    _saveCalendarEvents(); // 캘린더 이벤트 저장
  }

  // 할 일 수정 메서드
  void _editTodoItem(int index, String newTask) {
    setState(() {
      _todoList[index]['task'] = newTask;
    });
    _saveTodoList();
  }

  // 완료 상태 변경 메서드
  void _toggleTodoStatus(int index) {
    setState(() {
      _todoList[index]['isCompleted'] = !_todoList[index]['isCompleted'];
      if (_autoDeleteCompleted && _todoList[index]['isCompleted']) {
        print(_todoList[index]);
        print("할 일을 삭제합니다 !");
        _todoList.removeAt(index);
      }
    });
    _saveTodoList();
  }

  // 현재 필터에 따라 리스트 필터링
  List<Map<String, dynamic>> _getFilteredTodos() {
    final today = _normalizeDate(DateTime.now()); // 오늘 날짜를 표준화
    print("_filter : $_filter");
    print('_todoList: $_todoList');
    print('_calendarEvents: $_calendarEvents');

    // 'all' 필터인 경우 오늘 날짜의 할 일만 필터링
    if (_filter == 'all') {
      return _todoList.where((item) {
        final itemDate = _normalizeDate(DateTime.parse(item['date']));
        return itemDate == today; // 오늘 날짜와 동일한 할 일만 반환
      }).toList();
    }

    // 'active' ㅣㄹ터인 경우 미완료된 오늘 날짜의 할 일만 필터링
    if (_filter == 'active') {
      return _todoList.where((item) {
        final itemDate = _normalizeDate(DateTime.parse(item['date']));
        return itemDate == today && !item['isCompleted'];
      }).toList();
    }

    // 'completed' 필터인 경우 완료된 오늘 날짜의 할 일만 필터링
    if (_filter == 'completed') {
      return _todoList.where((item) {
        final itemDate = _normalizeDate(DateTime.parse(item['date']));
        return itemDate == today && item['isCompleted'];
      }).toList();
    }

    return []; // 기본적으로 빈 리스트 반환
  }

  // 날짜별 데이터 조회
  List<String> _getEventsForDay(DateTime day) {
    final dateKey = _normalizeDate(day); // 날짜 키 표준화
    return _calendarEvents[dateKey] ?? [];
  }

  // 날짜 키 표준화
  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  // 할 일 추가 다이얼로그 표시
  void _showAddTodoDialog(BuildContext context) {
    String newTask = "";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("새로운 할 일 추가"),
          content: TextField(
            decoration: const InputDecoration(
              hintText: "할 일을 입력하세요",
            ),
            onChanged: (value) {
              newTask = value;
            },
          ),
          actions: [
            // 취소 버튼
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: const Text("취소"),
            ),
            // 추가 버튼
            TextButton(
              onPressed: () {
                if (newTask.isNotEmpty) {
                  // 할 일 리스트 추가하기
                  _addTodoItem(newTask);

                  // 다이얼로그 닫기 후 목록 갱신
                  Navigator.of(context).pop(); // 다이얼로그 닫기
                  _showTasksForSelectedDay();
                }
              },
              child: const Text("추가"),
            ),
          ],
        );
      },
    );
  } // _showAddTodoDialog

  // 할 일 수정 다이얼로그
  void _showEditTodoDialog(BuildContext context, int index) {
    String editedTask = _todoList[index]['task'];
    TextEditingController controller = TextEditingController(text: editedTask);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("할 일 수정"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "할 일을 수정하세요",
            ),
            onChanged: (value) {
              editedTask = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text("취소"),
            ),
            TextButton(
              onPressed: () {
                if (editedTask.isNotEmpty) {
                  _editTodoItem(index, editedTask);
                }
                Navigator.of(context).pop();
              },
              child: const Text("저장"),
            ),
          ],
        );
      },
    );
  } // _showEditTodoDialog

  // 캘린더
  void _showCalendar() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '캘린더',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        Navigator.of(context).pop(); // 캘린더 모달 닫기
                      },
                    ),
                  ],
                ),
                const Divider(),
                TableCalendar(
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      final eventList = _getEventsForDay(day);
                      if (eventList.isNotEmpty) {
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
                  onFormatChanged: (format) {
                    if (_calendarFormat != format) {
                      setModalState(() {
                        _calendarFormat = format;
                      });
                      setState(() {
                        _calendarFormat = format; // 부모 상태에도 저장
                      });
                    }
                  },
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                    _showTasksForSelectedDay();
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showTasksForSelectedDay() {
    final selectedDateTasks = _getEventsForDay(_selectedDay ?? DateTime.now());

    // 기존 모달 닫기 후 새로운 모달 열기
    Navigator.of(context).pop(); // 기존 모달 닫기

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 상단: 제목과 닫기 버튼
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${_selectedDay != null ? _selectedDay!.toLocal().toString().split(' ')[0] : '오늘'} 일자의 할 일',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        // 모달 닫기
                        if (Navigator.canPop(context)) {
                          Navigator.of(context).pop();
                        }
                      },
                    ),
                  ],
                ),
                const Divider(),

                // 중간: 할 일 목록
                selectedDateTasks.isEmpty
                    ? const Center(
                        child: Text(
                          '할 일이 없습니다!',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      )
                    : Expanded(
                        child: ListView.builder(
                          itemCount: selectedDateTasks.length,
                          itemBuilder: (context, index) {
                            final task = selectedDateTasks[index];
                            return Card(
                              elevation: 4.0,
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              child: ListTile(
                                title: Text(
                                  task,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          color: Colors.blueAccent),
                                      onPressed: () {
                                        // 편집 기능 추가
                                        _showEditTodoDialog(
                                            context,
                                            _todoList.indexWhere((item) =>
                                                item['task'] == task));
                                      },
                                    ),
                                    IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.redAccent),
                                        onPressed: () {
                                          final taskToDelete = task; // 삭제할 항목
                                          final dateKey = _normalizeDate(
                                              _selectedDay ??
                                                  DateTime.now()); // 선택된 날짜키

                                          setState(() {
                                            // _todoList에서 삭제
                                            _todoList.removeWhere((item) =>
                                                item['task'] == taskToDelete &&
                                                _normalizeDate(DateTime.parse(
                                                        item['date'])) ==
                                                    dateKey);

                                            // _calendarEvents 에서 해당 항목 삭제
                                            _calendarEvents[dateKey]
                                                ?.remove(taskToDelete);

                                            // 만약 해당 날짜의 이벤트 리스트가 비었다면, 날짜 키 제거
                                            if (_calendarEvents[dateKey]
                                                    ?.isEmpty ??
                                                true) {
                                              _calendarEvents.remove(dateKey);
                                            }
                                          });

                                          // 모달 내부 상태 갱신
                                          setModalState(() {
                                            selectedDateTasks.remove(
                                                taskToDelete); // 선택된 날짜의 목록 갱신
                                          });
                                        }),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                // 하단: "할 일 추가" 버튼
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ElevatedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('할 일 추가'),
                      onPressed: () {
                        _showAddTodoDialog(context);
                      }),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredTodos = _getFilteredTodos();

    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today), // 캘린더 아이콘
            onPressed: _showCalendar, // 캘린더 호출
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _filter = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('전체 보기')),
              const PopupMenuItem(value: 'active', child: Text('미완료 보기')),
              const PopupMenuItem(value: 'completed', child: Text('완료 보기')),
              PopupMenuItem(
                child: StatefulBuilder(
                  builder: (BuildContext context, StateSetter setState) {
                    return Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('완료 자동 삭제'),
                        Switch(
                          value: _autoDeleteCompleted,
                          onChanged: (bool value) {
                            setState(() {
                              _autoDeleteCompleted = value;
                            });
                            _saveAutoDeleteSetting();
                          },
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
      body: filteredTodos.isEmpty
          ? const Center(
              child: Text('항목이 없습니다!'),
            )
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
                    contentPadding: const EdgeInsets.all(10.0),
                    title: Text(
                      todoItem['task'],
                      style: TextStyle(
                        decoration: todoItem['isCompleted']
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        color: todoItem['isCompleted']
                            ? Colors.grey
                            : Colors.black,
                      ),
                    ),
                    leading: Checkbox(
                      value: todoItem['isCompleted'],
                      onChanged: (value) {
                        _toggleTodoStatus(actualIndex); // 완료 상태 변경
                      },
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon:
                              const Icon(Icons.edit, color: Colors.blueAccent),
                          onPressed: () {
                            _showEditTodoDialog(context, actualIndex);
                          },
                        ),
                        IconButton(
                          icon:
                              const Icon(Icons.delete, color: Colors.redAccent),
                          onPressed: () {
                            _deleteTodoItem(actualIndex); // 삭제 버튼 클릭 시 항목 삭제
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showAddTodoDialog(context); // 다이얼로그 호출
        }, // 다이얼로그 호출
        child: const Icon(Icons.add),
      ),
    );
  }
}
