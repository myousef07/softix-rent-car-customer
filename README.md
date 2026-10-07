# SOftiX Rent Car — تطبيق العملاء

تطبيق Flutter للمستأجرين (Android وiOS)، يتصل بواجهة `/api/v1/customer` في مشروع [`rental-car`](https://github.com/myousef07/rental-car) (موثقة في `docs/api.md`). كل شركة تأجير تنشر نسختها باسمها وشعارها.

## ما يقدمه للعميل

| الشاشة | الوظيفة |
|---|---|
| الدخول | رقم الجوال ورمز SMS (يقبل الأرقام العربية والإنجليزية وصيغ +966)، مع إعادة إرسال بعد دقيقة |
| حساب جديد | الاسم، نوع الهوية ورقمها، الجنسية، تاريخ الميلاد، الرخصة وتاريخ انتهائها، البريد |
| الرئيسية | السيارة التي معه الآن وموعد إعادتها (وتنبيه التأخير)، حجزه القادم، تنبيه انتهاء الرخصة، والبحث عن سيارة |
| اختيار الفئة | كل فئات الفرع للفترة المختارة: الموديلات المعتادة، المقاعد، الكيلومترات المشمولة، التأمين المسترد، السعر لليوم والإجمالي شامل الضريبة، والفئات غير المتاحة معطّلة |
| تأكيد الحجز | فرع الإعادة، الإضافات بالكمية، رمز الخصم (مع رسالة الرفض)، ملاحظات للفرع، والسعر يتحدث مباشرة |
| حجوزاتي | القادمة والسابقة، والتفاصيل، والإلغاء (حتى ساعتين قبل الاستلام)، والاتصال بالفرع وموقعه |
| عقودي | الساري والمنتهي، البنود، المدفوع والمتبقي، **الدفع الإلكتروني للمتبقي**، ونسخة العقد PDF |
| فواتيري | الفواتير الضريبية والإشعارات الدائنة، وفتح الفاتورة PDF (برمز ZATCA) |
| حسابي | الهوية والرخصة (مقنّعة)، تعديل البريد والعنوان الوطني، الفروع، طلب عرض سعر، تسجيل الخروج |
| اطلب عرض سعر | للإيجار الشهري والتأجير الطويل وحسابات الشركات، ويعمل قبل التسجيل أيضاً؛ يصل لفريق المبيعات في الـ CRM |
| الإشعارات | فتح العقد، التمديد، تذكير الإعادة، التأخير، الإغلاق، رابط الدفع، مبلغ مستحق، مخالفة؛ والضغط على الإشعار يفتح العقد أو الفواتير |

الواجهة عربية بالكامل (RTL) بخط IBM Plex Sans Arabic، والمبالغ والتواريخ بأرقام إنجليزية وبتوقيت الرياض.

## بناء نسخة لشركة

```bash
flutter build appbundle \
  --android-project-arg=appId=sa.example.rent \
  --android-project-arg=appName="المثال لتأجير السيارات" \
  --dart-define=API_BASE_URL=https://rent.example.sa/api/v1 \
  --dart-define=COMPANY_ID=12 \
  --dart-define=COMPANY_NAME="شركة المثال لتأجير السيارات" \
  --dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_SENDER_ID=... --dart-define=FIREBASE_PROJECT_ID=...
```

- `COMPANY_ID`: رقم الشركة في المنصة. يجب أن تشمل خطة اشتراكها ميزة «تطبيق العملاء»، وميزة «إدارة علاقات العملاء» لطلبات عرض السعر.
- `appId` و`appName`: معرّف التطبيق في المتجر واسمه على الجوال. لكل شركة معرّف مختلف.
- الشعار: استبدل `assets/images/softix-logo.png` وأيقونات `android/app/src/main/res/mipmap-*` و`ios/Runner/Assets.xcassets/AppIcon.appiconset`.
- iOS: من Xcode غيّر Bundle Identifier وDisplay Name، وفعّل Push Notifications.

## الإشعارات (Firebase)

مشروع Firebase لتطبيقات العملاء: **softix-rental-customer** (منفصل عن مشروع تطبيق الموظفين).

1. في Firebase Console افتح المشروع، ثم «إضافة تطبيق» ← Android، واكتب معرّف الشركة (`com.softix.rentalCustomer` لنسخة SOftiX، أو معرّف الشركة مثل `sa.example.rent`). لا يلزم تنزيل `google-services.json`.
2. من «إعدادات المشروع» ← «عام» ← تطبيقك: انسخ **App ID** (`1:...:android:...`) و**Web API Key**، ومن تبويب Cloud Messaging انسخ **Sender ID**.
3. مرّرها وقت البناء: `--dart-define=FIREBASE_API_KEY=... --dart-define=FIREBASE_APP_ID=... --dart-define=FIREBASE_SENDER_ID=...` (`FIREBASE_PROJECT_ID` افتراضياً `softix-rental-customer`).
4. للخادم: «إعدادات المشروع» ← «حسابات الخدمة» ← «إنشاء مفتاح خاص جديد»، والصق ملف JSON في لوحة المنصة ← «إعدادات المنصة» ← «إشعارات الجوال» ← خانة **تطبيقات العملاء**.
5. iOS: أضف تطبيق iOS في المشروع نفسه وارفع مفتاح APNs (Cloud Messaging ← Apple app configuration).

كل شركة تأجير تطبيقها يُضاف في المشروع نفسه بمعرّفها؛ حساب الخدمة واحد للجميع. بدون هذه القيم يعمل التطبيق طبيعياً، لكن بلا إشعارات. الخادم يرسل الإشعار بنفس نص رسالة SMS، وفقط للرسائل المفعّلة في قوالب الشركة، ولا يرسل الحملات التسويقية أبداً.

## البناء التلقائي من لوحة المنصة

لا حاجة لـ Flutter على جهازك: من لوحة SOftiX ← «الشركات» ← الشركة ← «تطبيق العملاء» ← **بناء نسخة**. تُشغَّل الخطوات في GitHub Actions (`.github/workflows/build-company-app.yml`) باسم الشركة وشعارها ومعرّفها وقيم Firebase، ويُرفق بالتشغيل ملف **APK** للتجربة على الجوال وملف **AAB** للرفع على Google Play. يمكن تشغيلها يدوياً أيضاً من تبويب Actions ← Build company app ← Run workflow.

مرة واحدة: أضف في إعدادات المستودع (Settings ← Secrets and variables ← Actions) مفتاح التوقيع: `ANDROID_KEYSTORE_BASE64` (ناتج `base64 -w0 upload.jks`) و`ANDROID_KEYSTORE_PASSWORD` و`ANDROID_KEY_ALIAS` و`ANDROID_KEY_PASSWORD`. بدونها تُوقّع النسخة بمفتاح التطوير، وتصلح للتجربة فقط. نسخة iOS ما زالت تُبنى على جهاز Mac.

## التوقيع والنشر

- Android: أنشئ مفتاحاً (`keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`) وضع `android/key.properties`:
  ```
  storePassword=...
  keyPassword=...
  keyAlias=upload
  storeFile=/path/to/upload.jks
  ```
  الملف والمفتاح مستثنيان من git. بدونه يُوقّع الإصدار بمفتاح التطوير، وهذا لا يصلح للمتجر.
- قبل النشر: رقم الإصدار في `pubspec.yaml`، وسياسة الخصوصية (التطبيق يجمع الاسم والهوية والرخصة والجوال)، ولقطات الشاشة.

## التطوير

```bash
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 --dart-define=COMPANY_ID=1
flutter analyze
flutter test
```

الاختبارات (`test/`) تغطي التنسيق والتحقق من المدخلات والنماذج، وتشغّل التطبيق كاملاً على API وهمي: الدخول برمز خاطئ ثم صحيح، والحجز بإضافة ورمز خصم مرفوض ثم مقبول، والإلغاء، وتسجيل رقم جديد.
