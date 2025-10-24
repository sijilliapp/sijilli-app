# إصلاح مشكلة البحث في PocketBase

## المشكلة 🚨
البحث لا يجد أي مستخدمين عدا المستخدم الحالي بسبب قواعد الوصول المقيدة في PocketBase.

## السبب 🔍
قواعد الوصول الحالية في مجموعة `users`:
```json
"listRule": "id = @request.auth.id",
"viewRule": "id = @request.auth.id"
```

هذا يعني أن المستخدم يمكنه رؤية **نفسه فقط**.

## الحل المقترح ✅

### 1. تسجيل الدخول إلى PocketBase Admin
- اذهب إلى: `https://sijilli.pockethost.io/_/`
- سجل دخول كمدير

### 2. تعديل قواعد الوصول لمجموعة `users`
في قسم **Collections** → **users** → **API Rules**:

#### أ. تعديل `List/Search rule`:
```javascript
// الحالي (مقيد):
id = @request.auth.id

// الجديد (يسمح بالبحث في المستخدمين العامين):
isPublic = true || id = @request.auth.id
```

#### ب. تعديل `View rule`:
```javascript
// الحالي (مقيد):
id = @request.auth.id

// الجديد (يسمح برؤية المستخدمين العامين):
isPublic = true || id = @request.auth.id
```

### 3. التأكد من إعداد `isPublic` للمستخدمين
تأكد من أن المستخدمين الذين تريد ظهورهم في البحث لديهم `isPublic = true`.

## البديل: قواعد أكثر تفصيلاً 🔧

إذا كنت تريد المزيد من التحكم:

### للمستخدمين المعتمدين فقط:
```javascript
// List rule:
(isPublic = true && verified = true) || id = @request.auth.id

// View rule:
(isPublic = true && verified = true) || id = @request.auth.id
```

### للمستخدمين بدور معين:
```javascript
// List rule:
(isPublic = true && role != "user") || id = @request.auth.id

// View rule:
(isPublic = true && role != "user") || id = @request.auth.id
```

## اختبار الحل 🧪

بعد تطبيق التغييرات:
1. أعد تشغيل التطبيق
2. جرب البحث عن مستخدمين آخرين
3. يجب أن تظهر النتائج الآن

## ملاحظات أمنية 🔒

- **`isPublic = true`**: يعني أن المستخدم موافق على ظهور ملفه في البحث
- **`verified = true`**: يضمن أن المستخدم مؤكد
- **`role`**: يمكن استخدامه لتحديد من يظهر في البحث

## الكود المحدث في التطبيق

لا حاجة لتغيير الكود في التطبيق، سيعمل البحث تلقائياً بعد تحديث قواعد PocketBase.

## التحقق من النجاح ✅

بعد التطبيق، يجب أن يعمل البحث ويجد:
- المستخدم الحالي
- جميع المستخدمين الذين لديهم `isPublic = true`
- (حسب القاعدة المختارة) المستخدمين المعتمدين أو بأدوار معينة
