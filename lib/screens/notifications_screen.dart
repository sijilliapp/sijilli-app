import 'package:flutter/material.dart';
import 'package:sijilli/services/auth_service.dart';
import 'package:sijilli/utils/arabic_search_utils.dart';
import 'package:sijilli/models/appointment_model.dart';
import 'package:sijilli/models/user_model.dart';
import 'package:sijilli/models/invitation_model.dart';
import 'package:sijilli/config/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  late TabController _tabController;

  List<NotificationModel> _notifications = [];
  List<VisitorModel> _visitors = [];
  List<NotificationModel> _filteredNotifications = [];
  List<VisitorModel> _filteredVisitors = [];

  bool _isLoading = false;
  String _searchQuery = '';

  // تتبع الدعوات المحدثة محلياً
  final Map<String, String> _localInvitationUpdates = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      print('🔄 بداية تحميل البيانات...');
      await _loadNotifications();
      await _loadVisitors();
      print('✅ تم تحميل البيانات بنجاح');
    } catch (e) {
      print('❌ خطأ في تحميل البيانات: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        print('🏁 انتهاء تحميل البيانات - _isLoading = false');
      }
    }
  }

  Future<void> _loadNotifications() async {
    print('🚀 تحميل الإشعارات السريع من قاعدة البيانات');

    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) {
        print('❌ لا يوجد مستخدم مسجل دخول');
        return;
      }

      print('🔍 جلب الدعوات للمستخدم: $currentUserId');

      // جلب الدعوات مع البيانات المرتبطة في استعلام واحد محسن
      final invitationRecords = await _authService.pb
          .collection('invitations')
          .getFullList(
            sort: '-created',
            expand: 'appointment,appointment.host,guest',
            filter: 'guest = "$currentUserId" || appointment.host = "$currentUserId"',
          );

      print('📊 تم جلب ${invitationRecords.length} دعوة مرتبطة بالمستخدم');

      List<NotificationModel> notifications = [];

      // تخزين مؤقت للبيانات لتجنب الاستعلامات المتكررة
      Map<String, dynamic> appointmentCache = {};
      Map<String, dynamic> userCache = {};

      for (final record in invitationRecords) {
        try {
          print('🔍 معالجة دعوة: ${record.id}');

          final guestId = record.data['guest'] as String?;
          final status = record.data['status'] as String?;

          if (guestId == null || status == null) {
            print('❌ بيانات ناقصة في الدعوة ${record.id}');
            continue;
          }

          // جلب البيانات المرتبطة مع التخزين المؤقت الذكي
          final appointmentId = record.data['appointment'] as String?;
          if (appointmentId == null) {
            print('❌ معرف الموعد مفقود في الدعوة ${record.id}');
            continue;
          }

          // جلب بيانات الموعد مع التخزين المؤقت
          dynamic appointmentData;
          if (appointmentCache.containsKey(appointmentId)) {
            appointmentData = appointmentCache[appointmentId];
            print('📋 استخدام بيانات الموعد من التخزين المؤقت: $appointmentId');
          } else {
            print('🔍 جلب بيانات الموعد: $appointmentId');
            appointmentData = await _authService.pb
                .collection('appointments')
                .getOne(appointmentId);
            appointmentCache[appointmentId] = appointmentData;
          }

          final hostId = appointmentData.data['host'] as String?;
          if (hostId == null) {
            print('❌ معرف المضيف مفقود في الموعد');
            continue;
          }

          // جلب بيانات المضيف مع التخزين المؤقت
          dynamic hostData;
          if (userCache.containsKey(hostId)) {
            hostData = userCache[hostId];
            print('📋 استخدام بيانات المضيف من التخزين المؤقت: $hostId');
          } else {
            print('🔍 جلب بيانات المضيف: $hostId');
            hostData = await _authService.pb
                .collection('users')
                .getOne(hostId);
            userCache[hostId] = hostData;
          }

          // جلب بيانات الضيف مع التخزين المؤقت
          dynamic guestData;
          if (userCache.containsKey(guestId)) {
            guestData = userCache[guestId];
            print('📋 استخدام بيانات الضيف من التخزين المؤقت: $guestId');
          } else {
            print('🔍 جلب بيانات الضيف: $guestId');
            guestData = await _authService.pb
                .collection('users')
                .getOne(guestId);
            userCache[guestId] = guestData;
          }

          // إنشاء الإشعار حسب المستخدم الحالي ونوع الدعوة
          NotificationModel? notification;

          if (guestId == currentUserId) {
            // المستخدم الحالي هو الضيف - إظهار الدعوة بجميع حالاتها
            final hostName = _extractStringFromData(hostData.data['name'], 'مستخدم');
            final appointmentTitle = appointmentData.data['title'] ?? 'موعد';

            notification = NotificationModel(
              id: 'inv_${record.id}',
              title: 'دعوة موعد',
              message: 'دعاك $hostName لموعد $appointmentTitle',
              type: NotificationType.invitation,
              isRead: false,
              createdAt: DateTime.parse(record.data['created']),
              senderId: hostId,
              senderName: hostName,
              senderAvatar: _extractStringFromData(hostData.data['avatar'], ''),
            );

            print('✅ إشعار دعوة للضيف: $hostName -> $appointmentTitle (حالة: $status)');

          } else if (hostId == currentUserId && status != 'invited') {
            // المستخدم الحالي هو المضيف وتم الرد على دعوته
            final guestName = _extractStringFromData(guestData.data['name'], 'مستخدم');
            final appointmentTitle = appointmentData.data['title'] ?? 'موعد';

            if (status == 'accepted') {
              notification = NotificationModel(
                id: 'inv_${record.id}',
                title: 'تم قبول الدعوة',
                message: 'قبل $guestName دعوتك لموعد $appointmentTitle',
                type: NotificationType.acceptance,
                isRead: false,
                createdAt: DateTime.parse(record.data['updated'] ?? record.data['created']),
                senderId: guestId,
                senderName: guestName,
                senderAvatar: _extractStringFromData(guestData.data['avatar'], ''),
              );

              print('✅ إشعار قبول: $guestName -> $appointmentTitle');

            } else if (status == 'rejected') {
              notification = NotificationModel(
                id: 'inv_${record.id}',
                title: 'تم رفض الدعوة',
                message: 'رفض $guestName دعوتك لموعد $appointmentTitle',
                type: NotificationType.rejection,
                isRead: false,
                createdAt: DateTime.parse(record.data['updated'] ?? record.data['created']),
                senderId: guestId,
                senderName: guestName,
                senderAvatar: _extractStringFromData(guestData.data['avatar'], ''),
              );

              print('✅ إشعار رفض: $guestName -> $appointmentTitle');
            }
          }

          if (notification != null) {
            notifications.add(notification);
          }

        } catch (e) {
          print('❌ خطأ في معالجة دعوة ${record.id}: $e');
          continue;
        }
      }

      print('✅ تم إنشاء ${notifications.length} إشعار من قاعدة البيانات');

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _filteredNotifications = List.from(notifications);
        });
      }

    } catch (e) {
      print('❌ خطأ في تحميل الإشعارات: $e');
      if (mounted) {
        setState(() {
          _notifications = [];
          _filteredNotifications = [];
        });
      }
    }
  }

  String _extractStringFromData(dynamic data, String defaultValue) {
    if (data == null) return defaultValue;
    if (data is String) return data;
    if (data is List && data.isNotEmpty) return data.first.toString();
    return defaultValue;
  }

  Future<void> _loadVisitors() async {
    try {
      // إضافة زوار تجريبيين
      List<VisitorModel> visitors = [
        VisitorModel(
          id: 'visitor_1',
          visitorId: 'visitor_user_1',
          visitorName: 'خالد أحمد',
          visitorAvatar: '',
          profileSection: 'الملف الشخصي',
          visitedAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
        VisitorModel(
          id: 'visitor_2',
          visitorId: 'visitor_user_2',
          visitorName: 'فاطمة محمد',
          visitorAvatar: '',
          profileSection: 'المواعيد',
          visitedAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
      ];

      if (mounted) {
        setState(() {
          _visitors = visitors;
          _filteredVisitors = List.from(visitors);
        });
      }
    } catch (e) {
      print('❌ خطأ في تحميل الزوار: $e');
    }
  }

  void _filterData(String query) {
    setState(() {
      _searchQuery = query;
      
      if (query.isEmpty) {
        _filteredNotifications = List.from(_notifications);
        _filteredVisitors = List.from(_visitors);
      } else {
        _filteredNotifications = _notifications.where((notification) {
          return ArabicSearchUtils.matchesArabicSearch(notification.title, query) ||
                 ArabicSearchUtils.matchesArabicSearch(notification.message, query) ||
                 ArabicSearchUtils.matchesArabicSearch(notification.senderName, query);
        }).toList();

        _filteredVisitors = _visitors.where((visitor) {
          return ArabicSearchUtils.matchesArabicSearch(visitor.visitorName, query) ||
                 ArabicSearchUtils.matchesArabicSearch(visitor.profileSection, query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'صندوق الوارد',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey[600],
          indicatorColor: Theme.of(context).primaryColor,
          tabs: [
            Tab(
              text: 'الإشعارات (${_filteredNotifications.length})',
            ),
            Tab(
              text: 'سجل الزوار (${_filteredVisitors.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // حقل البحث
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: _filterData,
              decoration: InputDecoration(
                hintText: 'البحث في الإشعارات والزوار...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ),
          // محتوى التبويبات
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationsList(),
                _buildVisitorsList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredNotifications.isEmpty) {
      return _buildEmptyState(
        icon: Icons.notifications_outlined,
        title: 'لا توجد إشعارات',
        subtitle: _searchQuery.isEmpty 
            ? 'ستظهر الإشعارات هنا عند وصولها'
            : 'لا توجد إشعارات تطابق البحث',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredNotifications.length,
        itemBuilder: (context, index) {
          final notification = _filteredNotifications[index];
          return _buildNotificationCard(notification);
        },
      ),
    );
  }

  Widget _buildVisitorsList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredVisitors.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline,
        title: 'لا يوجد زوار',
        subtitle: _searchQuery.isEmpty
            ? 'ستظهر زيارات ملفك الشخصي هنا'
            : 'لا يوجد زوار يطابقون البحث',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _filteredVisitors.length,
        itemBuilder: (context, index) {
          final visitor = _filteredVisitors[index];
          return _buildVisitorCard(visitor);
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification) {
    // كارد دعوة تفاعلي مباشر
    if (notification.type == NotificationType.invitation) {
      return _buildInvitationCard(notification);
    }

    // كارد إشعار عادي
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _getNotificationColor(notification.type).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            _getNotificationIcon(notification.type),
            color: _getNotificationColor(notification.type),
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification.message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  notification.senderName,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(notification.createdAt),
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        onTap: () => _onNotificationTap(notification),
      ),
    );
  }

  Widget _buildVisitorCard(VisitorModel visitor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          backgroundColor: Colors.blue[100],
          child: Text(
            visitor.visitorName.isNotEmpty ? visitor.visitorName[0] : '؟',
            style: TextStyle(
              color: Colors.blue[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          visitor.visitorName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'زار ${visitor.profileSection}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatTime(visitor.visitedAt),
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        onTap: () => _onVisitorTap(visitor),
      ),
    );
  }

  // كارد دعوة تفاعلي مباشر
  Widget _buildInvitationCard(NotificationModel notification) {
    final invitationId = notification.id.replaceFirst('inv_', '');
    final localStatus = _localInvitationUpdates[invitationId];

    return FutureBuilder<Map<String, dynamic>?>(
      key: ValueKey('invitation_${notification.id}_${localStatus ?? 'original'}'),
      future: _loadInvitationData(notification),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: const Text(
              'خطأ في تحميل بيانات الدعوة',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          );
        }

        final data = snapshot.data!;
        final invitation = data['invitation'] as InvitationModel;
        final appointment = data['appointment'] as AppointmentModel;
        final host = data['host'] as UserModel;

        return _buildInteractiveInvitationCard(invitation, appointment, host);
      },
    );
  }

  // تحميل بيانات الدعوة
  Future<Map<String, dynamic>?> _loadInvitationData(NotificationModel notification) async {
    try {
      final invitationId = notification.id.replaceFirst('inv_', '');

      final invitationRecord = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getOne(invitationId);

      var invitation = InvitationModel.fromJson(invitationRecord.toJson());

      // تطبيق التحديثات المحلية إذا وجدت
      if (_localInvitationUpdates.containsKey(invitationId)) {
        final localStatus = _localInvitationUpdates[invitationId]!;
        invitation = invitation.copyWith(
          status: localStatus,
          respondedAt: DateTime.now(),
        );
      }

      final appointmentRecord = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getOne(invitation.appointmentId);

      final appointment = AppointmentModel.fromJson(appointmentRecord.toJson());

      final hostRecord = await _authService.pb
          .collection(AppConstants.usersCollection)
          .getOne(appointment.hostId);

      final host = UserModel.fromJson(hostRecord.toJson());

      return {
        'invitation': invitation,
        'appointment': appointment,
        'host': host,
      };
    } catch (e) {
      print('خطأ في تحميل بيانات الدعوة: $e');
      return null;
    }
  }

  // كارد الدعوة التفاعلي الجديد
  Widget _buildInteractiveInvitationCard(InvitationModel invitation, AppointmentModel appointment, UserModel host) {
    final isResponded = invitation.status != 'invited';
    final isAccepted = invitation.status == 'accepted';
    final isRejected = invitation.status == 'rejected';

    Color borderColor;
    if (isAccepted) {
      borderColor = Colors.green;
    } else if (isRejected) {
      borderColor = Colors.red;
    } else {
      borderColor = Colors.orange;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // زر الحذف في الزاوية العلوية
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => _deleteInvitation(invitation),
              icon: const Icon(Icons.close, size: 20),
              style: IconButton.styleFrom(
                backgroundColor: Colors.grey.shade100,
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(28, 28),
              ),
            ),
          ),

          // محتوى الكارد
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // معلومات المضيف
                Row(
                  children: [
                    // صورة المضيف
                    CircleAvatar(
                      radius: 24,
                      backgroundImage: (host.avatar?.isNotEmpty ?? false)
                          ? NetworkImage('${AppConstants.pocketbaseUrl}/api/files/_pb_users_auth_/${host.id}/${host.avatar}')
                          : null,
                      backgroundColor: Colors.blue.shade100,
                      child: (host.avatar?.isEmpty ?? true)
                          ? Text(
                              host.name.isNotEmpty ? host.name[0] : '؟',
                              style: TextStyle(
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),

                    // اسم المضيف
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            host.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'دعاك إلى موعد',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // تفاصيل الموعد
                _buildAppointmentDetails(appointment),

                const SizedBox(height: 16),

                // أزرار الاستجابة أو حالة الاستجابة
                if (!isResponded) ...[
                  // أزرار القبول والرفض
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _respondToInvitation(invitation, 'accepted'),
                          icon: const Icon(Icons.check, color: Colors.white),
                          label: const Text('موافق', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _respondToInvitation(invitation, 'rejected'),
                          icon: const Icon(Icons.close, color: Colors.white),
                          label: const Text('رفض', style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  // حالة الاستجابة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: isAccepted ? Colors.green.shade50 : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isAccepted ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isAccepted ? Icons.check_circle : Icons.cancel,
                          color: isAccepted ? Colors.green : Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isAccepted ? 'تمت الموافقة' : 'تم الرفض',
                          style: TextStyle(
                            color: isAccepted ? Colors.green.shade700 : Colors.red.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // بناء تفاصيل الموعد
  Widget _buildAppointmentDetails(AppointmentModel appointment) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // عنوان الموعد
          Text(
            appointment.title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),

          // التاريخ والوقت
          Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                _formatAppointmentDate(appointment.appointmentDate),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 8),
              Text(
                _formatAppointmentTime(appointment.appointmentDate),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),

          // المكان إذا كان متوفراً
          if (appointment.region?.isNotEmpty ?? false) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${appointment.region}${appointment.building?.isNotEmpty ?? false ? ' - ${appointment.building}' : ''}',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // الخصوصية
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: appointment.privacy == 'public' ? Colors.green.shade100 : Colors.orange.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              appointment.privacy == 'public' ? 'عام' : 'خاص',
              style: TextStyle(
                fontSize: 12,
                color: appointment.privacy == 'public' ? Colors.green.shade700 : Colors.orange.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // الرد على الدعوة
  Future<void> _respondToInvitation(InvitationModel invitation, String response) async {
    try {
      // تحديث قاعدة البيانات
      await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .update(invitation.id, body: {
        'status': response,
        'respondedAt': DateTime.now().toIso8601String(),
      });

      // تحديث الحالة محلياً بدلاً من إعادة التحميل الكامل
      if (mounted) {
        setState(() {
          // حفظ التحديث محلياً
          _localInvitationUpdates[invitation.id] = response;
        });

        // إظهار رسالة نجاح
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
      }
    } catch (e) {
      print('❌ خطأ في الرد على الدعوة: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('حدث خطأ أثناء الرد على الدعوة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // حذف الدعوة
  Future<void> _deleteInvitation(InvitationModel invitation) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدعوة'),
        content: const Text('هل تريد حذف هذه الدعوة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // حذف الإشعار محلياً
        setState(() {
          _notifications.removeWhere((n) => n.id == 'inv_${invitation.id}');
          _filteredNotifications.removeWhere((n) => n.id == 'inv_${invitation.id}');
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم حذف الدعوة'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        print('خطأ في حذف الدعوة: $e');
      }
    }
  }

  // تنسيق تاريخ الموعد
  String _formatAppointmentDate(DateTime date) {
    final months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  // تنسيق وقت الموعد
  String _formatAppointmentTime(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? 'م' : 'ص';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:$minute $period';
  }

  Color _getNotificationColor(NotificationType type) {
    switch (type) {
      case NotificationType.invitation:
        return Colors.blue;
      case NotificationType.acceptance:
        return Colors.green;
      case NotificationType.rejection:
        return Colors.red;
      case NotificationType.reminder:
        return Colors.orange;
      case NotificationType.general:
        return Colors.grey;
    }
  }

  IconData _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.invitation:
        return Icons.event_available;
      case NotificationType.acceptance:
        return Icons.check_circle;
      case NotificationType.rejection:
        return Icons.cancel;
      case NotificationType.reminder:
        return Icons.access_time;
      case NotificationType.general:
        return Icons.info;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    if (!notification.isRead) {
      setState(() {
        notification.isRead = true;
      });
    }

    // لا نحتاج للتنقل - الكارد سيكون تفاعلي مباشرة
  }



  void _onVisitorTap(VisitorModel visitor) {
    // TODO: التنقل لملف المستخدم
  }
}

// النماذج
enum NotificationType {
  invitation,
  acceptance,
  rejection,
  reminder,
  general,
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  bool isRead;
  final DateTime createdAt;
  final String senderId;
  final String senderName;
  final String senderAvatar;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    required this.senderId,
    required this.senderName,
    required this.senderAvatar,
  });
}

class VisitorModel {
  final String id;
  final String visitorId;
  final String visitorName;
  final String visitorAvatar;
  final String profileSection;
  final DateTime visitedAt;

  VisitorModel({
    required this.id,
    required this.visitorId,
    required this.visitorName,
    required this.visitorAvatar,
    required this.profileSection,
    required this.visitedAt,
  });
}
