import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';
import '../services/timezone_service.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../config/constants.dart';
import '../widgets/appointment_card.dart';
import 'draft_forms_screen.dart';
import 'user_profile_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();

  List<AppointmentModel> _appointments = [];
  Map<String, List<UserModel>> _appointmentGuests = {}; // معرف الموعد -> قائمة الضيوف
  Map<String, List<InvitationModel>> _appointmentInvitations = {}; // معرف الموعد -> قائمة الدعوات
  bool _isOnline = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // لتحديث المحتوى عند تغيير التبويب
    });
    _initializeData();
    _listenToConnectivity();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    // تحميل بيانات المستخدم أولاً
    await _authService.initAuth();
    // ثم تحميل المواعيد
    await _loadAppointments();
  }

  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
        if (isConnected) {
          _loadAppointments();
          _syncOfflineAppointments(); // مزامنة المواعيد المحفوظة أوفلاين
        }
      }
    });
  }

  Future<void> _loadAppointments() async {
    if (!mounted) return;

    try {
      // 1. Load from Cache FIRST (instant) ⚡
      await _loadAppointmentsFromCache();

      // 2. Check internet connection
      final isOnline = await _connectivityService.hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);

      // 3. If online, update from PocketHost in background
      if (isOnline && _authService.isAuthenticated) {
        try {
          final records = await _authService.pb
              .collection(AppConstants.appointmentsCollection)
              .getFullList(
                filter: 'host = "${_authService.currentUser?.id}"',
                sort: '-appointment_date',
              );

          final appointments = records.map((record) {
            return AppointmentModel.fromJson(record.toJson());
          }).toList();

          // Save to Cache for next time ⚡
          await _saveAppointmentsToCache(appointments);

          // Also save to local database (backup)
          await _dbService.saveAppointments(appointments);

          // جلب الضيوف والدعوات للمواعيد
          await _loadGuestsAndInvitations(appointments);

          // Update UI with fresh data
          if (!mounted) return;
          setState(() => _appointments = appointments);
        } catch (e) {
          // If server error, keep showing cached data (already loaded)
          // No need to do anything
        }
      }
      // If offline, just show cached data (already loaded in step 1)
    } catch (e) {
      // If any error, try to show empty list
      if (!mounted) return;
      setState(() => _appointments = []);
    }
  }

  // دوال Cache للمواعيد
  Future<void> _loadAppointmentsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedData = prefs.getString('appointments_$userId');
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final appointments = jsonList.map((json) => AppointmentModel.fromJson(json)).toList();
        if (mounted) {
          setState(() => _appointments = appointments);
        }
      }
    } catch (e) {
      // Ignore cache errors
    }
  }

  Future<void> _saveAppointmentsToCache(List<AppointmentModel> appointments) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final jsonList = appointments.map((appointment) => appointment.toJson()).toList();
      await prefs.setString('appointments_$userId', jsonEncode(jsonList));
    } catch (e) {
      // Ignore cache errors
    }
  }

  // جلب الضيوف والدعوات للمواعيد
  Future<void> _loadGuestsAndInvitations(List<AppointmentModel> appointments) async {
    try {
      _appointmentGuests.clear();
      _appointmentInvitations.clear();

      for (final appointment in appointments) {
        // جلب دعوات الموعد
        final invitationRecords = await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .getFullList(
              filter: 'appointment = "${appointment.id}"',
              expand: 'guest',
            );

        final invitations = <InvitationModel>[];
        final guests = <UserModel>[];

        for (final record in invitationRecords) {
          try {
            final invitation = InvitationModel.fromJson(record.toJson());
            invitations.add(invitation);
          } catch (e) {
            print('خطأ في تحليل دعوة: ${record.id} - $e');
            continue; // تجاهل هذه الدعوة والمتابعة
          }

          // جلب بيانات الضيف من expand
          try {
            final guestData = record.get<List<dynamic>>('expand.guest');
            if (guestData.isNotEmpty) {
              final guest = UserModel.fromJson(guestData.first.toJson());
              guests.add(guest);
            }
          } catch (e) {
            // تجاهل الأخطاء في جلب بيانات الضيف
            continue;
          }
        }

        _appointmentInvitations[appointment.id] = invitations;
        _appointmentGuests[appointment.id] = guests;
      }
    } catch (e) {
      print('خطأ في جلب الضيوف والدعوات: $e');
    }
  }

  // دالة نسخ رابط الحساب
  Future<void> _copyProfileLink() async {
    final user = _authService.currentUser;
    if (user != null) {
      final profileLink = 'sijilli.com/${user.username}';
      await Clipboard.setData(ClipboardData(text: profileLink));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم نسخ الرابط: $profileLink'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // دالة مساعدة لرابط الصورة
  String? _getUserAvatarUrl(dynamic user) {
    if (user?.avatar == null || user.avatar?.isEmpty == true) {
      return null;
    }

    final cleanAvatar = user.avatar!.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // دوال فحص حالة المواعيد
  bool _hasTodayAppointments() {
    final today = DateTime.now();
    return _appointments.any((appointment) {
      final appointmentDate = appointment.appointmentDate;
      return appointmentDate.year == today.year &&
             appointmentDate.month == today.month &&
             appointmentDate.day == today.day;
    });
  }

  bool _hasActiveAppointment() {
    final now = DateTime.now();
    return _appointments.any((appointment) {
      final appointmentDate = appointment.appointmentDate;
      final appointmentEnd = appointmentDate.add(const Duration(hours: 1));
      return now.isAfter(appointmentDate) && now.isBefore(appointmentEnd);
    });
  }

  // فحص تداخل الموعد مع مواعيد أخرى
  bool _hasTimeConflict(AppointmentModel appointment) {
    final appointmentStart = appointment.appointmentDate;
    final appointmentEnd = appointmentStart.add(const Duration(minutes: 45));

    return _appointments.any((otherAppointment) {
      // تجاهل نفس الموعد
      if (otherAppointment.id == appointment.id) return false;

      final otherStart = otherAppointment.appointmentDate;
      final otherEnd = otherStart.add(const Duration(minutes: 45));

      // فحص التداخل الزمني
      return appointmentStart.isBefore(otherEnd) && appointmentEnd.isAfter(otherStart);
    });
  }

  // Widget صورة المستخدم
  Widget _buildUserProfilePicture() {
    final user = _authService.currentUser;
    final hasToday = _hasTodayAppointments();
    final hasActive = _hasActiveAppointment();

    // تحديد لون الطوق
    Color ringColor = Colors.grey.shade400; // الوضع الاعتيادي
    List<BoxShadow> shadows = [];

    if (hasActive) {
      // أزرق مشع للخارج عند وجود موعد نشط
      ringColor = const Color(0xFF2196F3);
      shadows = [
        BoxShadow(
          color: const Color(0xFF2196F3).withValues(alpha: 0.4),
          blurRadius: 20,
          spreadRadius: 5,
        ),
        BoxShadow(
          color: const Color(0xFF2196F3).withValues(alpha: 0.2),
          blurRadius: 40,
          spreadRadius: 10,
        ),
      ];
    } else if (hasToday) {
      // أزرق عندما يكون عنده موعد في نفس اليوم
      ringColor = const Color(0xFF2196F3);
    }

    return Center(
      child: Container(
        width: 146, // 140 + (3 * 2) للطوق والفجوة
        height: 146,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: shadows,
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: ringColor,
              width: 3,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(3), // الفجوة بين الصورة والطوق
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade200,
              ),
              child: _getUserAvatarUrl(user) == null
                  ? Icon(
                      Icons.person,
                      size: 70,
                      color: Colors.grey.shade500,
                    )
                  : ClipOval(
                      child: Image.network(
                        _getUserAvatarUrl(user)!,
                        width: 140,
                        height: 140,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) {
                            return child;
                          }
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 3,
                              color: const Color(0xFF2196F3),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            size: 70,
                            color: Colors.grey.shade500,
                          );
                        },
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  // Widget رابط الحساب - تصميم تيك توك
  Widget _buildProfileLink() {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox.shrink();

    final profileLink = 'sijilli.com/${user.username}';

    return Center(
      child: GestureDetector(
        onTap: _copyProfileLink,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profileLink,
              style: TextStyle(
                fontSize: 14, // أصغر
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic, // مائل
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy,
              size: 14, // أصغر أيضاً
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  // Widget اسم المستخدم
  Widget _buildUserDisplayName() {
    final user = _authService.currentUser;
    if (user?.name == null || user!.name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Text(
        user.name,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  // Widget السيرة الذاتية
  Widget _buildUserBio() {
    final user = _authService.currentUser;
    if (user == null || user.bio == null || user.bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          user.bio!,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // Widget مرن لمعلومات المستخدم
  Widget _buildUserInfoSection() {
    final user = _authService.currentUser;
    if (user == null) return const SizedBox(height: 20);

    final hasProfileLink = user.username.isNotEmpty;
    final hasDisplayName = user.name.isNotEmpty;
    final hasBio = user.bio != null && user.bio!.isNotEmpty;

    // إذا لم يكن هناك أي محتوى، أرجع مسافة صغيرة فقط
    if (!hasProfileLink && !hasDisplayName && !hasBio) {
      return const SizedBox(height: 20);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Profile Link
        if (hasProfileLink) ...[
          _buildProfileLink(),
          if (hasDisplayName || hasBio) const SizedBox(height: 4),
        ],

        // User Display Name
        if (hasDisplayName) ...[
          _buildUserDisplayName(),
          if (hasBio) const SizedBox(height: 8),
        ],

        // User Bio
        if (hasBio) _buildUserBio(),

        // مسافة نهائية
        const SizedBox(height: 20),
      ],
    );
  }

  // Widget الأزرار (دائري + كبسولة)
  Widget _buildActionButtons() {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // الزر الدائري للروابط الشخصية
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
              color: Colors.white,
            ),
            child: InkWell(
              onTap: _showPersonalLinks,
              borderRadius: BorderRadius.circular(15),
              child: Icon(
                Icons.link,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // كبسولة الأصدقاء
          Container(
            width: 120,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 1,
              ),
              color: Colors.white,
            ),
            child: InkWell(
              onTap: _showFriends,
              borderRadius: BorderRadius.circular(15),
              child: Center(
                child: Text(
                  'الأصدقاء',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // دالة عرض الروابط الشخصية
  void _showPersonalLinks() {
    final user = _authService.currentUser;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'الروابط الشخصية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Social Links List
              Expanded(
                child: _buildSocialLinksList(scrollController),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // دالة عرض الأصدقاء
  void _showFriends() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FriendsScreen(),
      ),
    );
  }

  // Widget قائمة الروابط الشخصية
  Widget _buildSocialLinksList(ScrollController scrollController) {
    final user = _authService.currentUser;
    if (user == null) {
      return const Center(child: Text('لا يمكن تحميل البيانات'));
    }

    // تحليل الروابط الاجتماعية
    List<Map<String, String>> socialLinks = [];

    if (user.socialLink != null && user.socialLink!.isNotEmpty) {
      try {
        // إذا كانت الروابط في صيغة JSON
        final dynamic linksData = jsonDecode(user.socialLink!);
        if (linksData is Map<String, dynamic>) {
          linksData.forEach((platform, url) {
            if (url != null && url.toString().isNotEmpty) {
              socialLinks.add({
                'platform': platform,
                'url': url.toString(),
                'icon': _getSocialIcon(platform),
              });
            }
          });
        }
      } catch (e) {
        // إذا كانت الروابط في صيغة نص بسيط
        if (user.socialLink!.contains('http')) {
          socialLinks.add({
            'platform': 'رابط',
            'url': user.socialLink!,
            'icon': '🔗',
          });
        }
      }
    }

    if (socialLinks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.link_off,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد روابط شخصية',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'أضف روابطك الاجتماعية في الإعدادات',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: socialLinks.length,
      itemBuilder: (context, index) {
        final link = socialLinks[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  link['icon']!,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            title: Text(
              link['platform']!,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              link['url']!,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              icon: Icon(
                Icons.open_in_new,
                color: Colors.blue.shade600,
                size: 20,
              ),
              onPressed: () => _openUrl(link['url']!),
            ),
            onTap: () => _copyToClipboard(link['url']!),
          ),
        );
      },
    );
  }



  // Widget التبويبات
  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF2196F3),
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: const Color(0xFF2196F3),
        indicatorWeight: 2,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        tabs: const [
          Tab(text: 'المواعيد'),
          Tab(text: 'المقالات'),
        ],
      ),
    );
  }

  // Widget المحتوى كـ Sliver حسب التبويب المختار
  Widget _buildContentSliver() {
    return _tabController.index == 0
        ? _buildAppointmentsSliver()
        : _buildArticlesSliver();
  }

  // Widget تبويب المواعيد كـ Sliver
  Widget _buildAppointmentsSliver() {
    if (_appointments.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // أيقونة التقويم مع X
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  children: [
                    // أيقونة التقويم
                    Center(
                      child: Icon(
                        Icons.calendar_today_outlined,
                        size: 40,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    // علامة X
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'لا توجد مواعيد',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ابدأ بإنشاء موعدك الأول',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => _buildAppointmentCard(_appointments[index]),
          childCount: _appointments.length,
        ),
      ),
    );
  }

  // Widget تبويب المقالات كـ Sliver
  Widget _buildArticlesSliver() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'لا توجد مقالات',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ابدأ بكتابة مقالك الأول',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // Header Section (Profile + Info + Buttons)
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // أزرار التحكم والصورة الرئيسية
                  Stack(
                    children: [
                      // User Profile Picture
                      Container(
                        padding: const EdgeInsets.only(top: 8, bottom: 12),
                        child: _buildUserProfilePicture(),
                      ),

                      // دائرة الأوفلاين في الزاوية اليسرى
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _isOnline ? Colors.green.shade50 : Colors.orange.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isOnline ? Colors.green.shade200 : Colors.orange.shade200,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _isOnline ? Icons.wifi : Icons.wifi_off,
                            size: 18,
                            color: _isOnline ? Colors.green.shade700 : Colors.orange.shade700,
                          ),
                        ),
                      ),

                      // زر المسودات في الزاوية اليمنى (للآدمن فقط)
                      if (_authService.currentUser?.role == 'admin')
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2196F3).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF2196F3).withValues(alpha: 0.3),
                                width: 1.5,
                              ),
                            ),
                            child: IconButton(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const DraftFormsScreen(),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.description_outlined,
                                color: Color(0xFF2196F3),
                                size: 18,
                              ),
                              tooltip: 'مسودات النماذج',
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                    ],
                  ),

                  // User Info Section (Flexible)
                  _buildUserInfoSection(),

                  // Action Buttons (دائري + كبسولة)
                  _buildActionButtons(),
                  const SizedBox(height: 20),

                  // Tab Bar
                  _buildTabBar(),
                ],
              ),
            ),

            // Content Section (Based on selected tab)
            _buildContentSliver(),
          ],
        ),
      ),
    );
  }





  // دالة الحصول على أيقونة المنصة الاجتماعية
  String _getSocialIcon(String platform) {
    switch (platform.toLowerCase()) {
      case 'twitter':
      case 'x':
        return '🐦';
      case 'instagram':
        return '📷';
      case 'facebook':
        return '📘';
      case 'linkedin':
        return '💼';
      case 'youtube':
        return '📺';
      case 'tiktok':
        return '🎵';
      case 'snapchat':
        return '👻';
      case 'telegram':
        return '✈️';
      case 'whatsapp':
        return '💬';
      case 'github':
        return '🐙';
      case 'website':
      case 'site':
        return '🌐';
      default:
        return '🔗';
    }
  }

  // دالة فتح الرابط (نسخ للحافظة)
  void _openUrl(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ الرابط: $url'),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'فتح',
            textColor: Colors.white,
            onPressed: () {
              // يمكن إضافة url_launcher لاحقاً
            },
          ),
        ),
      );
    }
  }

  // دالة نسخ الرابط
  void _copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم نسخ الرابط: $text'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    final guests = _appointmentGuests[appointment.id] ?? [];
    final invitations = _appointmentInvitations[appointment.id] ?? [];

    return AppointmentCard(
      appointment: appointment,
      guests: guests,
      invitations: invitations,
      onTap: () {
        // يمكن إضافة التنقل لصفحة تفاصيل الموعد هنا
      },
      onPrivacyChanged: (newPrivacy) async {
        // تحديث الموعد في القائمة المحلية
        final updatedAppointments = _appointments.map((apt) {
          if (apt.id == appointment.id) {
            return AppointmentModel(
              id: apt.id,
              title: apt.title,
              region: apt.region,
              building: apt.building,
              privacy: newPrivacy,
              status: apt.status,
              appointmentDate: apt.appointmentDate,
              hostId: apt.hostId,
              streamLink: apt.streamLink,
              noteShared: apt.noteShared,
              created: apt.created,
              updated: apt.updated,
            );
          }
          return apt;
        }).toList();

        setState(() {
          _appointments = updatedAppointments;
        });

        // حفظ التحديث في الكاش
        await _saveAppointmentsToCache(_appointments);
      },
      onGuestsChanged: (selectedGuestIds) async {
        // تحديث دعوات الضيوف
        await _updateAppointmentGuests(appointment.id, selectedGuestIds);
      },
    );
  }

  // تحديث ضيوف الموعد
  Future<void> _updateAppointmentGuests(String appointmentId, List<String> selectedGuestIds) async {
    try {
      // الحصول على الدعوات الحالية
      final currentInvitations = _appointmentInvitations[appointmentId] ?? [];
      final currentGuestIds = currentInvitations.map((inv) => inv.guestId).toSet();
      final newGuestIds = selectedGuestIds.toSet();

      // إضافة دعوات جديدة
      for (final guestId in newGuestIds.difference(currentGuestIds)) {
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .create(body: {
          'appointment': appointmentId,
          'guest': guestId,
          'status': 'invited',
        });
      }

      // حذف الدعوات المحذوفة
      for (final guestId in currentGuestIds.difference(newGuestIds)) {
        final invitation = currentInvitations.firstWhere((inv) => inv.guestId == guestId);
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .delete(invitation.id);
      }

      // إعادة تحميل الضيوف والدعوات
      await _loadGuestsAndInvitations(_appointments);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('خطأ في تحديث ضيوف الموعد: $e');
    }
  }

  // مزامنة المواعيد المحفوظة أوفلاين
  Future<void> _syncOfflineAppointments() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final offlineAppointments = prefs.getStringList('offline_appointments') ?? [];
      final offlineInvitations = prefs.getStringList('offline_invitations') ?? [];

      if (offlineAppointments.isEmpty) return;

      print('🔄 بدء مزامنة ${offlineAppointments.length} موعد محفوظ أوفلاين');

      List<String> syncedAppointments = [];
      List<String> syncedInvitations = [];

      // مزامنة المواعيد
      for (String appointmentJson in offlineAppointments) {
        try {
          final appointmentData = jsonDecode(appointmentJson);
          final tempId = appointmentData['temp_id'];

          // إزالة البيانات المؤقتة
          appointmentData.remove('id');
          appointmentData.remove('temp_id');
          appointmentData.remove('sync_status');
          appointmentData.remove('created_offline');

          // رفع الموعد للخادم
          final record = await _authService.pb
              .collection(AppConstants.appointmentsCollection)
              .create(body: appointmentData);

          print('✅ تم رفع الموعد: ${appointmentData['title']}');

          // البحث عن الدعوات المرتبطة بهذا الموعد
          final relatedInvitations = offlineInvitations.where((invJson) {
            final invData = jsonDecode(invJson);
            return invData['appointment_temp_id'] == tempId;
          }).toList();

          // رفع الدعوات
          for (String invJson in relatedInvitations) {
            try {
              final invData = jsonDecode(invJson);
              final guests = List<String>.from(invData['guests']);

              for (String guestId in guests) {
                await _authService.pb
                    .collection(AppConstants.invitationsCollection)
                    .create(body: {
                  'appointment': record.id,
                  'guest': guestId,
                  'status': 'invited',
                });
              }

              syncedInvitations.add(invJson);
              print('✅ تم رفع دعوات الموعد');
            } catch (e) {
              print('❌ خطأ في رفع دعوة: $e');
            }
          }

          syncedAppointments.add(appointmentJson);

        } catch (e) {
          print('❌ خطأ في رفع موعد: $e');
        }
      }

      // إزالة المواعيد المرفوعة من التخزين المحلي
      if (syncedAppointments.isNotEmpty) {
        final remainingAppointments = offlineAppointments
            .where((apt) => !syncedAppointments.contains(apt))
            .toList();
        await prefs.setStringList('offline_appointments', remainingAppointments);

        final remainingInvitations = offlineInvitations
            .where((inv) => !syncedInvitations.contains(inv))
            .toList();
        await prefs.setStringList('offline_invitations', remainingInvitations);

        print('🎉 تم رفع ${syncedAppointments.length} موعد بنجاح');

        // إعادة تحميل المواعيد لعرض البيانات المحدثة
        _loadAppointments();
      }

    } catch (e) {
      print('❌ خطأ في مزامنة المواعيد: $e');
    }
  }
}
