import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:app_04/TaskManager/model/Task.dart';
import 'package:app_04/TaskManager/model/User.dart';
import 'package:app_04/TaskManager/db/TaskDatabaseHelper.dart';
import 'package:app_04/TaskManager/db/UserDatabaseHelper.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class AddTaskScreen extends StatefulWidget {
  final String currentUserId;

  const AddTaskScreen({Key? key, required this.currentUserId})
      : super(key: key);

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _status = 'To do';
  int _priority = 1; // 1: Thấp, 2: Trung Bình, 3: Cao
  DateTime? _dueDate;
  String? _assignedTo;
  List<String> _attachments = [];
  List<User> _users = [];
  bool _isLoading = false;
  bool _isAdmin = false;

  final List<String> _statusOptions = [
    'To do',
    'In progress',
    'Done',
    'Cancelled',
  ];
  final List<Map<String, dynamic>> _priorityOptions = [
    {'value': 3, 'label': 'Cao'},
    {'value': 2, 'label': 'Trung Bình'},
    {'value': 1, 'label': 'Thấp'},
  ];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      User? currentUser = await UserDatabaseHelper.instance.getUserById(
        widget.currentUserId,
      );
      _isAdmin = currentUser?.isAdmin ?? false;

      if (_isAdmin) {
        _users = await UserDatabaseHelper.instance.getAllUsers();
        _users.removeWhere((user) => user.id == widget.currentUserId);
      } else {
        _users = [];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải user: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null && result.files.isNotEmpty) {
        final appDir = await getApplicationDocumentsDirectory();
        List<String> newAttachments = [];

        for (var file in result.files) {
          if (file.path != null) {
            final newFileName = '${DateTime.now().millisecondsSinceEpoch}_${file.name}';
            final newFilePath = '${appDir.path}/$newFileName';
            await File(file.path!).copy(newFilePath);
            newAttachments.add(newFilePath);
          }
        }

        setState(() {
          _attachments.addAll(newAttachments);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chọn file: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _removeAttachment(int index) {
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _selectDueDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade600,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue.shade600,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _handleAddTask() async {
    if (_formKey.currentState!.validate()) {
      try {
        setState(() => _isLoading = true);

        List<Task> tasksToCreate = [];

        if (_assignedTo == 'all' && _isAdmin) {
          for (final user in _users) {
            tasksToCreate.add(Task(
              id: '${DateTime.now().millisecondsSinceEpoch}_${user.id}',
              title: _titleController.text,
              description: _descriptionController.text,
              status: _status,
              priority: _priority,
              dueDate: _dueDate,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              assignedTo: user.id,
              createdBy: widget.currentUserId,
              category: null,
              attachments: _attachments.isNotEmpty ? _attachments : null,
              completed: _status == 'Done',
            ));
          }
        } else {
          tasksToCreate.add(Task(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            title: _titleController.text,
            description: _descriptionController.text,
            status: _status,
            priority: _priority,
            dueDate: _dueDate,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            assignedTo: _isAdmin ? _assignedTo : widget.currentUserId,
            createdBy: widget.currentUserId,
            category: null,
            attachments: _attachments.isNotEmpty ? _attachments : null,
            completed: _status == 'Done',
          ));
        }

        for (final task in tasksToCreate) {
          await TaskDatabaseHelper.instance.createTask(task);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã thêm ${tasksToCreate.length} công việc'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi thêm công việc: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Thêm công việc mới',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: Colors.white),
            onPressed: _handleAddTask,
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.blue.shade600,
          ),
        ),
      )
          : SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Thông tin cơ bản',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tiêu đề',
                  hintText: 'Nhập tiêu đề công việc',
                  prefixIcon: Icon(
                    Icons.title,
                    color: Colors.blue.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Colors.blue.shade600,
                      width: 2, // Độ dày viền khi chưa focus
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: Colors.blue.shade800,
                      width: 2.0, // Độ dày viền khi focus
                    ),
                  ),
                ),
                style: TextStyle(fontSize: 16),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Mô tả',
                  hintText: 'Nhập mô tả chi tiết (nếu có)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(
                    Icons.description,
                    color: Colors.blue.shade600,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(color: Colors.blue.shade600),
                  ),
                ),
                maxLines: 3,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 25),

              Text(
                'Cài đặt công việc',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 16),

              Column(
                children: [
                  // Dropdown cho Trạng thái
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0), // Khoảng cách giữa 2 dropdown
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: 'Trạng thái',
                        labelStyle: TextStyle(
                          color: Colors.blue.shade600, // Màu label
                        ),
                        prefixIcon: Icon(
                          Icons.info,
                          color: Colors.blue.shade600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20), // Bo tròn góc
                          borderSide: BorderSide(
                            color: Colors.blue.shade600,
                            width: 1.5, // Đường viền đậm hơn
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.blue.shade600,
                            width: 2, // Đường viền khi focus
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10, // Tăng chiều cao
                          horizontal: 12, // Khoảng cách bên trái và phải
                        ),
                      ),
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 16, // Font size lớn hơn
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _status = value;
                          });
                        }
                      },
                    ),
                  ),
                  // Dropdown cho Độ ưu tiên
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0), // Khoảng cách giữa 2 dropdown
                    child: DropdownButtonFormField<int>(
                      value: _priority,
                      decoration: InputDecoration(
                        labelText: 'Độ ưu tiên',
                        labelStyle: TextStyle(
                          color: Colors.blue.shade600, // Màu label
                        ),
                        prefixIcon: Icon(
                          Icons.priority_high,
                          color: Colors.blue.shade600,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20), // Bo tròn góc
                          borderSide: BorderSide(
                            color: Colors.blue.shade600,
                            width: 1.5, // Đường viền đậm hơn
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.blue.shade600,
                            width: 2, // Đường viền khi focus
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10, // Tăng chiều cao
                          horizontal: 12, // Khoảng cách bên trái và phải
                        ),
                      ),
                      items: _priorityOptions.map((option) {
                        return DropdownMenuItem<int>(
                          value: option['value'],
                          child: Text(
                            option['label'],
                            style: TextStyle(
                              fontSize: 16, // Font size lớn hơn
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _priority = value;
                          });
                        }
                      },
                    ),
                  ),
                ],
              ),

              SizedBox(height: 20),

              InkWell(
                onTap: () => _selectDueDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Ngày đến hạn',
                    prefixIcon: Icon(
                      Icons.calendar_today,
                      color: Colors.blue.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Colors.blue.shade600,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _dueDate == null
                            ? 'Chọn ngày'
                            : DateFormat('dd/MM/yyyy').format(_dueDate!),
                        style: TextStyle(fontSize: 16),
                      ),
                      Icon(Icons.arrow_drop_down, color: Colors.grey),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),

              if (_users.isNotEmpty && _isAdmin)
                DropdownButtonFormField<String>(
                  value: _assignedTo,
                  decoration: InputDecoration(
                    labelText: 'Gán cho người dùng',
                    prefixIcon: Icon(
                      Icons.person_add,
                      color: Colors.blue.shade600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(
                        color: Colors.blue.shade600,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: 'all',
                      child: Text('Gán cho tất cả'),
                    ),
                    ..._users.map((user) {
                      return DropdownMenuItem<String>(
                        value: user.id,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blue.shade100,
                              child: Text(
                                user.username[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 10),
                            Text(user.username),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _assignedTo = value;
                    });
                  },
                ),
              SizedBox(height: 25),

              Text(
                'Tệp đính kèm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 10),
              OutlinedButton(
                onPressed: _pickFiles,
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  side: BorderSide(color: Colors.blue.shade600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.attach_file,
                      color: Colors.blue.shade600,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Chọn tệp đính kèm',
                      style: TextStyle(
                        color: Colors.blue.shade600,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 10),

              if (_attachments.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final path = entry.value;
                    return Chip(
                      label: Text(
                        path.split('/').last,
                        style: TextStyle(fontSize: 14),
                      ),
                      deleteIcon: Icon(Icons.close, size: 18),
                      onDeleted: () => _removeAttachment(index),
                      backgroundColor: Colors.blue.shade50,
                      labelPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleAddTask,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue.shade600,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                  child: Text(
                    'THÊM CÔNG VIỆC',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}