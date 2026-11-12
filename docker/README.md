# دليل تشغيل منظومة الحاويات (Docker & Docker Compose Guide)

تم إعداد ملفات Docker بنظام **البناء متعدد المراحل (Multi-stage Build)** لتقليل حجم الحاويات لأصغر حد ممكن مع خادم **Nginx Alpine** فائق السرعة لتقديم صفحات الويب والأصول الثابتة.

---

## 1. الخدمات والمنافذ (Services & Ports)

| الخدمة | الحاوية | المنفذ الخارجي | الوصف |
| :--- | :--- | :--- | :--- |
| **Super Admin** | `saas_super_admin` | `http://localhost:8090` | لوحة السوبر أدمن لإدارة التيرات والاشتراكات والمستأجرين |
| **Store Admin** | `saas_store_admin` | `http://localhost:8091` | لوحة تحكم التاجر (المنتجات، الفيديوهات، الإكسل) |
| **User Storefront** | `saas_user_storefront` | `http://localhost:8092` | متجر الويب للزبائن (عرض المنتجات والفيديوهات أولاً) |
| **Next.js Portal** | `saas_nextjs_portal` | `http://localhost:3000` | بوابة الويب السريعة بتقنية SSR ومربوطة بـ Supabase |

---

## 2. أوامر التشغيل (Commands)

### تشغيل كافة الخدمات دفعة واحدة في الخلفية:
```bash
docker compose up -d --build
```

### إيقاف كافة الخدمات:
```bash
docker compose down
```

### عرض حالة الحاويات النشطة:
```bash
docker compose ps
```

### مشاهدة السجلات وسجلات التشغيل:
```bash
docker compose logs -f
```

---

## 3. ملفات الإعداد المهيأة:
1. `D:\my project\docker-compose.yml` — إدارة وتشغيل المنظومة بالكامل
2. `D:\my project\docker\nginx.conf` — إعدادات Nginx المتقدمة مع ضغط Gzip وحماية Headers
3. `D:\my project\st\Dockerfile` — حاوية أدمن المتجر
4. `D:\my project\ecommerce_saas\apps\super_admin\Dockerfile` — حاوية السوبر أدمن
5. `D:\my project\ua\Dockerfile` — حاوية متجر المستخدمين
6. `D:\my project\web_nextjs\Dockerfile` — حاوية تطبيق Next.js
7. `D:\my project\.dockerignore` — استبعاد الملفات المؤقتة لتسريع البناء
