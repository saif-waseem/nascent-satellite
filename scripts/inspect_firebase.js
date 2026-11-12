const https = require('https');
const fs = require('fs');
const path = require('path');
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
  // doc.name is "projects/.../documents/col/id"
  const parts = doc.name.split('/');
  obj.id = parts[parts.length - 1];
  return obj;
}

async function run() {
  console.log('🚀 بدء فحص بيانات Firebase...');
  
  const collections = ['tenants', 'categories', 'products', 'customers', 'sales_invoices', 'orders'];
  const summary = {};

  for (const col of collections) {
    try {
      const docs = await fetchFirestore(col);
      summary[col] = docs.length;
      console.log(`📦 مجموعة [${col}]: تم جلب ${docs.length} مستند`);
      if (docs.length > 0) {
        const sample = docToObj(docs[0]);
        console.log(`   عينة من [${col}]: id=${sample.id}, keys=${Object.keys(sample).slice(0, 6).join(', ')}`);
      }
    } catch (e) {
      console.log(`⚠️ فشل جلب [${col}]: ${e.message}`);
    }
  }

  console.log('\n📊 ملخص المستندات الجاهزة للنقل:', summary);
}

run();
