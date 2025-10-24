# ملخص ميزات نظام إضافة المواعيد - سجلي

## 📋 **نظرة عامة**

تم تطوير نظام شامل لإضافة المواعيد في تطبيق "سجلي" مع ميزات متقدمة لفحص التعارض وإدارة الضيوف والملاحظات.

---

## 🔴 **1. نظام فحص التعارض الشامل**

### **الوصف:**
نظام ذكي يفحص تداخل المواعيد ويحذر المستخدم بصرياً من التعارضات.

### **الميزات:**

#### **🕐 فحص تعارض مواعيدي الشخصية:**
- **الموقع:** صفحة إضافة الموعد
- **الوظيفة:** فحص التعارض مع مواعيد المستخدم الحالي
- **التصور:** حدود حمراء حول حقول الوقت (الساعة والدقيقة)
- **السلوك:** تحذير بصري فقط - لا يمنع الحفظ

#### **👥 فحص تعارض مواعيد الأصدقاء:**
- **الموقع:** صندوق اختيار الضيوف
- **الوظيفة:** فحص التعارض مع مواعيد الأصدقاء المدعوين
- **التصور:** طوق أحمر حول صورة الصديق المتعارض
- **السلوك:** تحذير بصري - يمكن تجاهله والمتابعة

#### **🏠 عرض التعارض في الصفحة الرئيسية:**
- **الموقع:** بطاقات المواعيد في الصفحة الرئيسية
- **الوظيفة:** إظهار المواعيد المتداخلة
- **التصور:** وقت أحمر وعريض للمواعيد المتعارضة
- **السلوك:** عرض فقط - لا يوجد تفاعل

### **الكود الرئيسي:**

#### **في `lib/screens/main_screen.dart`:**
```dart
// فحص تعارض مواعيدي
bool _hasMyTimeConflict() {
  if (_selectedDuration == 'عدة أيام') return false;
  final myId = _authService.currentUser?.id;
  if (myId == null) return false;
  final start = _buildAppointmentDateTime();
  final end = start.add(Duration(minutes: 45));
  return _checkFriendAppointmentConflict(myId, start, end);
}

// تحميل مواعيدي للفحص
Future<void> _loadMyAppointments() async {
  final myId = _authService.currentUser?.id;
  if (myId == null) return;
  
  // جلب مواعيدي كمضيف
  final myAppointments = await _authService.pb
      .collection(AppConstants.appointmentsCollection)
      .getFullList(filter: 'host = "$myId" && status = "active"');
  
  _friendAppointments[myId] = myAppointments
      .map((record) => AppointmentModel.fromJson(record.toJson()))
      .toList();
      
  // جلب دعواتي المقبولة
  final myInvitations = await _authService.pb
      .collection(AppConstants.invitationsCollection)
      .getFullList(filter: 'guest = "$myId" && status = "accepted"');
  
  _friendInvitations[myId] = myInvitations
      .map((record) => record.toJson())
      .toList();
}
```

#### **في `lib/screens/home_screen.dart`:**
```dart
// فحص تداخل المواعيد في الصفحة الرئيسية
bool _hasTimeConflict(AppointmentModel appointment) {
  final appointmentStart = appointment.appointmentDate;
  final appointmentEnd = appointmentStart.add(const Duration(minutes: 45));
  
  return _appointments.any((otherAppointment) {
    if (otherAppointment.id == appointment.id) return false;
    final otherStart = otherAppointment.appointmentDate;
    final otherEnd = otherStart.add(const Duration(minutes: 45));
    return appointmentStart.isBefore(otherEnd) && appointmentEnd.isAfter(otherStart);
  });
}
```

---

## 📝 **2. حقل الملاحظات المتطور**

### **الوصف:**
حقل نص مرن لإضافة ملاحظات أو روابط مفيدة للموعد.

### **الميزات:**
- **سطر واحد يتوسع تلقائياً** حسب حجم النص
- **تصميم أنيق** مع أيقونة ونص توضيحي
- **حفظ في قاعدة البيانات** في حقل `note_shared`
- **تنظيف تلقائي** عند إعادة تعيين النموذج

### **الموقع:**
تحت صندوق اختيار الضيوف في صفحة إضافة الموعد

### **الكود:**
```dart
Widget _buildNotesSection() {
  return Container(
    padding: const EdgeInsets.all(16),
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
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    ),
  );
}
```

