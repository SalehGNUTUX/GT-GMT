# GT-GMT — GNU Boot Manager Tool

**GT-GMT** هو أداة رسومية وتفاعلية لإدارة محمّلات الإقلاع في أنظمة GNU/Linux  
يدعم **GRUB** و **systemd-boot** و **rEFInd**، مع واجهة مبسطة تعمل في الطرفية أو عبر نافذة تفاعلية.

---

## ⚙️ المزايا

- 🧠 كشف تلقائي لنوع محمل الإقلاع المستخدم.  
- 🪄 أدوات تهيئة وصيانة GRUB و systemd-boot و rEFInd.  
- 🌐 متوفر حاليا باللغة العربية فقط.  
- 🧰 نسخ جاهزة للتثبيت أو التشغيل المستقل (AppImage).  
- 🧼 دعم الإزالة الكاملة لجميع الملفات المثبتة.

---

## 📦 طرق التثبيت

### 🌀 1. التثبيت المباشر من المستودع (الطريقة الموصى بها)

يمكنك تثبيت البرنامج مباشرة باستخدام المثبت الرسمي:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-GMT/main/GT-GMT/install.sh)
````

بعد اكتمال التثبيت يمكنك تشغيل الأداة بالأمر:

```bash
gt-gmt
```

> ⚠️ سيتطلب التثبيت صلاحيات المدير في مرحلة النسخ إلى النظام.

---

### 🧭 2. التثبيت اليدوي (من المجلد المحلي)

1. نزّل المجلد **GT-GMT** من المستودع:

   ```bash
   git clone https://github.com/SalehGNUTUX/GT-GMT.git
   cd GT-GMT/GT-GMT
   ```

2. اجعل ملف التثبيت قابلًا للتنفيذ وشغّله:

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. بعد التثبيت، شغّل البرنامج بالأمر:

   ```bash
   gt-gmt
   ```

> لإلغاء التثبيت استخدم الأداة المرفقة:
>
> ```bash
> chmod +x uninstall.sh
> ./uninstall.sh
> ```

---

### 🧱 3. استخدام نسخة AppImage

> الإصدار الأحدث متاح هنا:
> 🔗 [GT-GMT AppImage Release](https://github.com/SalehGNUTUX/GT-GMT/releases/tag/GT-GMT_Boot_Manager)

#### 🔹 التشغيل اليدوي

1. نزّل ملف `.AppImage` إلى أي مكان.
2. اجعله قابلًا للتنفيذ:

   ```bash
   chmod +x GT-GMT-x86_64.AppImage
   ```
3. ثم شغّله مباشرة:

   ```bash
   ./GT-GMT-x86_64.AppImage
   ```

> يمكنك أيضًا تشغيله بصلاحيات الجذر عند الحاجة:
>
> ```bash
> sudo ./GT-GMT-x86_64.AppImage
> ```

#### 🔹 التشغيل عبر GearLever (AppImage Launcher)

إذا كان لديك تطبيق **GearLever** أو **AppImage Launcher**:

* انقر بالزر الأيمن على الملف ثم اختر **“Integrate and Run”**
* سيُضاف البرنامج إلى القائمة ويصبح متاحًا ضمن التطبيقات الرسومية.

---

## 🧹 إلغاء التثبيت

لإزالة النسخة المثبتة من النظام:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/SalehGNUTUX/GT-GMT/main/GT-GMT/uninstall.sh)
```

أو من المجلد المحلي:

```bash
./uninstall.sh
```

---

## 🧾 معلومات إضافية

* 📂 **مسار التثبيت الافتراضي:** `$HOME/.local/share/gt-gmt/`
* 🧱 **الترخيص:** GNU GPL v3 or later
* 👤 **المطوّر:** [Saleh GNUTUX](https://github.com/SalehGNUTUX)
* 💬 **المصدر:** [GT-GMT on GitHub](https://github.com/SalehGNUTUX/GT-GMT)

---

## 🖥️ مثال لقطة شاشة

*(يمكنك إضافة صورة هنا لاحقًا)*

```
GT-GMT by gnutux — Unified Boot Manager for GNU/Linux
```

---

### 💡 نصائح

* لتحديث النسخة المثبتة يدويًا، أعد تشغيل أمر التثبيت نفسه — سيكتشف المثبت وجود نسخة سابقة ويحدثها.
* في بيئة GNOME قد تظهر نافذة مصادقة (pkexec) بدل طلب كلمة المرور في الطرفية — كلاهما طبيعي.
* تأكد من وجود **bash** و **sudo** و **zenity** أو **kdialog** في النظام لضمان التكامل الكامل.

---

🚀 **استمتع بإدارة محمل الإقلاع بسهولة مع GT-GMT !**
