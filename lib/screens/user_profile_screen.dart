import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/auth_service.dart';
import '../services/hijri_service.dart';
import '../models/user_model.dart';
import '../models/post_model.dart';

import '../config/constants.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? username;

  const UserProfileScreen({
    super.key,
    required this.userId,
    this.username,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();
  final HijriService _hijriService = HijriService();
  
  UserModel? _user;
  List<PostModel> _posts = [];
  bool _isLoading = true;
  bool _isFollowing = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }
  
  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      setState(() => _isLoading = true);

      // تحميل بيانات المستخدم
      final userRecord = await _authService.pb
          .collection(AppConstants.usersCollection)
          .getOne(widget.userId);
      
      _user = UserModel.fromJson(userRecord.toJson());
      
      // Profile loaded successfully

      // تحميل منشورات المستخدم
      final postRecords = await _authService.pb
          .collection(AppConstants.postsCollection)
          .getFullList(
            filter: 'author = "${widget.userId}"',
            sort: '-created',
          );

      _posts = postRecords.map((record) => PostModel.fromJson(record.toJson())).toList();

      // فحص حالة المتابعة
      await _checkFollowStatus();

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkFollowStatus() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      final records = await _authService.pb
          .collection('follows')
          .getFullList(
            filter: 'follower = "$currentUserId" && following = "${widget.userId}"',
          );

      if (mounted) {
        setState(() => _isFollowing = records.isNotEmpty);
      }
    } catch (e) {
      // تجاهل أخطاء فحص المتابعة
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      if (_isFollowing) {
        // إلغاء المتابعة
        final records = await _authService.pb
            .collection('follows')
            .getFullList(
              filter: 'follower = "$currentUserId" && following = "${widget.userId}"',
            );
        
        for (final record in records) {
          await _authService.pb.collection('follows').delete(record.id);
        }
      } else {
        // متابعة
        await _authService.pb.collection('follows').create(body: {
          'follower': currentUserId,
          'following': widget.userId,
        });
      }

      setState(() => _isFollowing = !_isFollowing);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث المتابعة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyProfileLink() async {
    if (_user != null) {
      final profileLink = 'sijilli.com/${_user!.username}';
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

  String? _getUserAvatarUrl(UserModel? user) {
    if (user?.avatar == null || user!.avatar?.isEmpty == true) {
      return null;
    }

    final cleanAvatar = user.avatar!.replaceAll('[', '').replaceAll(']', '').replaceAll('"', '');
    return '${AppConstants.pocketbaseUrl}/api/files/${AppConstants.usersCollection}/${user.id}/$cleanAvatar';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(_user?.name ?? widget.username ?? 'المستخدم'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? const Center(child: Text('لم يتم العثور على المستخدم'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header Section
                      _buildUserHeader(),
                      
                      // Posts Section
                      _buildPostsSection(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildUserHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // User Profile Picture
          Container(
            padding: const EdgeInsets.only(top: 10, bottom: 12),
            child: _buildUserProfilePicture(),
          ),

          // User Info Section
          _buildUserInfoSection(),

          // Action Buttons
          _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildPostsSection() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: _posts.isEmpty
          ? Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.article_outlined,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد منشورات',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                return _buildPostCard(_posts[index]);
              },
            ),
    );
  }

  // Widget صورة المستخدم
  Widget _buildUserProfilePicture() {
    return Center(
      child: Container(
        width: 146, // 140 + (3 * 2) للطوق والفجوة
        height: 146,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.grey.shade400,
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
              child: _getUserAvatarUrl(_user) == null
                  ? Icon(
                      Icons.person,
                      size: 70,
                      color: Colors.grey.shade500,
                    )
                  : ClipOval(
                      child: Image.network(
                        _getUserAvatarUrl(_user)!,
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

  // Widget رابط الحساب
  Widget _buildProfileLink() {
    if (_user == null) return const SizedBox.shrink();

    final profileLink = 'sijilli.com/${_user!.username}';

    return Center(
      child: GestureDetector(
        onTap: _copyProfileLink,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              profileLink,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.copy,
              size: 14,
              color: Colors.grey.shade600,
            ),
          ],
        ),
      ),
    );
  }

  // Widget اسم المستخدم
  Widget _buildUserDisplayName() {
    if (_user?.name == null || _user!.name.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Text(
        _user!.name,
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
    if (_user == null || _user!.bio == null || _user!.bio!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Text(
          _user!.bio!,
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
    if (_user == null) return const SizedBox(height: 20);

    final hasProfileLink = _user!.username.isNotEmpty;
    final hasDisplayName = _user!.name.isNotEmpty;
    final hasBio = _user!.bio != null && _user!.bio!.isNotEmpty;

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

  // Widget الأزرار
  Widget _buildActionButtons() {
    final currentUserId = _authService.currentUser?.id;
    final isOwnProfile = currentUserId == widget.userId;

    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // زر الرسائل
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
              onTap: _sendMessage,
              borderRadius: BorderRadius.circular(15),
              child: Icon(
                Icons.message_outlined,
                size: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          const SizedBox(width: 6),

          // زر المتابعة/إلغاء المتابعة
          if (!isOwnProfile)
            Container(
              width: 120,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: _isFollowing ? const Color(0xFF2196F3) : Colors.grey.shade300,
                  width: 1,
                ),
                color: _isFollowing ? const Color(0xFF2196F3) : Colors.white,
              ),
              child: InkWell(
                onTap: _toggleFollow,
                borderRadius: BorderRadius.circular(15),
                child: Center(
                  child: Text(
                    _isFollowing ? 'إلغاء المتابعة' : 'متابعة',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _isFollowing ? Colors.white : Colors.grey.shade700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // دالة إرسال رسالة
  void _sendMessage() {
    // TODO: تنفيذ إرسال الرسائل
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('ميزة الرسائل قريباً...'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // Widget بطاقة المنشور
  Widget _buildPostCard(PostModel post) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Post Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: _getUserAvatarUrl(_user) != null
                      ? NetworkImage(_getUserAvatarUrl(_user)!)
                      : null,
                  child: _getUserAvatarUrl(_user) == null
                      ? Icon(Icons.person, color: Colors.grey.shade600)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _user?.name ?? 'مستخدم',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _formatDate(post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Post Content
            Text(
              post.content,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 12),

            // Post Actions
            Row(
              children: [
                Icon(Icons.favorite_border, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${post.likesCount ?? 0}', style: TextStyle(color: Colors.grey.shade600)),

                const SizedBox(width: 20),

                Icon(Icons.comment_outlined, size: 20, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text('${post.commentsCount ?? 0}', style: TextStyle(color: Colors.grey.shade600)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      // For dates more than a day old, show Hijri date with profile owner's adjustment
      final hijriDate = _hijriService.convertGregorianToHijri(date);
      final hijriString = _hijriService.formatHijriDate(hijriDate);
      return '${difference.inDays} يوم ($hijriString)';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}
