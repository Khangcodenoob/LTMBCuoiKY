import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:app_04/TaskManager/model/Task.dart';
import 'package:app_04/TaskManager/model/User.dart';
import 'package:app_04/TaskManager/db/UserDatabaseHelper.dart';
import 'package:app_04/TaskManager/db/TaskDatabaseHelper.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class EditTaskScreen extends StatefulWidget {
  final Task task;
  final String currentUserId;
  final bool isReadOnly;


  const EditTaskScreen({
    Key? key,
    required this.task,
    required this.currentUserId,
    this.isReadOnly = false,
  }) : super(key: key);

  @override
  _EditTaskScreenState createState() => _EditTaskScreenState();
}

class _EditTaskScreenState extends State<EditTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late String _status;
  late int _priority;
  late DateTime? _dueDate;
  late String? _assignedTo;
  late List<String> _attachments;
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
    _titleController = TextEditingController(text: widget.task.title);
    _descriptionController = TextEditingController(text: widget.task.description);
    _status = widget.task.status;
    _priority = widget.task.priority;
    _dueDate = widget.task.dueDate;
    _assignedTo = widget.task.assignedTo;
    _attachments = widget.task.attachments ?? [];
    _loadUsers();
  }


  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      User? currentUser = await UserDatabaseHelper.instance.getUserById(widget.currentUserId);
      _isAdmin = currentUser?.isAdmin ?? false;

      // Chỉ tải danh sách người dùng khi là admin
      if (_isAdmin) {
        _users = await UserDatabaseHelper.instance.getAllUsersExcept(widget.currentUserId);
      } else {
        _users = [];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi tải danh sách người dùng: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _pickFiles() async {
    if (!_isAdmin) return;
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.any,
      );

      if (result != null) {
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
    if (!_isAdmin) return;
    setState(() {
      _attachments.removeAt(index);
    });
  }

  Future<void> _selectDueDate(BuildContext context) async {
    if (!_isAdmin) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
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

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final updatedTask = widget.task.copyWith(
        title: _isAdmin ? _titleController.text : widget.task.title,
        description: _isAdmin ? _descriptionController.text : widget.task.description,
        status: _status,
        priority: _isAdmin ? _priority : widget.task.priority,
        dueDate: _isAdmin ? _dueDate : widget.task.dueDate,
        assignedTo: _isAdmin ? _assignedTo : widget.task.assignedTo,
        attachments: _isAdmin ? (_attachments.isNotEmpty ? _attachments : null) : widget.task.attachments,
        updatedAt: DateTime.now(),
        completed: _status == 'Done',
      );
      Navigator.pop(context, updatedTask);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Chỉnh sửa công việc',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20 , color: Colors.black),
        ),
        backgroundColor: Colors.greenAccent,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(
            Colors.black,
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
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                readOnly: !_isAdmin,
                decoration: InputDecoration(
                  labelText: 'Tiêu đề *',
                  hintText: 'Nhập tiêu đề công việc',
                  prefixIcon: Icon(
                    Icons.title,
                    color: Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.black),
                  ),
                ),
                style: TextStyle(fontSize: 16),
                validator: (value) {
                  if (_isAdmin && (value == null || value.isEmpty)) {
                    return 'Vui lòng nhập tiêu đề';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),

              TextFormField(
                controller: _descriptionController,
                readOnly: !_isAdmin,
                decoration: InputDecoration(
                  labelText: 'Mô tả',
                  hintText: 'Nhập mô tả chi tiết (nếu có)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(
                    Icons.description,
                    color: Colors.black,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.black),
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
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 16),
              Column(
                children: [
                  // Dropdown cho Trạng thái
                  Padding(
                    padding: const EdgeInsets.only(bottom: 15.0),
                    child: DropdownButtonFormField<String>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: 'Trạng thái',
                        labelStyle: TextStyle(
                          color: Colors.black,
                        ),
                        prefixIcon: Icon(
                          Icons.info,
                          color: Colors.black,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                      items: _statusOptions.map((status) {
                        return DropdownMenuItem<String>(
                          value: status,
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: widget.isReadOnly
                          ? null
                          : (value) {
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
                    padding: const EdgeInsets.only(top: 15.0),
                    child: DropdownButtonFormField<int>(
                      value: _priority,
                      decoration: InputDecoration(
                        labelText: 'Độ ưu tiên',
                        labelStyle: TextStyle(
                          color: Colors.black,
                        ),
                        prefixIcon: Icon(
                          Icons.priority_high,
                          color: Colors.black,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(
                            color: Colors.black,
                            width: 2,
                          ),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                      ),
                      items: _priorityOptions.map((option) {
                        return DropdownMenuItem<int>(
                          value: option['value'],
                          child: Text(
                            option['label'],
                            style: TextStyle(
                              fontSize: 16,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: widget.isReadOnly || !_isAdmin
                          ? null
                          : (value) {
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

              // Ngày đến hạn dùng cho cả admin và users
              if (_isAdmin || _users.isNotEmpty || true)
                InkWell(
                  onTap: () => _selectDueDate(context),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Ngày đến hạn',
                      labelStyle: TextStyle(
                        color: Colors.black,
                      ),
                      prefixIcon: Icon(
                        Icons.calendar_today,
                        color: Colors.black,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide(
                          color: Colors.black,
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

              // Gán công việc cho admin và users
              if (_isAdmin && _users.isNotEmpty)
                DropdownButtonFormField<String?>(
                  value: _assignedTo, // Giá trị mặc định là người được gán
                  decoration: InputDecoration(
                    labelText: 'Gán cho người dùng',
                    labelStyle: TextStyle(
                      color: Colors.black,
                    ),
                    prefixIcon: Icon(
                      Icons.person_add,
                      color: Colors.black,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.black,
                      ),
                    ),
                    contentPadding: EdgeInsets.symmetric(vertical: 0),
                  ),
                  items: [
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text('Không gán'),
                    ),
                    ..._users.map((user) {
                      return DropdownMenuItem<String>(
                        value: user.id,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.blueAccent,
                              child: Text(
                                user.username[0].toUpperCase(),
                                style: TextStyle(
                                  color: Colors.black,
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
                  onChanged: widget.isReadOnly || !_isAdmin // User chỉ có thể xem
                      ? null
                      : (value) {
                    setState(() {
                      _assignedTo = value; // Admin có thể thay đổi người được gán
                    });
                  },
                ),

              // Tệp đính kèm ( chỉ có admin được thêm tep )
              SizedBox(height: 7),
              if (_isAdmin) ...[
                Text(
                  'Tệp đính kèm',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                OutlinedButton(
                  onPressed: _pickFiles,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: Colors.black),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.attach_file,
                        color: Colors.black,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Chọn tệp đính kèm',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              SizedBox(height: 10),
              if (_attachments.isNotEmpty) ...[
                SizedBox(height: 20),
                Text(
                  'Tệp đính kèm',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachments.asMap().entries.map((entry) {
                    final index = entry.key;
                    final path = entry.value;
                    final fileName = path.split('/').last;

                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.black,
                            insetPadding: const EdgeInsets.all(10),
                            child: Stack(
                              children: [
                                InteractiveViewer(
                                  child: Image.file(
                                    File(path),
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close, color: Colors.white),
                                    onPressed: () => Navigator.of(context).pop(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Hiển thị hình ảnh thumbnail
                          Image.file(
                            File(path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                          SizedBox(height: 8),
                          Text(
                            fileName,
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 20),
              ],
               //Nút lưu
              if (!widget.isReadOnly) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleSave,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.greenAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                    child: Text(
                      'LƯU THAY ĐỔI',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
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