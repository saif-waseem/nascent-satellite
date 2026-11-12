import { createClient } from '@/utils/supabase/server';
import { cookies } from 'next/headers';

export default async function Page() {
  const cookieStore = await cookies();
  const supabase = createClient(cookieStore);

  const { data: products } = await supabase.from('products').select();

  return (
    <div style={{ padding: '2rem', fontFamily: 'sans-serif', direction: 'rtl' }}>
      <h1>قائمة المنتجات (Supabase SQL)</h1>
      <ul>
        {products?.map((product: any) => (
          <li key={product.id}>
            <strong>{product.name}</strong> - {product.price} IQD
          </li>
        ))}
      </ul>
    </div>
  );
}
