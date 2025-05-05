import 'package:flutter/material.dart';
import 'package:app_04/TaskManager/model/Task.dart';
import 'package:app_04/TaskManager/db/UserDatabaseHelper.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class TaskDetailScreen extends StatefulWidget {
  final Task task;

  const TaskDetailScreen({Key? key, required this.task}) : super(key: key);

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late Task task;
  final DateFormat _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    task = widget.task;
  }

  void _updateStatus(String newStatus) {
    setState(() {
      task = task.copyWith(status: newStatus, updatedAt: DateTime.now());
    });
  }
  Future<String> _getAssignedUserName() async {
    if (task.assignedTo == null || task.assignedTo!.isEmpty) {
      return 'Chưa được gán';
    }

    final user = await UserDatabaseHelper.instance.getUserById(task.assignedTo!);
    return user?.username ?? 'Không rõ người dùng';
  }



  Widget _buildAttachments() {
    if (task.attachments == null || task.attachments!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Không có tệp đính kèm.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: task.attachments!.map((attachment) {
        final fileName = attachment.split('/').last;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: attachment.toLowerCase().endsWith('.jpg') ||
                attachment.toLowerCase().endsWith('.png')
                ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
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
                                File(attachment),
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
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(attachment),
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[200],
                          child: const Center(
                            child: Text('Không tải được ảnh',
                                style: TextStyle(color: Colors.grey)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.image, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      fileName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            )
                : InkWell(
              onTap: () {
                // mở file khác nếu không phải ảnh
              },
              child: Row(
                children: [
                  Icon(Icons.attach_file,
                      color: Theme.of(context).primaryColor),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        Text(
                          'Tệp đính kèm',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.download, color: Colors.grey[500]),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }


  Widget _buildInfoCard(String title, String content, {Widget? trailing}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
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
        title: const Text('Chi tiết Công việc'),
        backgroundColor: Colors.greenAccent,
        elevation: 1,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard('Tiêu đề', task.title),
              _buildInfoCard('Mô tả', task.description.isNotEmpty ? task.description : 'Không có mô tả'),
              _buildInfoCard(
                'Trạng thái',
                task.status,
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task.status),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    task.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              _buildInfoCard('Ưu tiên', _priorityText(task.priority)),
              _buildInfoCard('Ngày tới hạn', task.dueDate != null ? DateFormat('dd/MM/yyyy').format(task.dueDate!) : 'Chưa đặt ngày tới hạn'),
              FutureBuilder<String>(
                future: _getAssignedUserName(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildInfoCard('Người được giao', 'Đang tải...');
                  } else if (snapshot.hasError) {
                    return _buildInfoCard('Người được giao', 'Lỗi khi tải');
                  } else {
                    return _buildInfoCard('Người được giao', snapshot.data ?? 'Không xác định');
                  }
                },
              ),
              _buildInfoCard('Ngày tạo', _dateFormat.format(task.createdAt)),
              _buildInfoCard('Ngày cập nhật', _dateFormat.format(task.updatedAt)),

              const SizedBox(height: 16),
              const Text(
                'Tệp đính kèm',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              _buildAttachments(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'To do':
        return Colors.blue;
      case 'In progress':
        return Colors.orange;
      case 'Done':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _priorityText(int priority) {
    switch (priority) {
      case 1:
        return 'Thấp';
      case 2:
        return 'Trung Bình';
      case 3:
        return 'Cao';
      default:
        return 'Không xác định';
    }
  }
}