import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/date_converter.dart';
import '../utils/arabic_search_utils.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/connectivity_service.dart';
import '../services/timezone_service.dart';
import '../services/sunset_service.dart';
import '../models/user_model.dart';
import '../models/appointment_model.dart';
import '../config/constants.dart';
import 'home_screen.dart';
import 'editable_settings_screen.dart';
import 'user_profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final GlobalKey<_AddAppointmentScreenState> _addAppointmentKey = GlobalKey<_AddAppointmentScreenState>();

  // Temporary placeholder screens
  List<Widget> get _screens => [
    const HomeScreen(), // الرئيسية
    const NotificationsScreen(), // الإشعارات
    AddAppointmentScreen(key: _addAppointmentKey), // إضافة
    const SearchScreen(), // البحث
    const EditableSettingsScreen(), // الإعدادات
  ];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: _screens[_currentIndex],
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(
                    icon: Icons.home_rounded,
                    label: 'الرئيسية',
                    index: 0,
                  ),
                  _buildNavItem(
                    icon: Icons.notifications_rounded,
                    label: 'الإشعارات',
                    index: 1,
                  ),
                  _buildNavItem(
                    icon: Icons.add_circle_rounded,
                    label: 'إضافة',
                    index: 2,
                    isCenter: true,
                  ),
                  _buildNavItem(
                    icon: Icons.search_rounded,
                    label: 'البحث',
                    index: 3,
                  ),
                  _buildNavItem(
                    icon: Icons.settings_rounded,
                    label: 'الإعدادات',
                    index: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    bool isCenter = false,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF2196F3) : Colors.grey.shade600;

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            // إذا كان المستخدم ينتقل من الإعدادات إلى صفحة الإضافة، قم بتحديث التواريخ
            if (_currentIndex == 4 && index == 2) {
              // تحديث التواريخ في صفحة الإضافة عند العودة من الإعدادات
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _addAppointmentKey.currentState?._refreshDatesFromSettings();
              });
            }
            _currentIndex = index;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: isCenter ? 32 : 26),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Placeholder Screens
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Text(
                'الإشعارات',
                style: TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'لا توجد إشعارات',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AddAppointmentScreen extends StatefulWidget {
  const AddAppointmentScreen({super.key});

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _regionController = TextEditingController();
  final _buildingController = TextEditingController();
  final _searchController = TextEditingController();
  final _notesController = TextEditingController();
  final AuthService _authService = AuthService();
  final DatabaseService _dbService = DatabaseService();
  final ConnectivityService _connectivityService = ConnectivityService();

  bool _isPrivate = false;
  bool _isSaving = false;
  String _dateType = 'ميلادي';
  String _selectedMonth = 'يناير';
  int _selectedDay = DateTime.now().day;
  int _selectedYear = DateTime.now().year;
  String _selectedWeekday = 'السبت';
  int _selectedHour = 9;
  int _selectedMinute = 0;
  String _selectedPeriod = 'مساءً';
  String _selectedDuration = '45 دقيقة';
  int _endDay = DateTime.now().day;
  String _endMonth = 'يناير';
  int _endYear = DateTime.now().year;

  // متغيرات تاريخ الانتهاء الهجري
  int _endHijriDay = 1;
  String _endHijriMonth = 'محرم';
  int _endHijriYear = 1446;

  // Precise date conversion using centralized DateConverter
  late DateTime _selectedGregorianDate;
  late HijriCalendar _selectedHijriDate;

  // Guest management
  List<String> _selectedGuests = [];
  String _searchQuery = '';

  // Real friends data from follows/followers
  List<UserModel> _availableFriends = [];
  List<UserModel> _filteredFriends = [];
  bool _isLoadingFriends = false;

  // Conflict checking data
  Map<String, List<AppointmentModel>> _friendAppointments = {};
  Map<String, List<Map<String, dynamic>>> _friendInvitations = {};
  List<AppointmentModel> _allAppointments = [];

  @override
  void initState() {
    super.initState();
    _initializeDates();
    _loadFriends();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-initialize dates when returning from settings
    _initializeDates();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _regionController.dispose();
    _buildingController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Initialize dates with current user adjustment via DateConverter
  void _initializeDates() {
    final today = DateTime.now();
    _selectedGregorianDate = today;

    // Apply user's Hijri adjustment using centralized DateConverter
    final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
    _selectedHijriDate = DateConverter.toHijri(today, adjustment: userAdjustment);

    _selectedDay = today.day;
    _selectedMonth = _getMonthName(today.month);
    _selectedYear = today.year;
    _selectedWeekday = _getWeekdayName(today.weekday);

    _endDay = today.day;
    _endMonth = _selectedMonth;
    _endYear = today.year;

    // Initialize end Hijri date with user adjustment
    final hijriToday = DateConverter.toHijri(today, adjustment: userAdjustment);
    _endHijriDay = hijriToday.hDay;
    _endHijriMonth = _getHijriMonthName(hijriToday.hMonth);
    _endHijriYear = hijriToday.hYear;

    // تطبيق وقت الغروب كوقت افتراضي لليوم الحالي
    _applySunsetTime(today);
  }

  // Method to refresh dates when returning from settings
  void _refreshDatesFromSettings() {
    setState(() {
      _initializeDates();
    });
  }

  // تحميل الأصدقاء (المتابعات + المتبوعين) - Offline First
  Future<void> _loadFriends() async {
    if (!mounted) return;

    try {
      // 1. Load from Cache FIRST (instant) ⚡
      await _loadFriendsFromCache();

      // 2. Check internet connection
      final isOnline = await _connectivityService.hasConnection();

      // 3. If online, update from PocketHost in background
      if (isOnline && _authService.isAuthenticated) {
        try {
          final currentUserId = _authService.currentUser?.id;
          if (currentUserId == null) return;

          // جلب المتابعات (من أتابعهم)
          final followingRecords = await _authService.pb
              .collection(AppConstants.followsCollection)
              .getFullList(
                filter: 'follower = "$currentUserId"',
              );

          // جلب المتبوعين (من يتابعونني)
          final followersRecords = await _authService.pb
              .collection(AppConstants.followsCollection)
              .getFullList(
                filter: 'following = "$currentUserId"',
              );

          // جمع معرفات المستخدمين
          Set<String> friendIds = {};

          // إضافة المتابعات
          for (var record in followingRecords) {
            friendIds.add(record.data['following']);
          }

          // إضافة المتبوعين
          for (var record in followersRecords) {
            friendIds.add(record.data['follower']);
          }

          // جلب بيانات المستخدمين
          if (friendIds.isNotEmpty) {
            final friendsFilter = friendIds.map((id) => 'id = "$id"').join(' || ');
            final usersRecords = await _authService.pb
                .collection(AppConstants.usersCollection)
                .getFullList(
                  filter: '($friendsFilter) && isPublic = true',
                  sort: 'name',
                );

            final friends = usersRecords
                .map((record) => UserModel.fromJson(record.toJson()))
                .toList();

            // Save to Cache for next time ⚡
            await _saveFriendsToCache(friends);

            // Update UI with fresh data
            if (!mounted) return;
            setState(() {
              _availableFriends = friends;
              _filteredFriends = friends;
              _isLoadingFriends = false;
            });

            // جلب مواعيد الأصدقاء لفحص التعارض
            await _loadFriendsAppointments(friends);

            // جلب مواعيدي أيضاً لفحص التعارض مع نفسي
            await _loadMyAppointments();
          } else {
            // Save empty list to cache
            await _saveFriendsToCache([]);

            if (!mounted) return;
            setState(() {
              _availableFriends = [];
              _filteredFriends = [];
              _isLoadingFriends = false;
            });
          }
        } catch (e) {
          print('خطأ في تحميل الأصدقاء من الخادم: $e');
          // Keep showing cached data (already loaded)
          if (mounted) {
            setState(() => _isLoadingFriends = false);
          }
        }
      } else {
        // Offline - just show cached data (already loaded in step 1)
        if (mounted) {
          setState(() => _isLoadingFriends = false);
        }
      }
    } catch (e) {
      print('خطأ عام في تحميل الأصدقاء: $e');
      if (mounted) {
        setState(() {
          _availableFriends = [];
          _filteredFriends = [];
          _isLoadingFriends = false;
        });
      }
    }
  }

  // دوال Cache للأصدقاء
  Future<void> _loadFriendsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedData = prefs.getString('friends_$userId');
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final friends = jsonList.map((json) => UserModel.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            _availableFriends = friends;
            _filteredFriends = friends;
            _isLoadingFriends = false;
          });
        }
      }
    } catch (e) {
      // Ignore cache errors
      print('خطأ في تحميل الأصدقاء من الذاكرة: $e');
    }
  }

  Future<void> _saveFriendsToCache(List<UserModel> friends) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final jsonList = friends.map((friend) => friend.toJson()).toList();
      await prefs.setString('friends_$userId', jsonEncode(jsonList));
    } catch (e) {
      // Ignore cache errors
      print('خطأ في حفظ الأصدقاء في الذاكرة: $e');
    }
  }

  // فلترة الأصدقاء بناءً على البحث
  void _filterFriends(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredFriends = _availableFriends;
      } else {
        _filteredFriends = _availableFriends.where((friend) {
          return ArabicSearchUtils.searchInUserFields(
            friend.name,
            friend.username,
            friend.bio ?? '',
            query,
          );
        }).toList();
      }
    });
  }

  // الحصول على رابط الصورة الشخصية
  String _getUserAvatarUrl(UserModel user) {
    if (user.avatar == null || user.avatar!.isEmpty) {
      return '';
    }

    final cleanAvatar = user.avatar!.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // تحديد لون الطوق للأصدقاء في صندوق الإضافة
  Color _getFriendRingColor(UserModel friend) {
    // فحص تعارض المواعيد أولاً
    if (_hasAppointmentConflict(friend)) {
      return Colors.red; // أحمر للتعارض في المواعيد
    }

    // الافتراضي: رمادي
    return Colors.grey.shade400;
  }

  // فحص تعارض المواعيد مع الصديق
  bool _hasAppointmentConflict(UserModel friend) {
    try {
      // بناء تاريخ ووقت الموعد الحالي
      final currentAppointmentStart = _buildAppointmentDateTime();

      // حساب مدة الموعد بالدقائق
      int durationMinutes = 45; // افتراضي
      if (_selectedDuration.contains('30')) {
        durationMinutes = 30;
      } else if (_selectedDuration.contains('60')) {
        durationMinutes = 60;
      } else if (_selectedDuration.contains('90')) {
        durationMinutes = 90;
      } else if (_selectedDuration.contains('120')) {
        durationMinutes = 120;
      }

      final currentAppointmentEnd = currentAppointmentStart.add(
        Duration(minutes: durationMinutes),
      );

      // فحص التعارض مع مواعيد الصديق
      return _checkFriendAppointmentConflict(friend.id, currentAppointmentStart, currentAppointmentEnd);

    } catch (e) {
      // في حالة خطأ، لا نعتبر أن هناك تعارض
      return false;
    }
  }

  // فحص التعارض مع مواعيد صديق معين
  bool _checkFriendAppointmentConflict(String friendId, DateTime start, DateTime end) {
    // فحص مواعيد الصديق كمضيف
    for (final appointment in _friendAppointments[friendId] ?? []) {
      final appointmentStart = appointment.appointmentDate;
      // افتراض مدة 45 دقيقة للمواعيد الموجودة (يمكن تحسينها لاحقاً)
      final appointmentEnd = appointmentStart.add(const Duration(minutes: 45));

      // فحص التداخل الزمني
      if (start.isBefore(appointmentEnd) && end.isAfter(appointmentStart)) {
        return true; // يوجد تعارض
      }
    }

    // فحص دعوات الصديق للمواعيد الأخرى
    for (final invitation in _friendInvitations[friendId] ?? []) {
      // البحث عن الموعد المرتبط بالدعوة
      try {
        final appointment = _allAppointments.firstWhere(
          (apt) => apt.id == invitation['appointment'],
        );

        final appointmentStart = appointment.appointmentDate;
        final appointmentEnd = appointmentStart.add(const Duration(minutes: 45));

        if (start.isBefore(appointmentEnd) && end.isAfter(appointmentStart)) {
          return true; // يوجد تعارض
        }
      } catch (e) {
        // الموعد غير موجود، تجاهل
        continue;
      }
    }

    return false; // لا يوجد تعارض
  }

  // جلب مواعيد الأصدقاء لفحص التعارض
  Future<void> _loadFriendsAppointments(List<UserModel> friends) async {
    try {
      // مسح البيانات السابقة
      _friendAppointments.clear();
      _friendInvitations.clear();
      _allAppointments.clear();

      // جلب جميع المواعيد النشطة
      final appointmentRecords = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(
            filter: 'status = "active"',
            sort: 'appointment_date',
          );

      _allAppointments = appointmentRecords
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();

      // تصنيف المواعيد حسب المضيف
      for (final friend in friends) {
        final friendAppointments = _allAppointments
            .where((apt) => apt.hostId == friend.id)
            .toList();
        _friendAppointments[friend.id] = friendAppointments;
      }

      // جلب دعوات الأصدقاء
      for (final friend in friends) {
        try {
          final invitationRecords = await _authService.pb
              .collection(AppConstants.invitationsCollection)
              .getFullList(
                filter: 'guest = "${friend.id}" && status = "accepted"',
              );

          _friendInvitations[friend.id] = invitationRecords
              .map((record) => record.toJson())
              .toList();
        } catch (e) {
          // في حالة خطأ، استخدم قائمة فارغة
          _friendInvitations[friend.id] = [];
        }
      }

      // تحديث الواجهة لإعادة حساب الألوان
      if (mounted) {
        setState(() {});
      }

    } catch (e) {
      // في حالة خطأ، استخدم بيانات فارغة
      _friendAppointments.clear();
      _friendInvitations.clear();
      _allAppointments.clear();
    }
  }

  // فحص تعارض مواعيدي - دالة بسيطة
  bool _hasMyTimeConflict() {
    try {
      // إذا كان الموعد "عدة أيام" فلا يوجد وقت محدد للفحص
      if (_selectedDuration == 'عدة أيام') return false;

      final myId = _authService.currentUser?.id;
      if (myId == null) return false;

      final start = _buildAppointmentDateTime();
      final end = start.add(Duration(minutes: 45));

      return _checkFriendAppointmentConflict(myId, start, end);
    } catch (e) {
      return false;
    }
  }

  // جلب مواعيدي لفحص التعارض
  Future<void> _loadMyAppointments() async {
    try {
      final myId = _authService.currentUser?.id;
      if (myId == null) return;

      // جلب مواعيدي كمضيف
      final myAppointments = await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .getFullList(
            filter: 'host = "$myId" && status = "active"',
            sort: 'appointment_date',
          );

      // إضافة مواعيدي إلى قائمة مواعيد الأصدقاء
      _friendAppointments[myId] = myAppointments
          .map((record) => AppointmentModel.fromJson(record.toJson()))
          .toList();

      // جلب دعواتي المقبولة
      final myInvitations = await _authService.pb
          .collection(AppConstants.invitationsCollection)
          .getFullList(
            filter: 'guest = "$myId" && status = "accepted"',
          );

      _friendInvitations[myId] = myInvitations
          .map((record) => record.toJson())
          .toList();

      if (mounted) setState(() {});
    } catch (e) {
      // في حالة خطأ، تجاهل
    }
  }

  // Helper methods for date conversion and display
  String _getMonthName(int month) {
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[month - 1];
  }



  String _getHijriMonthName(int month) {
    const months = [
      'محرم',
      'صفر',
      'ربيع الأول',
      'ربيع الآخر',
      'جمادى الأولى',
      'جمادى الآخرة',
      'رجب',
      'شعبان',
      'رمضان',
      'شوال',
      'ذو القعدة',
      'ذو الحجة',
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return weekdays[weekday - 1];
  }

  int _getMonthNumber(String monthName) {
    final gregorianMonths = _gregorianMonths;
    final hijriMonths = _hijriMonths;

    if (gregorianMonths.contains(monthName)) {
      return gregorianMonths.indexOf(monthName) + 1;
    } else if (hijriMonths.contains(monthName)) {
      return hijriMonths.indexOf(monthName) + 1;
    }
    return 1;
  }

  // Precise date update methods using centralized DateConverter
  void _updateDateFromGregorian() {
    try {
      final monthNumber = _getMonthNumber(_selectedMonth);
      final gregorianDate = DateTime(_selectedYear, monthNumber, _selectedDay);
      // Apply user adjustment via DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final hijriDate = DateConverter.toHijri(gregorianDate, adjustment: userAdjustment);

      setState(() {
        _selectedGregorianDate = gregorianDate;
        _selectedHijriDate = hijriDate;
        _selectedWeekday = _getWeekdayName(gregorianDate.weekday);

        // تطبيق وقت الغروب كوقت افتراضي
        _applySunsetTime(gregorianDate);
      });
    } catch (e) {
      // Handle invalid date
    }
  }

  void _updateDateFromHijri() {
    try {
      final monthNumber = _getMonthNumber(_selectedMonth);
      final hijriDate = HijriCalendar()
        ..hYear = _selectedYear
        ..hMonth = monthNumber
        ..hDay = _selectedDay;

      // Convert Hijri to Gregorian with reverse adjustment via DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final gregorianDate = DateConverter.toGregorian(hijriDate, adjustment: userAdjustment);

      setState(() {
        _selectedHijriDate = hijriDate;
        _selectedGregorianDate = gregorianDate;
        _selectedWeekday = _getWeekdayName(gregorianDate.weekday);

        // تطبيق وقت الغروب كوقت افتراضي
        _applySunsetTime(gregorianDate);
      });
    } catch (e) {
      // Handle invalid date
    }
  }

  // Helper method to update date to match selected weekday
  void _updateDateToMatchWeekday(String weekdayName) {
    final targetWeekday = _getWeekdayNumber(weekdayName);
    final currentWeekday = _selectedGregorianDate.weekday;
    final daysDifference = targetWeekday - currentWeekday;

    final newDate = _selectedGregorianDate.add(Duration(days: daysDifference));

    setState(() {
      _selectedGregorianDate = newDate;
      // Apply user adjustment via DateConverter
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      _selectedHijriDate = DateConverter.toHijri(newDate, adjustment: userAdjustment);

      _selectedDay = newDate.day;
      _selectedMonth = _getMonthName(newDate.month);
      _selectedYear = newDate.year;
    });
  }

  // Helper method to get weekday number from Arabic name
  int _getWeekdayNumber(String weekdayName) {
    const weekdays = {
      'الإثنين': 1,
      'الثلاثاء': 2,
      'الأربعاء': 3,
      'الخميس': 4,
      'الجمعة': 5,
      'السبت': 6,
      'الأحد': 7,
    };
    return weekdays[weekdayName] ?? 1;
  }

  // قوائم البيانات
  final List<String> _gregorianMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  final List<String> _hijriMonths = [
    'محرم',
    'صفر',
    'ربيع الأول',
    'ربيع الآخر',
    'جمادى الأولى',
    'جمادى الآخرة',
    'رجب',
    'شعبان',
    'رمضان',
    'شوال',
    'ذو القعدة',
    'ذو الحجة',
  ];

  final List<String> _weekdays = [
    'السبت',
    'الأحد',
    'الإثنين',
    'الثلاثاء',
    'الأربعاء',
    'الخميس',
    'الجمعة',
  ];

  final List<String> _durations = [
    '15 دقيقة',
    '30 دقيقة',
    '45 دقيقة',
    '60 دقيقة',
    '90 دقيقة',
    '120 دقيقة',
    'عدة أيام',
  ];

  // دالة حفظ الموعد
  Future<void> _saveAppointment() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_authService.isAuthenticated) {
      _showErrorMessage('يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // تحويل التاريخ والوقت إلى DateTime المحلي
      final localAppointmentDateTime = _buildAppointmentDateTime();

      // تحويل الوقت المحلي إلى UTC للحفظ في قاعدة البيانات
      final utcAppointmentDateTime = TimezoneService.toUtc(localAppointmentDateTime);

      // إنشاء بيانات الموعد
      final appointmentData = {
        'title': _titleController.text.trim(),
        'region': _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
        'building': _buildingController.text.trim().isEmpty ? null : _buildingController.text.trim(),
        'privacy': _isPrivate ? 'private' : 'public',
        'status': 'active',
        'appointment_date': utcAppointmentDateTime.toIso8601String(), // حفظ بتوقيت UTC
        'host': _authService.currentUser!.id,
        'stream_link': null,
        'note_shared': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      // فحص الاتصال بالإنترنت
      final isOnline = await _connectivityService.hasConnection();

      if (isOnline) {
        // حفظ الموعد في PocketBase (أونلاين)
        final record = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .create(body: appointmentData);

        // إضافة الضيوف إذا كانوا موجودين
        if (_selectedGuests.isNotEmpty) {
          await _saveGuestInvitations(record.id);
        }

        // إظهار رسالة نجاح
        _showSuccessMessage('تم حفظ الموعد بنجاح');
      } else {
        // حفظ الموعد محلياً (أوفلاين)
        await _saveAppointmentOffline(appointmentData);

        // إظهار رسالة نجاح مع تنبيه الأوفلاين
        _showSuccessMessage('تم حفظ الموعد محلياً - سيتم رفعه عند الاتصال بالإنترنت');
      }

      // إعادة تعيين النموذج
      _resetForm();

      // الانتقال للصفحة الرئيسية
      _navigateToHome();

    } catch (e) {
      _showErrorMessage('حدث خطأ أثناء حفظ الموعد: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // حفظ الموعد محلياً عند عدم وجود اتصال
  Future<void> _saveAppointmentOffline(Map<String, dynamic> appointmentData) async {
    try {
      // إضافة معرف مؤقت للموعد
      final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      appointmentData['id'] = tempId;
      appointmentData['temp_id'] = tempId;
      appointmentData['sync_status'] = 'pending'; // في انتظار المزامنة
      appointmentData['created_offline'] = true;

      // حفظ في SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final offlineAppointments = prefs.getStringList('offline_appointments') ?? [];
      offlineAppointments.add(jsonEncode(appointmentData));
      await prefs.setStringList('offline_appointments', offlineAppointments);

      // حفظ الضيوف المحددين أيضاً
      if (_selectedGuests.isNotEmpty) {
        final guestData = {
          'appointment_temp_id': tempId,
          'guests': _selectedGuests,
          'sync_status': 'pending',
        };

        final offlineInvitations = prefs.getStringList('offline_invitations') ?? [];
        offlineInvitations.add(jsonEncode(guestData));
        await prefs.setStringList('offline_invitations', offlineInvitations);
      }

    } catch (e) {
      print('خطأ في حفظ الموعد محلياً: $e');
      rethrow;
    }
  }

  // دالة حفظ الموعد مع البقاء في الصفحة (للضغط المطول)
  Future<void> _saveAppointmentAndStay() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_authService.isAuthenticated) {
      _showErrorMessage('يجب تسجيل الدخول أولاً');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // تحويل التاريخ والوقت إلى DateTime المحلي
      final localAppointmentDateTime = _buildAppointmentDateTime();

      // تحويل الوقت المحلي إلى UTC للحفظ في قاعدة البيانات
      final utcAppointmentDateTime = TimezoneService.toUtc(localAppointmentDateTime);

      // إنشاء بيانات الموعد
      final appointmentData = {
        'title': _titleController.text.trim(),
        'region': _regionController.text.trim().isEmpty ? null : _regionController.text.trim(),
        'building': _buildingController.text.trim().isEmpty ? null : _buildingController.text.trim(),
        'privacy': _isPrivate ? 'private' : 'public',
        'status': 'active',
        'appointment_date': utcAppointmentDateTime.toIso8601String(), // حفظ بتوقيت UTC
        'host': _authService.currentUser!.id,
        'stream_link': null,
        'note_shared': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      };

      // فحص الاتصال بالإنترنت
      final isOnline = await _connectivityService.hasConnection();

      if (isOnline) {
        // حفظ الموعد في PocketBase (أونلاين)
        final record = await _authService.pb
            .collection(AppConstants.appointmentsCollection)
            .create(body: appointmentData);

        // إضافة الضيوف إذا كانوا موجودين
        if (_selectedGuests.isNotEmpty) {
          await _saveGuestInvitations(record.id);
        }

        // إظهار رسالة نجاح
        _showSuccessMessage('تم حفظ الموعد بنجاح - يمكنك إضافة موعد آخر');
      } else {
        // حفظ الموعد محلياً (أوفلاين)
        await _saveAppointmentOffline(appointmentData);

        // إظهار رسالة نجاح مع تنبيه الأوفلاين
        _showSuccessMessage('تم حفظ الموعد محلياً - سيتم رفعه عند الاتصال بالإنترنت');
      }

      // إعادة تعيين النموذج فقط (البقاء في الصفحة)
      _resetForm();

    } catch (e) {
      _showErrorMessage('حدث خطأ أثناء حفظ الموعد: ${e.toString()}');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  // الانتقال للصفحة الرئيسية
  void _navigateToHome() {
    // العثور على MainScreen والانتقال للصفحة الرئيسية
    final mainScreenState = context.findAncestorStateOfType<_MainScreenState>();
    if (mainScreenState != null) {
      mainScreenState.setState(() {
        mainScreenState._currentIndex = 0; // الصفحة الرئيسية
      });
    }
  }

  // تطبيق وقت الغروب كوقت افتراضي
  void _applySunsetTime(DateTime date) {
    final sunsetData = SunsetService.getParsedSunsetTime(date);
    if (sunsetData != null) {
      _selectedHour = sunsetData['hour'];
      _selectedMinute = sunsetData['minute'];
      _selectedPeriod = sunsetData['period'];
    }
  }

  // بناء تاريخ ووقت الموعد
  DateTime _buildAppointmentDateTime() {
    int hour = _selectedHour;
    if (_selectedPeriod == 'مساءً' && hour != 12) {
      hour += 12;
    } else if (_selectedPeriod == 'صباحاً' && hour == 12) {
      hour = 0;
    }

    if (_dateType == 'ميلادي') {
      return DateTime(
        _selectedYear,
        _getMonthNumber(_selectedMonth),
        _selectedDay,
        hour,
        _selectedMinute,
      );
    } else {
      // تحويل التاريخ الهجري إلى ميلادي
      final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
      final gregorianDate = DateConverter.toGregorian(_selectedHijriDate, adjustment: userAdjustment);
      return DateTime(
        gregorianDate.year,
        gregorianDate.month,
        gregorianDate.day,
        hour,
        _selectedMinute,
      );
    }
  }

  // حفظ دعوات الضيوف
  Future<void> _saveGuestInvitations(String appointmentId) async {
    try {
      for (String guestId in _selectedGuests) {
        await _authService.pb
            .collection(AppConstants.invitationsCollection)
            .create(body: {
          'appointment': appointmentId,
          'guest': guestId,
          'status': 'pending',
          'invited_by': _authService.currentUser!.id,
        });
      }
    } catch (e) {
      print('خطأ في حفظ دعوات الضيوف: $e');
    }
  }

  // إعادة تعيين النموذج
  void _resetForm() {
    _titleController.clear();
    _regionController.clear();
    _buildingController.clear();
    _searchController.clear();
    _notesController.clear();

    setState(() {
      _isPrivate = false;
      _selectedGuests.clear();
      _dateType = 'ميلادي';
      _selectedMonth = 'يناير';
      _selectedDay = DateTime.now().day;
      _selectedYear = DateTime.now().year;
      _selectedWeekday = 'السبت';
      _selectedHour = 9;
      _selectedMinute = 0;
      _selectedPeriod = 'مساءً';
      _selectedDuration = '45 دقيقة';
      _initializeDates();
    });
  }

  // إظهار رسالة نجاح
  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // إظهار رسالة خطأ
  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.grey.shade50,
        body: SafeArea(
          child: Column(
            children: [
              // AppBar with Save Button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Text(
                            'إضافة موعد جديد',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                            ),
                          ),
                          if ((_authService.currentUser?.hijriAdjustment ?? 0) != 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                ),
                              ),
                              child: Text(
                                'تصحيح هجري: ${(_authService.currentUser?.hijriAdjustment ?? 0) >= 0 ? '+' : ''}${_authService.currentUser?.hijriAdjustment ?? 0}',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // زر الخصوصية
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isPrivate ? Icons.lock : Icons.public,
                          color: _isPrivate ? const Color(0xFF2196F3) : Colors.grey.shade600,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isPrivate ? 'خاص' : 'عام',
                          style: TextStyle(
                            color: _isPrivate ? const Color(0xFF2196F3) : Colors.grey.shade600,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Switch(
                          value: _isPrivate,
                          onChanged: (value) {
                            setState(() {
                              _isPrivate = value;
                            });
                          },
                          activeThumbColor: const Color(0xFF2196F3),
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Form Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // حقل العنوان
                        TextFormField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'موضوع الموعد',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                            prefixIcon: const Icon(Icons.title),
                          ),
                          validator: (value) {
                            if (value?.isEmpty ?? true) {
                              return 'الرجاء إدخال موضوع الموعد';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // المنطقة والمبنى
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _regionController,
                                decoration: InputDecoration(
                                  labelText: 'المنطقة',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  prefixIcon: const Icon(Icons.location_on),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _buildingController,
                                decoration: InputDecoration(
                                  labelText: 'المبنى',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  prefixIcon: const Icon(Icons.business),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // السطر الثالث: اختيار نوع التاريخ
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // اختيار نوع التاريخ
                            Row(
                              children: [
                                Radio<String>(
                                  value: 'ميلادي',
                                  groupValue: _dateType,
                                  onChanged: (value) {
                                    setState(() {
                                      _dateType = value!;
                                      if (value == 'ميلادي') {
                                        // Switch to Gregorian - use current gregorian date
                                        _selectedYear = _selectedGregorianDate.year;
                                        _selectedMonth = _getMonthName(
                                          _selectedGregorianDate.month,
                                        );
                                        _selectedDay = _selectedGregorianDate.day;

                                        // Update end date to Gregorian
                                        _endYear = _selectedGregorianDate.year;
                                        _endMonth = _getMonthName(_selectedGregorianDate.month);
                                        _endDay = _selectedGregorianDate.day;
                                      } else {
                                        // Switch to Hijri - use current hijri date
                                        _selectedYear = _selectedHijriDate.hYear;
                                        _selectedMonth = _getHijriMonthName(
                                          _selectedHijriDate.hMonth,
                                        );
                                        _selectedDay = _selectedHijriDate.hDay;

                                        // Update end date to Hijri
                                        _endHijriYear = _selectedHijriDate.hYear;
                                        _endHijriMonth = _getHijriMonthName(_selectedHijriDate.hMonth);
                                        _endHijriDay = _selectedHijriDate.hDay;
                                      }
                                    });
                                  },
                                ),
                                const Text('ميلادي'),
                                const SizedBox(width: 20),
                                Radio<String>(
                                  value: 'هجري',
                                  groupValue: _dateType,
                                  onChanged: (value) {
                                    setState(() {
                                      _dateType = value!;
                                      if (value == 'هجري') {
                                        // Switch to Hijri - use current hijri date with user adjustment
                                        final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
                                        final adjustedHijriDate = DateConverter.toHijri(_selectedGregorianDate, adjustment: userAdjustment);

                                        _selectedYear = adjustedHijriDate.hYear;
                                        _selectedMonth = _getHijriMonthName(
                                          adjustedHijriDate.hMonth,
                                        );
                                        _selectedDay = adjustedHijriDate.hDay;
                                        _selectedHijriDate = adjustedHijriDate;

                                        // Update end date to Hijri
                                        _endHijriYear = adjustedHijriDate.hYear;
                                        _endHijriMonth = _getHijriMonthName(adjustedHijriDate.hMonth);
                                        _endHijriDay = adjustedHijriDate.hDay;
                                      } else {
                                        // Switch to Gregorian - use current gregorian date
                                        _selectedYear = _selectedGregorianDate.year;
                                        _selectedMonth = _getMonthName(
                                          _selectedGregorianDate.month,
                                        );
                                        _selectedDay = _selectedGregorianDate.day;

                                        // Update end date to Gregorian
                                        _endYear = _selectedGregorianDate.year;
                                        _endMonth = _getMonthName(_selectedGregorianDate.month);
                                        _endDay = _selectedGregorianDate.day;
                                      }
                                    });
                                  },
                                ),
                                const Text('هجري'),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // التاريخ الميلادي (نشط عند اختيار ميلادي)
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month,
                                  color: _dateType == 'ميلادي' ? Colors.blue.shade700 : Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'التاريخ الميلادي',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _dateType == 'ميلادي' ? Colors.blue.shade700 : Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // يوم ميلادي
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _selectedGregorianDate.day,
                                    decoration: InputDecoration(
                                      labelText: 'اليوم',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      enabled: _dateType == 'ميلادي',
                                    ),
                                    items: List.generate(31, (index) => index + 1)
                                        .map(
                                          (day) => DropdownMenuItem(
                                            value: day,
                                            child: Text(
                                              day.toString(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _dateType == 'ميلادي' ? Colors.black : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _dateType == 'ميلادي' ? (value) {
                                      setState(() {
                                        _selectedGregorianDate = DateTime(
                                          _selectedGregorianDate.year,
                                          _selectedGregorianDate.month,
                                          value!,
                                        );
                                        final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
                                        _selectedDay = value;
                                        _updateDateFromGregorian();
                                      });
                                    } : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // شهر ميلادي
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _getMonthName(_selectedGregorianDate.month),
                                    decoration: InputDecoration(
                                      labelText: 'الشهر',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      enabled: _dateType == 'ميلادي',
                                    ),
                                    items: _gregorianMonths
                                        .map(
                                          (month) => DropdownMenuItem(
                                            value: month,
                                            child: Text(
                                              month,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _dateType == 'ميلادي' ? Colors.black : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _dateType == 'ميلادي' ? (value) {
                                      setState(() {
                                        final monthIndex = _gregorianMonths.indexOf(value!) + 1;
                                        _selectedGregorianDate = DateTime(
                                          _selectedGregorianDate.year,
                                          monthIndex,
                                          _selectedGregorianDate.day,
                                        );
                                        final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
                                        _selectedMonth = value;
                                        _updateDateFromGregorian();
                                      });
                                    } : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // سنة ميلادي
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _selectedGregorianDate.year,
                                    decoration: InputDecoration(
                                      labelText: 'السنة',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      enabled: _dateType == 'ميلادي',
                                    ),
                                    items: List.generate(10, (index) => DateTime.now().year + index)
                                        .map(
                                          (year) => DropdownMenuItem(
                                            value: year,
                                            child: Text(
                                              year.toString(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _dateType == 'ميلادي' ? Colors.black : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _dateType == 'ميلادي' ? (value) {
                                      setState(() {
                                        _selectedGregorianDate = DateTime(
                                          value!,
                                          _selectedGregorianDate.month,
                                          _selectedGregorianDate.day,
                                        );
                                        final userAdjustment = _authService.currentUser?.hijriAdjustment ?? 0;
                                        _selectedYear = value;
                                        _updateDateFromGregorian();
                                      });
                                    } : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // التاريخ الهجري (نشط عند اختيار هجري)
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_month_outlined,
                                  color: _dateType == 'هجري' ? Colors.orange.shade700 : Colors.grey.shade400,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'التاريخ الهجري',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: _dateType == 'هجري' ? Colors.orange.shade700 : Colors.grey.shade400,
                                  ),
                                ),
                                // Hijri adjustment badge
                                if ((_authService.currentUser?.hijriAdjustment ?? 0) != 0) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.orange.shade300, width: 0.5),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.tune, size: 10, color: Colors.orange.shade700),
                                        const SizedBox(width: 3),
                                        Text(
                                          '${(_authService.currentUser?.hijriAdjustment ?? 0) > 0 ? '+' : ''}${_authService.currentUser?.hijriAdjustment ?? 0}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                // يوم هجري
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _selectedHijriDate.hDay,
                                    decoration: InputDecoration(
                                      labelText: 'اليوم',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      enabled: _dateType == 'هجري',
                                    ),
                                    items: List.generate(30, (index) => index + 1)
                                        .map(
                                          (day) => DropdownMenuItem(
                                            value: day,
                                            child: Text(
                                              day.toString(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _dateType == 'هجري' ? Colors.black : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _dateType == 'هجري' ? (value) {
                                      setState(() {
                                        _selectedDay = value!;
                                        _selectedYear = _selectedHijriDate.hYear;
                                        _selectedMonth = _getHijriMonthName(_selectedHijriDate.hMonth);
                                        _updateDateFromHijri();
                                      });
                                    } : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // شهر هجري
                                Expanded(
                                  flex: 3,
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _getHijriMonthName(_selectedHijriDate.hMonth),
                                    decoration: InputDecoration(
                                      labelText: 'الشهر',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      enabled: _dateType == 'هجري',
                                    ),
                                    items: _hijriMonths
                                        .map(
                                          (month) => DropdownMenuItem(
                                            value: month,
                                            child: Text(
                                              month,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _dateType == 'هجري' ? Colors.black : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _dateType == 'هجري' ? (value) {
                                      setState(() {
                                        _selectedMonth = value!;
                                        _selectedYear = _selectedHijriDate.hYear;
                                        _selectedDay = _selectedHijriDate.hDay;
                                        _updateDateFromHijri();
                                      });
                                    } : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // سنة هجري
                                Expanded(
                                  flex: 2,
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _selectedHijriDate.hYear,
                                    decoration: InputDecoration(
                                      labelText: 'السنة',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(18),
                                      ),
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      enabled: _dateType == 'هجري',
                                    ),
                                    items: List.generate(10, (index) => 1446 + index)
                                        .map(
                                          (year) => DropdownMenuItem(
                                            value: year,
                                            child: Text(
                                              year.toString(),
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: _dateType == 'هجري' ? Colors.black : Colors.grey.shade400,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: _dateType == 'هجري' ? (value) {
                                      setState(() {
                                        _selectedYear = value!;
                                        _selectedMonth = _getHijriMonthName(_selectedHijriDate.hMonth);
                                        _selectedDay = _selectedHijriDate.hDay;
                                        _updateDateFromHijri();
                                      });
                                    } : null,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // السطر الرابع: يوم الأسبوع ومدة الموعد
                        Row(
                          children: [
                            // اختيار يوم الأسبوع
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedWeekday,
                                decoration: InputDecoration(
                                  labelText: 'يوم الأسبوع',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.calendar_today,
                                    color: _dateType == 'ميلادي' ? null : Colors.grey.shade400,
                                  ),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  enabled: _dateType == 'ميلادي',
                                ),
                                items: _weekdays
                                    .map(
                                      (day) => DropdownMenuItem(
                                        value: day,
                                        child: Text(
                                          day,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: _dateType == 'ميلادي' ? Colors.black : Colors.grey.shade400,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _dateType == 'ميلادي' ? (value) {
                                  setState(() {
                                    _selectedWeekday = value!;
                                    // Update date to match the selected weekday
                                    _updateDateToMatchWeekday(value);
                                  });
                                } : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            // اختيار مدة الموعد
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _selectedDuration,
                                decoration: InputDecoration(
                                  labelText: 'مدة الموعد',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  prefixIcon: const Icon(Icons.timer),
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: _durations
                                    .map(
                                      (duration) => DropdownMenuItem(
                                        value: duration,
                                        child: Text(
                                          duration,
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedDuration = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // اختيار الوقت (لا يظهر عند اختيار "عدة أيام")
                        if (_selectedDuration != 'عدة أيام')
                          Column(
                            children: [
                              // الساعة والدقيقة في صف واحد
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _selectedHour,
                                      decoration: InputDecoration(
                                        labelText: 'الساعة',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict() ? Colors.red : Colors.grey,
                                            width: _hasMyTimeConflict() ? 2 : 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict() ? Colors.red : Colors.grey,
                                            width: _hasMyTimeConflict() ? 2 : 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict() ? Colors.red : Colors.blue,
                                            width: 2,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: List.generate(12, (index) => index + 1)
                                          .map(
                                            (hour) => DropdownMenuItem(
                                              value: hour,
                                              child: Text(
                                                hour.toString(),
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedHour = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _selectedMinute,
                                      decoration: InputDecoration(
                                        labelText: 'الدقيقة',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict() ? Colors.red : Colors.grey,
                                            width: _hasMyTimeConflict() ? 2 : 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict() ? Colors.red : Colors.grey,
                                            width: _hasMyTimeConflict() ? 2 : 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                          borderSide: BorderSide(
                                            color: _hasMyTimeConflict() ? Colors.red : Colors.blue,
                                            width: 2,
                                          ),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: List.generate(60, (index) => index)
                                          .map(
                                            (minute) => DropdownMenuItem(
                                              value: minute,
                                              child: Text(
                                                minute.toString().padLeft(2, '0'),
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedMinute = value!;
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _selectedPeriod,
                                      decoration: InputDecoration(
                                        labelText: 'فترة',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: ['صباحاً', 'مساءً']
                                          .map(
                                            (period) => DropdownMenuItem(
                                              value: period,
                                              child: Text(
                                                period,
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedPeriod = value!;
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        if (_selectedDuration != 'عدة أيام') const SizedBox(height: 16),

                        // تاريخ انتهاء الموعد (يظهر فقط عند اختيار "عدة أيام")
                        if (_selectedDuration == 'عدة أيام')
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'تاريخ انتهاء الموعد',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  // يوم الانتهاء
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _dateType == 'ميلادي' ? _endDay : _endHijriDay,
                                      decoration: InputDecoration(
                                        labelText: 'اليوم',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: List.generate(_dateType == 'ميلادي' ? 31 : 30, (index) => index + 1)
                                          .map(
                                            (day) => DropdownMenuItem(
                                              value: day,
                                              child: Text(
                                                day.toString(),
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          if (_dateType == 'ميلادي') {
                                            _endDay = value!;
                                          } else {
                                            _endHijriDay = value!;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // شهر الانتهاء
                                  Expanded(
                                    flex: 3,
                                    child: DropdownButtonFormField<String>(
                                      initialValue: _dateType == 'ميلادي' ? _endMonth : _endHijriMonth,
                                      decoration: InputDecoration(
                                        labelText: 'الشهر',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items:
                                          (_dateType == 'ميلادي'
                                                  ? _gregorianMonths
                                                  : _hijriMonths)
                                              .map(
                                                (month) => DropdownMenuItem(
                                                  value: month,
                                                  child: Text(
                                                    month,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                              )
                                              .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          if (_dateType == 'ميلادي') {
                                            _endMonth = value!;
                                          } else {
                                            _endHijriMonth = value!;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // سنة الانتهاء
                                  Expanded(
                                    flex: 2,
                                    child: DropdownButtonFormField<int>(
                                      initialValue: _dateType == 'ميلادي' ? _endYear : _endHijriYear,
                                      decoration: InputDecoration(
                                        labelText: 'السنة',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(18),
                                        ),
                                        isDense: true,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                      items: _dateType == 'ميلادي'
                                          ? List.generate(
                                                  10,
                                                  (index) =>
                                                      DateTime.now().year + index,
                                                )
                                                .map(
                                                  (year) => DropdownMenuItem(
                                                    value: year,
                                                    child: Text(
                                                      year.toString(),
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList()
                                          : List.generate(
                                                  10,
                                                  (index) => 1446 + index,
                                                )
                                                .map(
                                                  (year) => DropdownMenuItem(
                                                    value: year,
                                                    child: Text(
                                                      year.toString(),
                                                      style: const TextStyle(
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          if (_dateType == 'ميلادي') {
                                            _endYear = value!;
                                          } else {
                                            _endHijriYear = value!;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        if (_selectedDuration == 'عدة أيام') const SizedBox(height: 16),

                        _buildGuestSection(),
                        const SizedBox(height: 16),

                        // حقل الملاحظات
                        _buildNotesSection(),
                        const SizedBox(height: 24),

                        // أزرار الإجراءات النهائية
                        Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _isSaving ? null : _saveAppointment,
                                onLongPress: _isSaving ? null : _saveAppointmentAndStay,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  decoration: BoxDecoration(
                                    color: _isSaving ? Colors.grey : const Color(0xFF2196F3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _isSaving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            )
                                          : const Icon(Icons.save, color: Colors.white),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isSaving ? 'جاري الحفظ...' : 'حفظ الموعد',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _isSaving ? null : _resetForm,
                                icon: const Icon(Icons.refresh),
                                label: const Text('إعادة تعيين'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.grey.shade700,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // تلميح للمستخدم
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.blue.shade600, size: 16),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'اضغط للحفظ والانتقال للرئيسية • اضغط مطولاً للحفظ وإضافة موعد آخر',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
                      ],
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

  // Helper methods and sections will be added in the next file









  Widget _buildGuestSection() {

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              Text(
                'دعوة الضيوف',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _searchController,
            textAlign: TextAlign.right,
            decoration: InputDecoration(
              hintText: 'ابحث بالاسم أو اسم المستخدم...',
              hintStyle: TextStyle(color: Colors.grey[600]),
              prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade600),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: _filterFriends,
          ),
          const SizedBox(height: 12),
          if (_selectedGuests.isNotEmpty) ...[
            Text(
              'الضيوف المدعوون (${_selectedGuests.length}):',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _selectedGuests.map((guestId) {
                final guest = _availableFriends.firstWhere(
                  (f) => f.id == guestId,
                  orElse: () => UserModel(
                    id: guestId,
                    email: '',
                    username: 'غير معروف',
                    name: 'غير معروف',
                    verified: false,
                    avatar: '',
                    bio: '',
                    socialLink: '',
                    phone: '',
                    role: 'user',
                    joiningDate: DateTime.now().toIso8601String(),
                    hijriAdjustment: 0,
                    createdDate: DateTime.now(),
                  ),
                );
                return Chip(
                  avatar: CircleAvatar(
                    radius: 12,
                    backgroundImage: (guest.avatar?.isNotEmpty ?? false)
                        ? NetworkImage(_getUserAvatarUrl(guest))
                        : null,
                    child: (guest.avatar?.isEmpty ?? true)
                        ? const Icon(Icons.person, size: 16)
                        : null,
                  ),
                  label: Text(
                    guest.name,
                    style: const TextStyle(fontSize: 12),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () =>
                      setState(() => _selectedGuests.remove(guestId)),
                  backgroundColor: Colors.orange.shade100,
                );
              }).toList(),
            ),
            const Divider(height: 24),
          ],
          SizedBox(
            height: 150,
            child: _isLoadingFriends
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                    ? Center(
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'لا توجد متابعات'
                              : 'لا توجد نتائج',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _filteredFriends[index];
                          final isSelected = _selectedGuests.contains(friend.id);
                          return ListTile(
                            dense: true,
                            leading: Container(
                              width: 36, // 32 + (2 * 2) للطوق
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _getFriendRingColor(friend), // لون ديناميكي
                                  width: 2,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(2), // الفجوة بين الصورة والطوق
                                child: CircleAvatar(
                                  radius: 14,
                                  backgroundImage: _getUserAvatarUrl(friend).isNotEmpty
                                      ? NetworkImage(_getUserAvatarUrl(friend))
                                      : null,
                                  backgroundColor: Colors.grey.shade200,
                                  child: _getUserAvatarUrl(friend).isEmpty
                                      ? const Icon(Icons.person, size: 14)
                                      : null,
                                ),
                              ),
                            ),
                            title: Text(
                              friend.name,
                              style: const TextStyle(fontSize: 14),
                            ),
                            subtitle: Text(
                              '@${friend.username}',
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedGuests.add(friend.id);
                                  } else {
                                    _selectedGuests.remove(friend.id);
                                  }
                                });
                              },
                              activeColor: Colors.orange,
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // حقل الملاحظات
  Widget _buildNotesSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.note_alt, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: TextFormField(
              controller: _notesController,
              textAlign: TextAlign.right,
              minLines: 1,
              maxLines: null, // يتوسع حسب المحتوى
              decoration: InputDecoration(
                hintText: 'أضف ملاحظات أو روابط مفيدة للموعد...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }


}

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();

  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _searchQuery = '';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _searchQuery = query;
    });

    try {
      // البحث في قاعدة البيانات مع تضمين المستخدمين العامين
      final records = await _authService.pb
          .collection(AppConstants.usersCollection)
          .getFullList(
            // البحث في الاسم واسم المستخدم للمستخدمين العامين أو المستخدم الحالي
            filter: '(isPublic = true || id = "${_authService.currentUser?.id}") && (name ~ "$query" || username ~ "$query")',
            sort: 'name',
          );

      List<UserModel> users = records.map((record) {
        return UserModel.fromJson(record.toJson());
      }).toList();

      // تطبيق البحث المحلي مع التطبيع العربي
      users = users.where((user) {
        return ArabicSearchUtils.searchInUserFields(
          user.name,
          user.username,
          user.bio,
          query
        );
      }).toList();

      setState(() {
        _searchResults = users;
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
        _hasSearched = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar with Search
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'البحث عن المستخدمين',
                    style: TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    textAlign: TextAlign.right,
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو اسم المستخدم...',
                      hintStyle: TextStyle(color: Colors.grey[600]),
                      prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey[600]),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade600),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF2196F3)),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    onChanged: (value) {
                      setState(() {});
                      // تأخير البحث لتجنب الكثير من الطلبات
                      Future.delayed(const Duration(milliseconds: 500), () {
                        if (_searchController.text == value) {
                          _performSearch(value);
                        }
                      });
                    },
                    onSubmitted: _performSearch,
                  ),
                ],
              ),
            ),

            // Search Results
            Expanded(
              child: _buildSearchContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF2196F3),
        ),
      );
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              'ابحث عن المستخدمين',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'اكتب اسم المستخدم أو الاسم الظاهر للبحث',
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

    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              'لا توجد نتائج',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم العثور على مستخدمين بهذا الاسم',
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
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final user = _searchResults[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(UserModel user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 64, // 60 + (2 * 2) للطوق
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getSearchUserRingColor(user), // لون ديناميكي
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2), // الفجوة بين الصورة والطوق
            child: CircleAvatar(
              radius: 28,
              backgroundImage: _getUserAvatarUrl(user).isNotEmpty
                  ? NetworkImage(_getUserAvatarUrl(user))
                  : null,
              backgroundColor: Colors.grey.shade200,
              child: _getUserAvatarUrl(user).isEmpty
                  ? Icon(
                      Icons.person,
                      color: Colors.grey.shade600,
                      size: 28,
                    )
                  : null,
            ),
          ),
        ),
        title: Text(
          user.name.isNotEmpty ? user.name : user.username,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.username}',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
            if (user.bio != null && user.bio!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                user.bio!,
                style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: 16,
          color: Colors.grey.shade400,
        ),
        onTap: () => _openUserProfile(user),
      ),
    );
  }

  // الحصول على رابط الصورة الشخصية
  String _getUserAvatarUrl(UserModel user) {
    if (user.avatar == null || user.avatar!.isEmpty) {
      return '';
    }

    final cleanAvatar = user.avatar!.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // تحديد لون الطوق للمستخدمين في نتائج البحث
  Color _getSearchUserRingColor(UserModel user) {
    // حالياً: رمادي دائماً في نتائج البحث
    Color ringColor = Colors.grey.shade400;

    // متاح للتطوير المستقبلي:
    // if (user.verified) ringColor = const Color(0xFF2196F3); // أزرق للمتحققين
    // if (user.isOnline) ringColor = Colors.green; // أخضر للمتصلين
    // if (user.isFriend) ringColor = Colors.purple; // بنفسجي للأصدقاء
    // if (user.isPremium) ringColor = Colors.amber; // أصفر للمميزين

    return ringColor;
  }

  void _openUserProfile(UserModel user) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: user.id,
          username: user.username,
        ),
      ),
    );
  }
}
