# مناقشة تصميم بطاقة الموعد - سجلي

## 📋 **السياق والمتطلبات**

### **🎯 المبادئ الأساسية:**
- **العصرية والجدية** هي من أهم سمات الصفحة الرئيسية
- **بطاقة الموعد** هي أهم جزء ولا بد أن تكون:
  - متناسقة قليلة الألوان
  - جادة وحديثة
  - بصرياً غير مزعجة
  - الترميزات تكون تلميحية
- **وحدة المظهر** بين كل بطاقات التطبيق

---

## 📊 **مخرجات صفحة الإضافة**

### **🔤 البيانات الأساسية:**
1. **العنوان** (`title`) - إلزامي
2. **المنطقة** (`region`) - اختياري  
3. **المبنى** (`building`) - اختياري
4. **الخصوصية** (`privacy`) - إلزامي: `'public'` أو `'private'`

### **📅 بيانات التاريخ والوقت:**
5. **نوع التاريخ** - ميلادي أو هجري
6. **التاريخ** (`appointment_date`) - محفوظ بصيغة UTC ISO8601
7. **الوقت** - ساعة ودقيقة مع صباحاً/مساءً
8. **يوم الأسبوع** - للتواريخ الميلادية
9. **المدة** - من قائمة محددة (15د، 30د، 45د، 60د، 90د، 120د، عدة أيام)

### **👥 بيانات الضيوف:**
10. **الضيوف المختارون** (`_selectedGuests`) - قائمة معرفات المستخدمين
11. **دعوات الضيوف** - تُحفظ في collection منفصل `invitations`

### **📝 بيانات إضافية:**
12. **الملاحظات** (`note_shared`) - اختياري
13. **المضيف** (`host`) - معرف المستخدم الحالي تلقائياً
14. **الحالة** (`status`) - `'active'` افتراضياً
15. **رابط البث** (`stream_link`) - `null` افتراضياً

---

## 🎨 **التصميم الحالي المشترك**

### **📐 الهيكل الأساسي:**
```dart
Container(
  margin: const EdgeInsets.only(bottom: 12),
  decoration: BoxDecoration(
    color: Colors.white,                    // خلفية بيضاء نظيفة
    borderRadius: BorderRadius.circular(13), // زوايا مدورة متوسطة
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05), // ظل خفيف جداً
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  ),
  child: Padding(
    padding: const EdgeInsets.all(16),     // مساحة داخلية موحدة
    // المحتوى...
  ),
)
```

### **🎯 العناصر المشتركة الحالية:**

#### **1. العنوان + شارة الخصوصية:**
```dart
Row(
  children: [
    Expanded(
      child: Text(
        appointment.title,
        style: const TextStyle(
          fontSize: 18,                    // خط كبير
          fontWeight: FontWeight.bold,     // عريض
          color: Colors.black87,           // أسود داكن
        ),
      ),
    ),
    Container(                            // شارة الخصوصية
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: appointment.privacy == 'public' 
            ? Colors.green.shade50         // أخضر فاتح للعام
            : Colors.orange.shade50,       // برتقالي فاتح للخاص
        borderRadius: BorderRadius.circular(13),
      ),
      child: Text(
        appointment.privacy == 'public' ? 'عام' : 'خاص',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: appointment.privacy == 'public'
              ? Colors.green.shade700      // أخضر داكن
              : Colors.orange.shade700,    // برتقالي داكن
        ),
      ),
    ),
  ],
),
```

#### **2. المكان (إذا موجود):**
```dart
if (appointment.region != null) ...[
  Row(
    children: [
      Icon(
        Icons.location_on_outlined,       // أيقونة موقع
        size: 16,                        // حجم صغير
        color: Colors.grey.shade600,     // رمادي متوسط
      ),
      const SizedBox(width: 8),
      Text(
        appointment.region!,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      ),
      if (appointment.building != null) ...[
        Text(' - ${appointment.building}', // مدمج مع المنطقة
             style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
      ],
    ],
  ),
  const SizedBox(height: 8),
],
```

#### **3. التاريخ والوقت:**
```dart
Row(
  children: [
    Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade600),
    const SizedBox(width: 8),
    Text(
      '${localDate.day}/${localDate.month}/${localDate.year}',
      style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
    ),
    const SizedBox(width: 16),
    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
    const SizedBox(width: 8),
    Text(
      TimezoneService.formatTime12Hour(localDate),
      style: TextStyle(
        fontSize: 14,
        color: _hasTimeConflict(appointment) ? Colors.red : Colors.grey.shade700,
        fontWeight: _hasTimeConflict(appointment) ? FontWeight.bold : FontWeight.normal,
      ),
    ),
  ],
),
```

