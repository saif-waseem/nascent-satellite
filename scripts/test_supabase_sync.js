const { createClient } = require('D:/my project/web_nextjs/node_modules/@supabase/supabase-js');

const SUPABASE_URL = 'https://axcdhxubqzbzjpbhyvvf.supabase.co';
const SUPABASE_KEY = 'sb_publishable_wVnAoc2K3TewY6Wpb0-D4Q_fX94VBMH';

const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

async function testQuery() {
  console.log('🔍 اختبار القراءة السريعة من Supabase SQL...');
  const { data: products, error: pErr } = await supabase.from('products').select('id, name, price, stock_quantity, storage_locations').limit(3);
  if (pErr) {
    console.error('❌ خطأ استعلام المنتجات:', pErr.message);
  } else {
    console.log(`✅ تم جلب ${products.length} منتجات بنجاح من Supabase SQL:`);
    products.forEach(p => console.log(`   - [${p.name}] السعر: ${p.price} | الكمية: ${p.stock_quantity} | مواقع المخزن: ${JSON.stringify(p.storage_locations)}`));
  }

  const { data: categories, error: cErr } = await supabase.from('categories').select('id, name').limit(3);
  if (cErr) {
    console.error('❌ خطأ استعلام الأقسام:', cErr.message);
  } else {
    console.log(`✅ تم جلب ${categories.length} أقسام بنجاح من Supabase SQL:`);
    categories.forEach(c => console.log(`   - قسم: ${c.name}`));
  }
}

testQuery();
