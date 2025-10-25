import 'package:flutter/material.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../services/auth_service.dart';
import '../services/timezone_service.dart';
import '../utils/arabic_search_utils.dart';
import '../config/constants.dart';

class AppointmentCard extends StatefulWidget {
  final AppointmentModel appointment;
  final List<UserModel> guests;
  final List<InvitationModel> invitations;
  final VoidCallback? onTap;
  final Function(String)? onPrivacyChanged;
  final Function(List<String>)? onGuestsChanged;

  const AppointmentCard({
    super.key,
    required this.appointment,
    this.guests = const [],
    this.invitations = const [],
    this.onTap,
    this.onPrivacyChanged,
    this.onGuestsChanged,
  });

  @override
  State<AppointmentCard> createState() => _AppointmentCardState();
}

class _AppointmentCardState extends State<AppointmentCard> {
  final AuthService _authService = AuthService();

  // الحصول على حالة الضيف من الدعوة
  String _getGuestStatus(UserModel guest) {
    final invitation = widget.invitations.firstWhere(
      (inv) => inv.guestId == guest.id,
      orElse: () => InvitationModel(
        id: '',
        appointmentId: widget.appointment.id,
        guestId: guest.id,
        status: 'invited',
        created: DateTime.now(),
        updated: DateTime.now(),
      ),
    );
    return invitation.ringStatus;
  }