---

## 🎨 **المبادئ التصميمية المشتركة**

### **🎯 الألوان الأساسية:**
- **الخلفية:** `Colors.white` - نظيفة وجادة
- **النص الرئيسي:** `Colors.black87` - واضح ومقروء
- **النص الثانوي:** `Colors.grey.shade700` - هادئ
- **الأيقونات:** `Colors.grey.shade600` - تلميحية
- **الظل:** `Colors.black.withValues(alpha: 0.05)` - خفيف جداً

### **🔤 الخطوط:**
- **العنوان:** `fontSize: 18, fontWeight: FontWeight.bold`
- **النص العادي:** `fontSize: 14, fontWeight: FontWeight.normal`
- **الشارات:** `fontSize: 12, fontWeight: FontWeight.w500`

### **📏 المسافات:**
- **الحواف الخارجية:** `margin: EdgeInsets.only(bottom: 12)`
- **الحواف الداخلية:** `padding: EdgeInsets.all(16)`
- **بين العناصر:** `SizedBox(height: 8-12)`
- **بين الأيقونات والنص:** `SizedBox(width: 8)`

### **🔘 الأشكال:**
- **زوايا البطاقة:** `BorderRadius.circular(13)`
- **زوايا الشارات:** `BorderRadius.circular(13)`
- **حجم الأيقونات:** `size: 16`

---

## 📝 **الترتيب المقترح للبطاقة الجديدة**

### **🔝 من الأعلى إلى الأسفل:**

#### **1. العنوان + شارة الخصوصية**
- **الأهمية:** الأعلى - أول ما يراه المستخدم
- **التصميم:** نفس التصميم الحالي

#### **2. التاريخ والوقت**
- **الأهمية:** معلومات حرجة
- **التصميم:** نفس التصميم الحالي مع إضافة المدة

#### **3. المكان (المنطقة - المبنى)**
- **الأهمية:** معلومات مهمة للحضور
- **التصميم:** نفس التصميم الحالي

#### **4. الضيوف**
- **صور مصغرة:** دوائر صغيرة للضيوف
- **عدد الضيوف:** "+3 آخرين" إذا كانوا كثر
- **أيقونة مجموعة:** 👥

#### **5. التفاصيل الإضافية**
- **الخصوصية:** أيقونة 🔒 للخاص أو 🌐 للعام
- **المدة:** ⏱️ "45 دقيقة"
- **في سطر واحد** مع مسافة بينهما

#### **6. الملاحظات**
- **نص مقتطع:** أول 50 حرف مع "..."
- **لون فاتح:** رمادي
- **أيقونة ملاحظة:** 📝

---

## ❓ **أسئلة للمناقشة**

### **1. الأولوية في العرض:**
- هل تفضل **التاريخ والوقت** في الأعلى أم **العنوان**؟
- هل **المكان** أهم من **الضيوف** في الترتيب؟

### **2. التصميم البصري:**
- هل تريد **بطاقات مدمجة** (معلومات كثيرة في مساحة صغيرة)؟
- أم **بطاقات مفصلة** (مساحة أكبر لكل عنصر)؟

### **3. المعلومات الإضافية:**
- هل نعرض **حالة الدعوات** (مقبول/مرفوض/معلق)؟
- هل نعرض **وقت الإنشاء** أو **آخر تحديث**؟

### **4. التفاعل:**
- هل تريد **أزرار سريعة** (تعديل/حذف/مشاركة) في البطاقة؟
- أم **النقر على البطاقة** للانتقال لصفحة التفاصيل؟

---

## 🎯 **الخطوات التالية**

1. **تحديد الترتيب النهائي** للعناصر
2. **تصميم عرض الضيوف** (صور مصغرة أم قائمة)
3. **تحديد المعلومات الإضافية** المطلوب عرضها
4. **تطبيق التصميم** مع الحفاظ على المبادئ الحالية
5. **اختبار التناسق** مع باقي بطاقات التطبيق

---

**📅 تاريخ المناقشة:** 2025-10-25  
**🎯 الهدف:** تصميم بطاقة موعد عصرية وجادة ومتناسقة  
**📱 التطبيق:** سجلي - إدارة المواعيد والفعاليات
