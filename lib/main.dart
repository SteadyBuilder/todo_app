import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
        primarySwatch: Colors.blue,
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

// build() {}
class _TodoListScreenState extends State<TodoListScreen> {
  //final List<String> _todoList = []; // 할 일 목록
  final List<Map<String, dynamic>> _todoList = []; // 수정: 완료/미완료 상태 포함

  // 상태값 초기화 (깔끔한 데이터 로드를 위함)
  @override
  void initState() {
    super.initState();
    // _clearOldData(); // 초기화 메서드 호출
    _loadTodoList(); // 앱 시작 시 로컬 저장소에서 데이터 로드
  }

  // 저장된 데이터 초기화
  Future<void> _clearOldData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('todoList'); // SharedPreferences 데이터 삭제
    setState(
      () {
        _todoList.clear(); // _todoList 상태 초기화
      },
    );
    print("기존 데이터를 삭제했어요!");
    print(_todoList);
  }

  // 로컬 저장소에서 데이터를 불러오는 메서드
  Future<void> _loadTodoList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString('todoList');
    if (jsonString != null) {
      setState(() {
        final List<dynamic> jsonData = jsonDecode(jsonString);
        _todoList.addAll(jsonData.cast<Map<String, dynamic>>());
      });
    }
  }

  // 로컬 저장소에 데이터를 저장하는 메서드
  Future<void> _saveTodoList() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = jsonEncode(_todoList); // JSON 문자열로 변환
    await prefs.setString('todoList', jsonString); // JSON 데이터 저장
  }

  // 할 일 추가 메서드
  void _addTodoItem(task) {
    setState(() {
      _todoList.add({'task': task, 'isCompleted': false}); // 수정: 완료 상태 포함
    });
    print(_todoList.last);
    print("할 일을 추가했어요 !");
    _saveTodoList();
  }

  // 할 일 삭제 메서드
  void _deleteTodoItem(index) {
    print(_todoList[index]);
    setState(() {
      _todoList.removeAt(index);
    });
    print("할 일을 삭제했어요 !");
    _saveTodoList();
  }

  // 완료 상태 변경 메서드
  void _toggleTodoStatus(int index) {
    setState(() {
      _todoList[index]['isCompleted'] = !_todoList[index]['isCompleted'];
    });
    _saveTodoList();
  }

  // 다이얼로그를 표시한 메서드
  void _showAddTodoDialog(BuildContext context) {
    String newTask = "";

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("할 일 추가"),
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
            TextButton(
              onPressed: () {
                if (newTask.isNotEmpty) {
                  // 할 일 리스트 추가하기
                  _addTodoItem(newTask);
                }
                Navigator.of(context).pop(); // 다이얼로그 닫기
              },
              child: const Text("추가"),
            ),
          ],
        );
      },
    );
  } // __showSimpleDialog

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('To-Do List'),
      ),
      body: _todoList.isEmpty
          ? const Center(
              child: Text('할 일이 없습니다!'),
            )
          : ListView.builder(
              itemCount: _todoList.length,
              itemBuilder: (context, index) {
                final todoItem = _todoList[index];
                return ListTile(
                  title: Text(
                    todoItem['task'],
                    style: TextStyle(
                      decoration: todoItem['isCompleted']
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color:
                          todoItem['isCompleted'] ? Colors.grey : Colors.black,
                    ),
                  ),
                  leading: Checkbox(
                    value: todoItem['isCompleted'],
                    onChanged: (value) {
                      _toggleTodoStatus(index); // 완료 상태 변경
                    },
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.redAccent),
                    onPressed: () {
                      _deleteTodoItem(index); // 삭제 버튼 클릭 시 항목 삭제
                    },
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
