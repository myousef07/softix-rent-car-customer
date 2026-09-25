# SOftiX Rent Car — تطبيق العملاء (قيد التطوير)

تطبيق Flutter للمستأجرين، يتصل بواجهة `/api/v1/customer` في مشروع [`rental-car`](https://github.com/myousef07/rental-car) (موثقة في `docs/api.md`).

## الحالة

- جاهز: طبقة الاتصال بالـ API، الجلسة (الدخول برمز SMS والتسجيل)، نماذج البيانات، فتح ملفات PDF وصفحة الدفع، الثيم والخط.
- لم يُكتب بعد: الشاشات (الدخول، البحث والحجز، حجوزاتي، عقودي والدفع، الفواتير، الحساب). `lib/main.dart` ما زال قالب Flutter الافتراضي.

## الإعداد

كل شركة تأجير تبني نسختها:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 --dart-define=COMPANY_ID=1 --dart-define=COMPANY_NAME="اسم الشركة"
```
