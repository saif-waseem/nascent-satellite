const https = require('https');

const FIREBASE_PROJECT = 'my-store-b0723';

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

async function run() {
  const docs = await fetchFirestore('products');
  console.log(`فحص روابط الصور في ${docs.length} منتج:`);
  
  let firebaseStorageCount = 0;
  let otherUrls = 0;
  let emptyImages = 0;
  const sampleUrls = [];

  for (const d of docs) {
    const p = docToObj(d);
    const imgs = p.images || [];
    if (imgs.length === 0) {
      emptyImages++;
    } else {
      imgs.forEach(url => {
        if (typeof url === 'string') {
          if (url.includes('firebasestorage.googleapis.com') || url.includes('appspot.com')) {
            firebaseStorageCount++;
            if (sampleUrls.length < 5) sampleUrls.push(url);
          } else {
            otherUrls++;
            if (sampleUrls.length < 5) sampleUrls.push(url);
          }
        }
      });
    }
  }

  console.log(`- روابط Firebase Storage (المحظورة في العراق): ${firebaseStorageCount}`);
  console.log(`- روابط خارجية أخرى (مثل ibb.co): ${otherUrls}`);
  console.log(`- منتجات بدون صور: ${emptyImages}`);
  console.log('عينات من الروابط:', sampleUrls);
}

run();
