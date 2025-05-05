import 'package:flutter/material.dart';
import 'package:app_04/TaskManager/view/Task/AddTaskScreen.dart';
import 'package:app_04/TaskManager/view/Task/EditTaskScreen.dart';
import 'package:app_04/TaskManager/model/Task.dart';
import 'package:app_04/TaskManager/view/Task/TaskDetailScreen.dart';
import 'package:app_04/TaskManager/view/Sign-in/LoginScreen.dart';
import 'package:app_04/TaskManager/db/TaskDatabaseHelper.dart';
import 'package:app_04/TaskManager/db/UserDatabaseHelper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class TaskListScreen extends StatefulWidget {
  final String currentUserId;

  const TaskListScreen({Key? key, required this.currentUserId}) : super(key: key);

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> tasks = [];
  List<Task> filteredTasks = [];
  bool isGrid = false;
  String selectedStatus = 'Tất cả';
  String searchKeyword = '';
  bool _isLoading = false;
  bool _dbInitialized = false;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  // Khởi tạo database và lấy dữ liệu
  Future<void> _initializeDatabase() async {
    try {
      setState(() => _isLoading = true);
      await TaskDatabaseHelper.instance.database;
      setState(() => _dbInitialized = true);

      final user = await UserDatabaseHelper.instance.getUserById(widget.currentUserId);
      _isAdmin = user?.isAdmin ?? false;

      await _loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khởi tạo database: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  //Kiểm tra task đến hạn chưa
  bool _isTaskUpcoming(Task task) {
    if (task.dueDate == null || task.status.toLowerCase() == 'done') return false; //sẽ bỏ qua các task đã done mà ko không hiện cảnh báo
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(task.dueDate!.year, task.dueDate!.month, task.dueDate!.day);
    final difference = dueDate.difference(today).inDays;
    return difference >= 0 && difference <= 3;
  }

  // Hàm load Task tu database
  Future<void> _loadTasks() async {
    if (!_dbInitialized) return;

    try {
      setState(() => _isLoading = true);

      if (_isAdmin) {
        tasks = await TaskDatabaseHelper.instance.getAllTasks();
      } else {
        tasks = await TaskDatabaseHelper.instance.getTasksByUser(widget.currentUserId);
      }

      _applyFilters();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải công việc: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Lọc task theo từ khoá và trạng thái
  void _applyFilters() {
    setState(() {
      filteredTasks = tasks.where((task) {
        final matchesStatus =
            selectedStatus == 'Tất cả' || task.status == selectedStatus;
        final matchesSearch = searchKeyword.isEmpty ||
            task.title.toLowerCase().contains(searchKeyword.toLowerCase()) ||
            task.description.toLowerCase().contains(searchKeyword.toLowerCase());
        return matchesStatus && matchesSearch;
      }).toList();

      filteredTasks.sort((a, b) => b.priority.compareTo(a.priority));
    });
  }
  // Hàm xoá task
  Future<void> _deleteTask(String taskId, Task task) async {
    // Kiểm tra quyền: chỉ admin hoặc người tạo task mới được xóa
    if (!_isAdmin && task.createdBy != widget.currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn không có quyền xóa công việc này.')),
      );
      return;
    }

    // Xác nhận xóa
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa công việc này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // Nếu xác nhận xóa thì sẽ báo xoá thành công
    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);
        await TaskDatabaseHelper.instance.deleteTask(taskId);
        await _loadTasks(); // Tải lại danh sách task
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xóa công việc thành công.')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi khi xóa công việc: $e')),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Màu sắc của mức độ ưu tiên
  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 1: // Cao
        return Colors.teal.shade100;
      case 2: // Trung bình
        return Colors.amber.shade100;
      case 3: // Thấp
        return Colors.red.shade100;
      default:
        return Colors.white;
    }
  }

  // Mức độ ưu tiên
  String _priorityText(int priority) {
    switch (priority) {
      case 1:
        return 'Cao';
      case 2:
        return 'Trung bình';
      case 3:
        return 'Thấp';
      default:
        return 'Không xác định';
    }
  }

  //Giao diện chính của màn hình task
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Danh sách Công việc',
          style: TextStyle(
            color: Colors.black,  // Màu chữ của title
          ),
        ),
        backgroundColor: Colors.greenAccent, //màu appbar
        actions: [
          IconButton(icon: const Icon(Icons.restart_alt), onPressed: _loadTasks), // n1ut load
          IconButton(
            icon: Icon(isGrid ? Icons.format_list_bulleted : Icons.dashboard), //2 nút grid và list
            onPressed: () => setState(() => isGrid = !isGrid),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _showLogoutDialog();
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Đăng xuất'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),

      //Thanh tìm kiếm task - tìm kiếm theo title
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Tìm kiếm công việc...',
                prefixIcon: const Icon(Icons.search, color: Colors.black),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 20.0),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.transparent),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(color: Colors.blue.shade300, width: 1.5),
                ),
              ),
              onChanged: (value) {
                searchKeyword = value;
                _applyFilters();
              },
            ),
          ),

          // Thanh sreach theo trạng thai
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: DropdownButtonFormField<String>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Lọc theo trạng thái',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(22)),
                ),
              ),
              items: ['Tất cả', 'To do', 'In progress', 'Done', 'Cancelled']
                  .map((status) => DropdownMenuItem<String>(value: status, child: Text(status)))
                  .toList(),
              onChanged: (value) {
                selectedStatus = value!;
                _applyFilters();
              },
            ),
          ),
          Expanded(
            child: isGrid ? _buildTaskGridView() : _buildTaskListView(),
          ),
        ],
      ),

      // Nút add task
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddTaskScreen(currentUserId: widget.currentUserId),
            ),
          );
          if (result == true) await _loadTasks();
        },
        child: const Icon(Icons.add, color: Colors.black),
        backgroundColor: Colors.greenAccent,
      ),
    );
  }

  //Listview
  Widget _buildTaskListView() {
    return ListView.builder(
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final isUpcoming = _isTaskUpcoming(task); //kiểm tra task hết hạn chưa hàm isUpcoming đa được thiết lập ở trên

        return Card(  //giao diện của 1 task
          color: _getPriorityColor(task.priority),
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: ListTile(
            leading: isUpcoming //nếu task đến hạn sẽ hiển thị icon cảnh bo
                ? const Padding(
              padding: EdgeInsets.only(right: 8.0), // Đảm bảo khoảng cách giữa icon và tiêu đề
              child: Icon(Icons.warning, color: Colors.orange),
            )
                : null,
            title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Trạng thái: ${task.status} • Ưu tiên: ${_priorityText(task.priority)}'),

            // Hai nút sửa và xoá của list view
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () async {
                    final updatedTask = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditTaskScreen(
                            task: task, currentUserId: widget.currentUserId),
                      ),
                    );
                    if (updatedTask != null) {
                      await TaskDatabaseHelper.instance.updateTask(updatedTask);
                      await _loadTasks();
                    }
                  },
                ),
                if (_isAdmin || task.createdBy == widget.currentUserId) //nếu là admin hoặc là users tạo task thì mới được xoá
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTask(task.id, task),
                  ),
              ],
            ),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
              );
              await _loadTasks();
            },
          )
        );
      },
    );
  }

   //Giao diện của gridview
  Widget _buildTaskGridView() {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 4 / 3,
      ),
      itemCount: filteredTasks.length,
      itemBuilder: (context, index) {
        final task = filteredTasks[index];
        final isUpcoming = _isTaskUpcoming(task);

        return GestureDetector(
          onTap: () async {
            final updatedTask = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => EditTaskScreen(task: task, currentUserId: widget.currentUserId),
              ),
            );
            if (updatedTask != null) {
              await TaskDatabaseHelper.instance.updateTask(updatedTask);
              await _loadTasks();
            }
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getPriorityColor(task.priority),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade300,
                  blurRadius: 6,
                  offset: const Offset(2, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    if (isUpcoming)
                      const Icon(Icons.warning, color: Colors.orange, size: 16),
                    if (isUpcoming) const SizedBox(width: 8), // Điều chỉnh khoảng cách
                    Expanded(
                      child: Text(
                        task.title,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Trạng thái: ${task.status}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text('Ưu tiên: ${_priorityText(task.priority)}', style: const TextStyle(fontSize: 12)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end, // Căn các nút về phía bên phải
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () async {
                        final updatedTask = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditTaskScreen(
                                task: task, currentUserId: widget.currentUserId),
                          ),
                        );
                        if (updatedTask != null) {
                          await TaskDatabaseHelper.instance.updateTask(updatedTask);
                          await _loadTasks();
                        }
                      },
                    ),
                    if (_isAdmin || task.createdBy == widget.currentUserId)
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteTask(task.id, task),

                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }


  // cửa sổ thông báo xoá task
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')),
          TextButton(
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('loggedInUserId');
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (ctx) => const LoginScreen()),
                    (route) => false,
              );
            },
            child: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}