  // الحصول على لون الطوق حسب الحالة
  Color _getRingColor(String status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'deleted':
        return Colors.red;
      case 'cancelled':
        return Colors.transparent; // مخفي
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  // تبديل الخصوصية
  Future<void> _togglePrivacy() async {
    final newPrivacy = widget.appointment.privacy == 'public' ? 'private' : 'public';

    try {
      // تحديث الخصوصية في قاعدة البيانات
      await _authService.pb
          .collection(AppConstants.appointmentsCollection)
          .update(widget.appointment.id, body: {
        'privacy': newPrivacy,
      });

      // استدعاء callback للتحديث في الواجهة الأساسية
      widget.onPrivacyChanged?.call(newPrivacy);

      // إظهار بنر التنبيه
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPrivacy == 'public'
                ? 'تم تغيير الموعد إلى عام'
                : 'تم تغيير الموعد إلى خاص',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: newPrivacy == 'public' ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      // إظهار رسالة خطأ
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الخصوصية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // إظهار قائمة إضافة الضيوف مع البحث
  void _showAddGuestsDialog() {
    showDialog(
      context: context,
      builder: (context) => _GuestSelectionDialog(
        appointmentId: widget.appointment.id,
        currentGuests: widget.guests.map((g) => g.id).toList(),
        onGuestsSelected: (selectedGuestIds) {
          widget.onGuestsChanged?.call(selectedGuestIds);
        },
      ),
    );
  }

  // بناء كبسولة الخصوصية
  Widget _buildPrivacyCapsule() {
    final isPublic = widget.appointment.privacy == 'public';
    return GestureDetector(
      onTap: _togglePrivacy,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isPublic ? Colors.green.shade50 : Colors.orange.shade50,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isPublic ? Colors.green.shade200 : Colors.orange.shade200,
            width: 1,
          ),
        ),
        child: Text(
          isPublic ? 'عام' : 'خاص',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isPublic ? Colors.green.shade700 : Colors.orange.shade700,
          ),
        ),
      ),
    );
  }

  // بناء صورة الضيف مع الطوق الديناميكي
  Widget _buildGuestAvatar(UserModel guest) {
    final status = _getGuestStatus(guest);
    final ringColor = _getRingColor(status);

    if (status == 'cancelled') {
      return const SizedBox.shrink(); // مخفي للملغيين
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: ringColor,
          width: status == 'active' ? 3 : 2, // طوق أسمك للنشطين
        ),
        // إضافة ظل للطوق النشط
        boxShadow: status == 'active' ? [
          BoxShadow(
            color: ringColor.withValues(alpha: 0.3),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ] : null,
      ),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey.shade100,
        backgroundImage: (guest.avatar?.isNotEmpty ?? false)
            ? NetworkImage(_getUserAvatarUrl(guest))
            : null,
        child: (guest.avatar?.isEmpty ?? true)
            ? Icon(
                Icons.person,
                size: 20,
                color: Colors.grey.shade600,
              )
            : null,
      ),
    );
  }

  // بناء كبسولة اسم الضيف مع تلوين حسب الحالة
  Widget _buildGuestNameCapsule(UserModel guest) {
    final status = _getGuestStatus(guest);

    if (status == 'cancelled') {
      return const SizedBox.shrink(); // مخفي للملغيين
    }

    // تحديد ألوان الكبسولة حسب الحالة
    Color backgroundColor;
    Color textColor;
    Color borderColor;

    switch (status) {
      case 'active':
        backgroundColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        borderColor = Colors.green.shade200;
        break;
      case 'deleted':
        backgroundColor = Colors.red.shade50;
        textColor = Colors.red.shade700;
        borderColor = Colors.red.shade200;
        break;
      case 'pending':
      default:
        backgroundColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        borderColor = Colors.grey.shade300;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Text(
        guest.name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: status == 'active' ? FontWeight.w600 : FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }

  // بناء زر إضافة الضيوف
  Widget _buildAddGuestButton() {
    return GestureDetector(
      onTap: _showAddGuestsDialog,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.blue.shade50,
          border: Border.all(
            color: Colors.blue.shade200,
            width: 1,
          ),
        ),
        child: Icon(
          Icons.add,
          size: 18,
          color: Colors.blue.shade600,
        ),
      ),
    );
  }

  // الحصول على رابط صورة المستخدم
  String _getUserAvatarUrl(UserModel user) {
    if (user.avatar?.isEmpty ?? true) return '';
    return '${AppConstants.pocketbaseUrl}/api/files/users/${user.id}/${user.avatar}';
  }

  @override
  Widget build(BuildContext context) {
    final firstGuest = widget.guests.isNotEmpty ? widget.guests.first : null;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الهيدر مع الكبسولات
              Row(
                children: [
                  // كبسولة الخصوصية
                  _buildPrivacyCapsule(),
                  const Spacer(),
                  // صورة أول ضيف مع الطوق
                  if (firstGuest != null) ...[
                    _buildGuestAvatar(firstGuest),
                    const SizedBox(width: 6),
                    // اسم الضيف في كبسولة
                    _buildGuestNameCapsule(firstGuest),
                    const SizedBox(width: 6),
                  ],
                  // زر إضافة الضيوف
                  _buildAddGuestButton(),
                ],
              ),
              const SizedBox(height: 16),
              
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
              
              // المكان (إذا موجود)
              if (widget.appointment.region?.isNotEmpty ?? false) ...[
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      widget.appointment.region!,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                    ),
                    if (widget.appointment.building?.isNotEmpty ?? false)
                      Text(
                        ' - ${widget.appointment.building}',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
              
              // التاريخ والوقت
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    () {
                      final localDate = TimezoneService.toLocal(widget.appointment.appointmentDate);
                      return '${localDate.day}/${localDate.month}/${localDate.year}';
                    }(),
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    TimezoneService.formatTime12Hour(
                      TimezoneService.toLocal(widget.appointment.appointmentDate)
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// مكون حوار اختيار الضيوف مع البحث
class _GuestSelectionDialog extends StatefulWidget {
  final String appointmentId;
  final List<String> currentGuests;
  final Function(List<String>) onGuestsSelected;

  const _GuestSelectionDialog({
    required this.appointmentId,
    required this.currentGuests,
    required this.onGuestsSelected,
  });

  @override
  State<_GuestSelectionDialog> createState() => _GuestSelectionDialogState();
}

class _GuestSelectionDialogState extends State<_GuestSelectionDialog> {
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();

  List<UserModel> _allFriends = [];
  List<UserModel> _filteredFriends = [];
  List<String> _selectedGuests = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedGuests = List.from(widget.currentGuests);
    _loadFriends();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _filterFriends();
    });
  }

  void _filterFriends() {
    if (_searchQuery.isEmpty) {
      _filteredFriends = List.from(_allFriends);
    } else {
      _filteredFriends = _allFriends.where((friend) {
        return ArabicSearchUtils.searchInUserFields(
          friend.name,
          friend.username,
          friend.bio ?? '',
          _searchQuery,
        );
      }).toList();
    }
  }

  Future<void> _loadFriends() async {
    try {
      final currentUserId = _authService.currentUser?.id;
      if (currentUserId == null) return;

      // جلب المتابعات (من أتابعهم) - نفس منطق الصفحة الرئيسية
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
      final friends = <UserModel>[];
      if (friendIds.isNotEmpty) {
        final friendsFilter = friendIds.map((id) => 'id = "$id"').join(' || ');
        final usersRecords = await _authService.pb
            .collection(AppConstants.usersCollection)
            .getFullList(
              filter: '($friendsFilter) && isPublic = true',
              sort: 'name',
            );

        friends.addAll(usersRecords
            .map((record) => UserModel.fromJson(record.toJson()))
            .toList());
      }

      setState(() {
        _allFriends = friends;
        _filterFriends();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleGuestSelection(String guestId) {
    setState(() {
      if (_selectedGuests.contains(guestId)) {
        _selectedGuests.remove(guestId);
      } else {
        _selectedGuests.add(guestId);
      }
    });
  }

  void _saveSelection() {
    widget.onGuestsSelected(_selectedGuests);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة ضيوف'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            // شريط البحث
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'البحث عن الأصدقاء...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 16),

            // قائمة الأصدقاء
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredFriends.isEmpty
                      ? Center(
                          child: Text(
                            _searchQuery.isEmpty
                                ? 'لا توجد متابعات'
                                : 'لا توجد نتائج للبحث',
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _filteredFriends.length,
                          itemBuilder: (context, index) {
                            final friend = _filteredFriends[index];
                            final isSelected = _selectedGuests.contains(friend.id);

                            return CheckboxListTile(
                              secondary: CircleAvatar(
                                radius: 20,
                                backgroundImage: (friend.avatar?.isNotEmpty ?? false)
                                    ? NetworkImage('${AppConstants.pocketbaseUrl}/api/files/users/${friend.id}/${friend.avatar}')
                                    : null,
                                child: (friend.avatar?.isEmpty ?? true)
                                    ? const Icon(Icons.person, size: 20)
                                    : null,
                              ),
                              title: Text(friend.name),
                              subtitle: Text('@${friend.username}'),
                              value: isSelected,
                              onChanged: (value) => _toggleGuestSelection(friend.id),
                              activeColor: Colors.blue,
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _saveSelection,
          child: Text('حفظ (${_selectedGuests.length})'),
        ),
      ],
    );
  }
}
