import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../config/constants.dart';
import '../utils/arabic_search_utils.dart';
import 'user_profile_screen.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // قوائم البيانات
  List<UserModel> _followers = [];
  List<UserModel> _following = [];
  List<UserModel> _filteredFollowers = [];
  List<UserModel> _filteredFollowing = [];

  // حالات التحميل
  bool _isLoadingFollowers = false;
  bool _isLoadingFollowing = false;
  bool _isOnline = true;

  // البحث
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadFollowers();
    _loadFollowing();
    _listenToConnectivity();
  }

  void _listenToConnectivity() {
    _connectivityService.onConnectivityChanged.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);
        if (isConnected) {
          // Refresh data when coming back online
          _loadFollowers();
          _loadFollowing();
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // تحميل المتابعين (من يتابعونني) - Offline First
  Future<void> _loadFollowers() async {
    if (!mounted) return;

    try {
      // 1. Load from Cache FIRST (instant) ⚡
      await _loadFollowersFromCache();

      // 2. Check internet connection
      final isOnline = await _connectivityService.hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);

      // 3. If online, update from PocketHost in background
      if (isOnline && _authService.isAuthenticated) {
        try {
          final currentUserId = _authService.currentUser?.id;
          if (currentUserId == null) return;

          // جلب المتابعين
          final followRecords = await _authService.pb
              .collection(AppConstants.followsCollection)
              .getFullList(
                filter: 'following = "$currentUserId"',
              );

          // جلب بيانات المستخدمين
          if (followRecords.isNotEmpty) {
            final followerIds = followRecords.map((record) => record.data['follower']).toList();
            final followersFilter = followerIds.map((id) => 'id = "$id"').join(' || ');

            final usersRecords = await _authService.pb
                .collection(AppConstants.usersCollection)
                .getFullList(
                  filter: '($followersFilter) && isPublic = true',
                  sort: 'name',
                );

            final followers = usersRecords
                .map((record) => UserModel.fromJson(record.toJson()))
                .toList();

            // Save to Cache for next time ⚡
            await _saveFollowersToCache(followers);

            // Update UI with fresh data
            if (!mounted) return;
            setState(() {
              _followers = followers;
              _filteredFollowers = followers;
              _isLoadingFollowers = false;
            });
          } else {
            // Save empty list to cache
            await _saveFollowersToCache([]);

            if (!mounted) return;
            setState(() {
              _followers = [];
              _filteredFollowers = [];
              _isLoadingFollowers = false;
            });
          }
        } catch (e) {
          print('خطأ في تحميل المتابعين من الخادم: $e');
          // Keep showing cached data (already loaded)
          if (mounted) {
            setState(() => _isLoadingFollowers = false);
          }
        }
      } else {
        // Offline - just show cached data (already loaded in step 1)
        if (mounted) {
          setState(() => _isLoadingFollowers = false);
        }
      }
    } catch (e) {
      print('خطأ عام في تحميل المتابعين: $e');
      if (mounted) {
        setState(() {
          _followers = [];
          _filteredFollowers = [];
          _isLoadingFollowers = false;
        });
      }
    }
  }

  // دوال Cache للمتابعين
  Future<void> _loadFollowersFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedData = prefs.getString('followers_$userId');
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final followers = jsonList.map((json) => UserModel.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            _followers = followers;
            _filteredFollowers = followers;
            _isLoadingFollowers = false;
          });
        }
      }
    } catch (e) {
      // Ignore cache errors
      print('خطأ في تحميل المتابعين من الذاكرة: $e');
    }
  }

  Future<void> _saveFollowersToCache(List<UserModel> followers) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final jsonList = followers.map((follower) => follower.toJson()).toList();
      await prefs.setString('followers_$userId', jsonEncode(jsonList));
    } catch (e) {
      // Ignore cache errors
      print('خطأ في حفظ المتابعين في الذاكرة: $e');
    }
  }

  // تحميل المتبوعين (من أتابعهم) - Offline First
  Future<void> _loadFollowing() async {
    if (!mounted) return;

    try {
      // 1. Load from Cache FIRST (instant) ⚡
      await _loadFollowingFromCache();

      // 2. Check internet connection
      final isOnline = await _connectivityService.hasConnection();
      if (!mounted) return;
      setState(() => _isOnline = isOnline);

      // 3. If online, update from PocketHost in background
      if (isOnline && _authService.isAuthenticated) {
        try {
          final currentUserId = _authService.currentUser?.id;
          if (currentUserId == null) return;

          // جلب المتبوعين
          final followRecords = await _authService.pb
              .collection(AppConstants.followsCollection)
              .getFullList(
                filter: 'follower = "$currentUserId"',
              );

          // جلب بيانات المستخدمين
          if (followRecords.isNotEmpty) {
            final followingIds = followRecords.map((record) => record.data['following']).toList();
            final followingFilter = followingIds.map((id) => 'id = "$id"').join(' || ');

            final usersRecords = await _authService.pb
                .collection(AppConstants.usersCollection)
                .getFullList(
                  filter: '($followingFilter) && isPublic = true',
                  sort: 'name',
                );

            final following = usersRecords
                .map((record) => UserModel.fromJson(record.toJson()))
                .toList();

            // Save to Cache for next time ⚡
            await _saveFollowingToCache(following);

            // Update UI with fresh data
            if (!mounted) return;
            setState(() {
              _following = following;
              _filteredFollowing = following;
              _isLoadingFollowing = false;
            });
          } else {
            // Save empty list to cache
            await _saveFollowingToCache([]);

            if (!mounted) return;
            setState(() {
              _following = [];
              _filteredFollowing = [];
              _isLoadingFollowing = false;
            });
          }
        } catch (e) {
          print('خطأ في تحميل المتبوعين من الخادم: $e');
          // Keep showing cached data (already loaded)
          if (mounted) {
            setState(() => _isLoadingFollowing = false);
          }
        }
      } else {
        // Offline - just show cached data (already loaded in step 1)
        if (mounted) {
          setState(() => _isLoadingFollowing = false);
        }
      }
    } catch (e) {
      print('خطأ عام في تحميل المتبوعين: $e');
      if (mounted) {
        setState(() {
          _following = [];
          _filteredFollowing = [];
          _isLoadingFollowing = false;
        });
      }
    }
  }

  // دوال Cache للمتبوعين
  Future<void> _loadFollowingFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final cachedData = prefs.getString('following_$userId');
      if (cachedData != null) {
        final List<dynamic> jsonList = jsonDecode(cachedData);
        final following = jsonList.map((json) => UserModel.fromJson(json)).toList();
        if (mounted) {
          setState(() {
            _following = following;
            _filteredFollowing = following;
            _isLoadingFollowing = false;
          });
        }
      }
    } catch (e) {
      // Ignore cache errors
      print('خطأ في تحميل المتبوعين من الذاكرة: $e');
    }
  }

  Future<void> _saveFollowingToCache(List<UserModel> following) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = _authService.currentUser?.id;
      if (userId == null) return;

      final jsonList = following.map((user) => user.toJson()).toList();
      await prefs.setString('following_$userId', jsonEncode(jsonList));
    } catch (e) {
      // Ignore cache errors
      print('خطأ في حفظ المتبوعين في الذاكرة: $e');
    }
  }

  // فلترة النتائج بناءً على البحث
  void _filterResults(String query) {
    setState(() {
      _searchQuery = query;
      
      if (query.isEmpty) {
        _filteredFollowers = _followers;
        _filteredFollowing = _following;
      } else {
        _filteredFollowers = _followers.where((user) {
          return ArabicSearchUtils.searchInUserFields(
            user.name,
            user.username,
            user.bio ?? '',
            query,
          );
        }).toList();
        
        _filteredFollowing = _following.where((user) {
          return ArabicSearchUtils.searchInUserFields(
            user.name,
            user.username,
            user.bio ?? '',
            query,
          );
        }).toList();
      }
    });
  }

  // الحصول على رابط الصورة الشخصية
  String? _getUserAvatarUrl(UserModel user) {
    if (user.avatar?.isEmpty ?? true) return null;

    // تنظيف اسم الملف من الأقواس والاقتباسات
    final cleanAvatar = user.avatar!.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  // تحديد لون الطوق حسب نشاط المستخدم
  Color _getUserRingColor(UserModel user) {
    // حالياً: رمادي دائماً في قائمة الأصدقاء
    Color ringColor = Colors.grey.shade400;

    // متاح للتطوير المستقبلي:
    // if (user.verified) ringColor = const Color(0xFF2196F3); // أزرق للمتحققين
    // if (user.isOnline) ringColor = Colors.green; // أخضر للمتصلين
    // if (user.hasActiveAppointment) ringColor = Colors.orange; // برتقالي للنشطين
    // if (user.isPremium) ringColor = Colors.purple; // بنفسجي للمميزين

    return ringColor;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('الأصدقاء'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.blue,
          tabs: [
            Tab(
              text: 'المتابعون (${_followers.length})',
            ),
            Tab(
              text: 'المتبوعون (${_following.length})',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // حقل البحث
          Container(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              textAlign: TextAlign.right,
              decoration: InputDecoration(
                hintText: 'ابحث في الأصدقاء...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.blue),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: _filterResults,
            ),
          ),
          
          // التبويبات
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFollowersList(),
                _buildFollowingList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // قائمة المتابعين
  Widget _buildFollowersList() {
    if (_isLoadingFollowers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredFollowers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'لا يوجد متابعون' : 'لا توجد نتائج',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFollowers.length,
      itemBuilder: (context, index) {
        final user = _filteredFollowers[index];
        return _buildUserCard(user);
      },
    );
  }

  // قائمة المتبوعين
  Widget _buildFollowingList() {
    if (_isLoadingFollowing) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_filteredFollowing.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_add_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isEmpty ? 'لا تتابع أحداً' : 'لا توجد نتائج',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredFollowing.length,
      itemBuilder: (context, index) {
        final user = _filteredFollowing[index];
        return _buildUserCard(user);
      },
    );
  }

  // بطاقة المستخدم
  Widget _buildUserCard(UserModel user) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 52, // 48 + (2 * 2) للطوق
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: _getUserRingColor(user), // لون ديناميكي
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(2), // الفجوة بين الصورة والطوق
            child: CircleAvatar(
              radius: 22,
              backgroundImage: _getUserAvatarUrl(user) != null
                  ? NetworkImage(_getUserAvatarUrl(user)!)
                  : null,
              backgroundColor: Colors.grey.shade200,
              child: _getUserAvatarUrl(user) == null
                  ? const Icon(Icons.person, size: 22)
                  : null,
            ),
          ),
        ),
        title: Text(
          user.name,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '@${user.username}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            if (user.bio?.isNotEmpty ?? false) ...[
              const SizedBox(height: 4),
              Text(
                user.bio!,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(
                userId: user.id,
                username: user.username,
              ),
            ),
          );
        },
      ),
    );
  }
}
