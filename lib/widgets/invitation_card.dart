import 'package:flutter/material.dart';
import 'package:sijilli/models/appointment_model.dart';
import 'package:sijilli/models/user_model.dart';
import 'package:sijilli/models/invitation_model.dart';
import 'package:sijilli/services/auth_service.dart';
import 'package:sijilli/services/timezone_service.dart';
import 'package:sijilli/config/constants.dart';

class InvitationCard extends StatefulWidget {
  final AppointmentModel appointment;
  final UserModel host;
  final InvitationModel invitation;
  final VoidCallback? onResponseChanged;

  const InvitationCard({
    super.key,
    required this.appointment,
    required this.host,
    required this.invitation,
    this.onResponseChanged,
  });

  @override
  State<InvitationCard> createState() => _InvitationCardState();
}

class _InvitationCardState extends State<InvitationCard> {
  final AuthService _authService = AuthService();
  bool _isResponding = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getBorderColor(),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // هيدر الدعوة
            _buildInvitationHeader(),
            const SizedBox(height: 12),
            
            // تفاصيل الموعد
            _buildAppointmentDetails(),
            const SizedBox(height: 16),
            
            // أزرار الاستجابة أو حالة الرد
            _buildResponseSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildInvitationHeader() {
    return Row(
      children: [
        // صورة المضيف
        CircleAvatar(
          radius: 20,
          backgroundColor: Colors.blue.shade100,
          backgroundImage: (widget.host.avatar?.isNotEmpty ?? false)
              ? NetworkImage(_getHostAvatarUrl())
              : null,
          child: (widget.host.avatar?.isEmpty ?? true)
              ? Icon(
                  Icons.person,
                  color: Colors.blue.shade700,
                  size: 20,
                )
              : null,
        ),
        const SizedBox(width: 12),
        
        // معلومات الدعوة
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'دعوة موعد جديد',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'من ${widget.host.name}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        
        // حالة الدعوة
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildAppointmentDetails() {
    final localDate = TimezoneService.toLocal(widget.appointment.appointmentDate);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الموعد
          Text(
            widget.appointment.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          
          // التاريخ والوقت
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                _formatDateTime(localDate),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          
          // المكان (إذا كان متاحاً)
          if (widget.appointment.region?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.appointment.region!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ],
          
          // الخصوصية
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                widget.appointment.privacy == 'private' 
                    ? Icons.lock 
                    : Icons.public,
                size: 16,
                color: Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                widget.appointment.privacy == 'private' ? 'خاص' : 'عام',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResponseSection() {
    if (widget.invitation.status == 'invited') {
      // أزرار الاستجابة للدعوات المعلقة
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isResponding ? null : () => _respondToInvitation('accepted'),
              icon: _isResponding 
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('موافق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isResponding ? null : () => _respondToInvitation('rejected'),
              icon: const Icon(Icons.close, size: 18),
              label: const Text('رفض'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      // عرض حالة الرد
      return _buildResponseStatus();
    }
  }

  Widget _buildResponseStatus() {
    IconData icon;
    Color color;
    String text;
    
    switch (widget.invitation.status) {
      case 'accepted':
        icon = Icons.check_circle;
        color = Colors.green;
        text = 'تم قبول الدعوة';
        break;
      case 'rejected':
        icon = Icons.cancel;
        color = Colors.red;
        text = 'تم رفض الدعوة';
        break;
      default:
        icon = Icons.help;
        color = Colors.grey;
        text = 'حالة غير معروفة';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;
    
    switch (widget.invitation.status) {
      case 'invited':
        color = Colors.orange;
        text = 'معلق';
        break;
      case 'accepted':
        color = Colors.green;
        text = 'مقبول';
        break;
      case 'rejected':
        color = Colors.red;
        text = 'مرفوض';
        break;
      default:
        color = Colors.grey;
        text = 'غير معروف';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getBorderColor() {
    switch (widget.invitation.status) {
      case 'invited':
        return Colors.orange.withValues(alpha: 0.3);
      case 'accepted':
        return Colors.green.withValues(alpha: 0.3);
      case 'rejected':
        return Colors.red.withValues(alpha: 0.3);
      default:
        return Colors.grey.withValues(alpha: 0.3);
    }
  }

  String _getHostAvatarUrl() {
    return '${AppConstants.pocketbaseUrl}/api/files/users/${widget.host.id}/${widget.host.avatar}';
  }

  String _formatDateTime(DateTime dateTime) {
    final weekdays = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    
    final weekday = weekdays[dateTime.weekday % 7];
    final month = months[dateTime.month - 1];
    final hour = dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
    
    return '$weekday، ${dateTime.day} $month ${dateTime.year} - $displayHour:$minute $period';
  }

  Future<void> _respondToInvitation(String response) async {
    if (_isResponding) return;
    
    setState(() => _isResponding = true);
    
    try {
      // تحديث الدعوة في قاعدة البيانات
      await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .update(widget.invitation.id, body: {
        'status': response,
        'respondedAt': DateTime.now().toIso8601String(),
      });
      
      // إظهار رسالة نجاح
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response == 'accepted' 
                  ? '✅ تم قبول الدعوة بنجاح'
                  : '❌ تم رفض الدعوة',
            ),
            backgroundColor: response == 'accepted' ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // إعادة تحميل البيانات
        widget.onResponseChanged?.call();
      }
      
    } catch (e) {
      print('❌ خطأ في الرد على الدعوة: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ حدث خطأ في الرد على الدعوة'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isResponding = false);
      }
    }
  }
}