### **الاستخدامات المتوقعة:**
- روابط الاجتماعات (Zoom, Teams, Google Meet)
- تعليمات خاصة للوصول
- معلومات إضافية أو جدول أعمال
- تذكيرات ومتطلبات

---

## 🖱️ **3. زر الحفظ الذكي**

### **الوصف:**
زر حفظ متطور يوفر خيارين للمستخدم حسب طريقة الضغط.

### **الميزات:**

#### **👆 الضغط العادي:**
- **الوظيفة:** حفظ الموعد والانتقال للصفحة الرئيسية
- **الاستخدام:** للمستخدم العادي الذي يريد إضافة موعد واحد
- **الرسالة:** "تم حفظ الموعد بنجاح"

#### **👆🔒 الضغط المطول (Hold):**
- **الوظيفة:** حفظ الموعد وتنظيف الحقول والبقاء في الصفحة
- **الاستخدام:** للمستخدم المتقدم الذي يريد إضافة عدة مواعيد
- **الرسالة:** "تم حفظ الموعد بنجاح - يمكنك إضافة موعد آخر"

### **التصميم:**
```dart
GestureDetector(
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
        Icon(Icons.save, color: Colors.white),
        const SizedBox(width: 8),
        Text('حفظ الموعد', style: TextStyle(color: Colors.white)),
      ],
    ),
  ),
),
```

### **تلميح للمستخدم:**
```
ℹ️ اضغط للحفظ والانتقال للرئيسية • اضغط مطولاً للحفظ وإضافة موعد آخر
```

---

## 🔧 **4. التفاصيل التقنية**

### **الملفات المعدلة:**
- `lib/screens/main_screen.dart` - الملف الرئيسي لصفحة إضافة المواعيد
- `lib/screens/home_screen.dart` - عرض التعارضات في الصفحة الرئيسية

### **قاعدة البيانات:**
- **الحقل المستخدم:** `note_shared` في جدول `appointments`
- **النوع:** نص اختياري (nullable)

### **المتغيرات المضافة:**
```dart
final _notesController = TextEditingController();
```

### **الدوال الجديدة:**
- `_hasMyTimeConflict()` - فحص تعارض مواعيدي
- `_loadMyAppointments()` - تحميل مواعيدي للفحص
- `_buildNotesSection()` - بناء قسم الملاحظات
- `_saveAppointmentAndStay()` - حفظ مع البقاء في الصفحة
- `_navigateToHome()` - الانتقال للصفحة الرئيسية

---

## 🎯 **5. الحالة النهائية**

### **✅ مكتمل:**
- نظام فحص التعارض الشامل
- حقل الملاحظات المرن
- زر الحفظ الذكي
- التصميم والواجهة

### **⏳ مؤجل للمستقبل:**
- فحص وجود الروابط في الملاحظات
- إضافة زر الرابط في هيدر بطاقة الموعد
- التفاعل مع الروابط عند الضغط

**ملاحظة:** تم تأجيل ميزة الروابط حسب طلب المستخدم لحين تصميم وتنظيم بطاقة الموعد.

---

## 📊 **6. ملخص الإنجازات**

**تم إنشاء نظام متكامل لإضافة المواعيد يتضمن:**
- ✅ فحص تعارض شامل ومرئي
- ✅ إدارة ضيوف متطورة
- ✅ ملاحظات مرنة وقابلة للتوسع
- ✅ خيارات حفظ ذكية ومرنة
- ✅ تجربة مستخدم ممتازة وبديهية

**النظام جاهز للإطلاق والاستخدام! 🚀**

---

## 📱 **7. نظام الحفظ الأوفلاين**

### **الوصف:**
نظام متطور للحفظ المحلي عندما يكون التطبيق بدون اتصال إنترنت، مع مزامنة تلقائية عند العودة للاتصال.

### **الميزات:**

#### **💾 الحفظ المحلي:**
- **الموقع:** صفحة إضافة الموعد
- **الوظيفة:** حفظ المواعيد في SharedPreferences عند عدم وجود اتصال
- **البيانات المحفوظة:**
  - بيانات الموعد كاملة
  - قائمة الضيوف المدعوين
  - معرف مؤقت للمزامنة
  - حالة المزامنة (pending)

#### **🔄 المزامنة التلقائية:**
- **التشغيل:** عند عودة الاتصال بالإنترنت
- **الوظيفة:** رفع جميع المواعيد المحفوظة محلياً للخادم
- **التنظيف:** إزالة البيانات المحلية بعد الرفع الناجح

### **الكود الرئيسي:**

