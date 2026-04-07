
void main() async {
  print('--- Registering Store "landan" ---');
  
  // Note: This script assumes you have firebase setup in your terminal environment
  // or it can be run within a Flutter context if needed.
  // For simplicity, we provide the model data.
  
  final landan = {
    'id': 'landan',
    'name': 'مكتبة لندن للطباعة و النشر',
    'description': 'متجر لندن للطباعة والنشر - كل ما تحتاجه من كتب وقرطاسية',
    'adminIds': [], // Add admin UIDs here
    'isActive': true,
    'primaryColor': '#8B0000',
    'logoUrl': 'https://firebasestorage.googleapis.com/v0/b/your-project.appspot.com/o/logos%2Flandan_logo.png?alt=media',
    'whatsappNumber': '9647700000000',
    'location': 'London, UK / Baghdad, Iraq',
    'createdAt': DateTime.now().toIso8601String(),
    'registrationPoints': 50,
    'reviewRewardPoints': 10,
    'currencySymbol': 'IQD',
    'shippingFees': 5000.0,
    'minOrderForFreeShipping': 50000.0,
  };

  print('Data prepared: ${landan['name']}');
  print('Please ensure you run this within an environment with Firebase access.');
  print('Or manually add this document to the "tenants" collection with ID "landan"');
}
