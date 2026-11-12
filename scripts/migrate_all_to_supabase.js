const https = require('https');
const { createClient } = require('D:/my project/web_nextjs/node_modules/@supabase/supabase-js');

const SUPABASE_URL = 'https://axcdhxubqzbzjpbhyvvf.supabase.co';
const SUPABASE_KEY = 'sb_publishable_wVnAoc2K3TewY6Wpb0-D4Q_fX94VBMH';
const FIREBASE_PROJECT = 'my-store-b0723';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

function fetchFirestore(collectionName) {
  return new Promise((resolve, reject) => {
    const url = `https://firestore.googleapis.com/v1/projects/${FIREBASE_PROJECT}/databases/(default)/documents/${collectionName}?pageSize=100`;
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve(json.documents || []);
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

function parseFirestoreField(field) {
  if (!field) return null;
  if ('stringValue' in field) return field.stringValue;
  if ('integerValue' in field) return parseInt(field.integerValue, 10);
  if ('doubleValue' in field) return parseFloat(field.doubleValue);
  if ('booleanValue' in field) return field.booleanValue;
  if ('nullValue' in field) return null;
  if ('timestampValue' in field) return field.timestampValue;
  if ('arrayValue' in field) {
    const arr = field.arrayValue.values || [];
    return arr.map(parseFirestoreField);
  }
  if ('mapValue' in field) {
    const map = field.mapValue.fields || {};
    const res = {};
    for (const k in map) {
      res[k] = parseFirestoreField(map[k]);
    }
    return res;
  }
  return null;
}

function docToObj(doc) {
  const fields = doc.fields || {};
  const obj = {};
  for (const k in fields) {
    obj[k] = parseFirestoreField(fields[k]);
  }
  const parts = doc.name.split('/');
  obj.id = parts[parts.length - 1];
  return obj;
}

async function migrateTenants() {
  console.log('\n--- 1. نقل المستأجرين (Tenants) ---');
  const docs = await fetchFirestore('tenants');
  console.log(`تم العثور على ${docs.length} مستأجر`);

  for (const doc of docs) {
    const t = docToObj(doc);
    const row = {
      id: t.id,
      name: t.name || 'متجر',
      description: t.description || '',
      whatsapp_number: t.whatsappNumber || '',
      primary_color: t.primaryColor || '#000000',
      is_active: t.isActive !== undefined ? t.isActive : true,
      expiry_date: t.expiryDate || null,
      is_store_enabled: t.isStoreEnabled !== undefined ? t.isStoreEnabled : true,
      is_pos_enabled: t.isPosEnabled !== undefined ? t.isPosEnabled : true,
      pos_tier: t.posTier || 'A',
      pos_device_limit: t.posDeviceLimit || 1,
      currency_unit: t.currencyUnit || 'IQD',
      shipping_cost: t.shippingCost || 5000,
    };

    const { error } = await supabase.from('tenants').upsert(row);
    if (error) {
      console.error(`❌ خطأ عند رفع المستأجر [${t.id}]:`, error.message);
    } else {
      console.log(`✅ تم نقل المستأجر: ${t.name} (${t.id})`);
    }
  }
}

async function migrateCategories() {
  console.log('\n--- 2. نقل الأقسام (Categories) ---');
  const docs = await fetchFirestore('categories');
  console.log(`تم العثور على ${docs.length} قسم`);

  for (const doc of docs) {
    const c = docToObj(doc);
    const row = {
      id: c.id,
      tenant_id: c.tenantId || 'anegmadenty',
      name: c.name || 'عام',
      icon: c.icon || '',
    };

    const { error } = await supabase.from('categories').upsert(row);
    if (error) {
      console.error(`❌ خطأ عند رفع القسم [${c.name}]:`, error.message);
    } else {
      console.log(`✅ تم نقل القسم: ${c.name}`);
    }
  }
}

async function migrateProducts() {
  console.log('\n--- 3. نقل المنتجات (Products) ---');
  const docs = await fetchFirestore('products');
  console.log(`تم العثور على ${docs.length} منتج`);

  for (const doc of docs) {
    const p = docToObj(doc);
    const row = {
      id: p.id,
      tenant_id: p.tenantId || 'anegmadenty',
      name: p.name || 'منتج',
      category: p.category || 'عام',
      description: p.description || '',
      price: p.price || 0,
      old_price: p.oldPrice || null,
      purchase_price: p.purchasePrice || 0,
      wholesale_price: p.wholesalePrice || 0,
      stock_quantity: p.stockQuantity || 0,
      min_stock_level: p.minStockLevel || 5,
      unit: p.unit || 'قطعة',
      barcode: p.barcode || null,
      images: p.images || [],
      video_url: p.videoUrl || null,
      rating: p.rating || 5.0,
      sales_count: p.salesCount || 0,
      in_stock: p.inStock !== undefined ? p.inStock : true,
      is_offer: p.isOffer || false,
      is_featured_deal: p.isFeaturedDeal || false,
      is_daily_starred: p.isDailyStarred || false,
      colors: p.colors || [],
      sizes: p.sizes || [],
      variants: p.variants || [],
      storage_locations: p.storageLocations || [],
    };

    const { error } = await supabase.from('products').upsert(row);
    if (error) {
      console.error(`❌ خطأ عند رفع المنتج [${p.name}]:`, error.message);
    } else {
      console.log(`✅ تم نقل المنتج: ${p.name} (السعر: ${p.price})`);
    }
  }
}

async function main() {
  console.log('🚀 بدء الترحيل الشامل من Firebase إلى Supabase SQL...');
  try {
    await migrateTenants();
    await migrateCategories();
    await migrateProducts();
    console.log('\n🎉 اكتمل الترحيل بنجاح!');
  } catch (e) {
    console.error('❌ حدث خطأ غير متوقع:', e);
  }
}

main();