#### **في `lib/screens/main_screen.dart`:**
```dart
// حفظ الموعد محلياً عند عدم وجود اتصال
Future<void> _saveAppointmentOffline(Map<String, dynamic> appointmentData) async {
  try {
    // إضافة معرف مؤقت للموعد
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    appointmentData['id'] = tempId;
    appointmentData['temp_id'] = tempId;
    appointmentData['sync_status'] = 'pending';
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

// فحص الاتصال والحفظ المناسب
final isOnline = await _connectivityService.hasConnection();

if (isOnline) {
  // حفظ الموعد في PocketBase (أونلاين)
  final record = await _authService.pb
      .collection(AppConstants.appointmentsCollection)
      .create(body: appointmentData);
  _showSuccessMessage('تم حفظ الموعد بنجاح');
} else {
  // حفظ الموعد محلياً (أوفلاين)
  await _saveAppointmentOffline(appointmentData);
  _showSuccessMessage('تم حفظ الموعد محلياً - سيتم رفعه عند الاتصال بالإنترنت');
}
```

#### **في `lib/screens/home_screen.dart`:**
```dart
// مزامنة المواعيد المحفوظة أوفلاين
Future<void> _syncOfflineAppointments() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final offlineAppointments = prefs.getStringList('offline_appointments') ?? [];

    if (offlineAppointments.isEmpty) return;

    List<String> syncedAppointments = [];

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

      // إعادة تحميل المواعيد لعرض البيانات المحدثة
      _loadAppointments();
    }
  } catch (e) {
    print('❌ خطأ في مزامنة المواعيد: $e');
  }
}
```

---

## 🔄 **8. تحديث واجهة الاتصال**

### **الوصف:**
استبدال البنر التقليدي بسويش صغير أنيق لعرض حالة الاتصال.

### **الميزات:**

#### **📱 الدوائر الجديدة:**
- **الموقع:** أعلى الصفحة الرئيسية - الجهتين اليسرى واليمنى
- **التصميم:** دوائر صغيرة أنيقة مع أيقونات
- **الألوان:**
  - أخضر للاتصال (متصل)
  - برتقالي للأوفلاين (أوفلاين)
  - أزرق للمسودات (آدمن فقط)

#### **🔒 سويش المسودات للآدمن:**
- **الشرط:** يظهر فقط للمستخدمين بدور `admin`
- **الموقع:** أعلى الصفحة الرئيسية - الجهة اليمنى
- **الوظيفة:** الانتقال لصفحة المسودات

### **الكود:**

#### **في `lib/screens/home_screen.dart`:**
```dart
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

// دائرة المسودات في الزاوية اليمنى (للآدمن فقط)
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
```

### **التحسينات:**
- ✅ **واجهة أنظف** - دوائر صغيرة بدلاً من بنر كبير
- ✅ **معلومات واضحة** - حالة الاتصال مرئية دائماً
- ✅ **أمان محسن** - المسودات للآدمن فقط
- ✅ **تصميم متناسق** - دوائر موازية لصورة البروفايل
- ✅ **توفير مساحة** - تصميم مدمج وأنيق

---

## 🎯 **9. الحالة النهائية المحدثة**

### **✅ مكتمل:**
- نظام فحص التعارض الشامل
- حقل الملاحظات المرن
- زر الحفظ الذكي
- **نظام الحفظ الأوفلاين الكامل**
- **واجهة الاتصال المحدثة**
- **التحكم في المسودات حسب الدور**

### **⏳ مؤجل للمستقبل:**
- فحص وجود الروابط في الملاحظات
- إضافة زر الرابط في هيدر بطاقة الموعد
- التفاعل مع الروابط عند الضغط

### **🔧 التفاصيل التقنية المحدثة:**

#### **الملفات المعدلة:**
- `lib/screens/main_screen.dart` - إضافة نظام الحفظ الأوفلاين
- `lib/screens/home_screen.dart` - تحديث واجهة الاتصال والمزامنة

#### **المتغيرات والدوال الجديدة:**
- `_saveAppointmentOffline()` - حفظ محلي للمواعيد
- `_syncOfflineAppointments()` - مزامنة المواعيد عند الاتصال
- تحديث `_listenToConnectivity()` - إضافة المزامنة التلقائية

#### **التخزين المحلي:**
- `offline_appointments` - قائمة المواعيد المحفوظة محلياً
- `offline_invitations` - قائمة الدعوات المحفوظة محلياً

**النظام الآن مكتمل ومتطور مع دعم الأوفلاين الكامل! 🚀**
