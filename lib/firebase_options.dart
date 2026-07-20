import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBifs9LZ866EZKnTU6bAQuyf69phNu1AkE',
    appId: '1:10654240804:android:6df92da096c9674c7ec8b1',
    messagingSenderId: '10654240804',
    projectId: 'multi-agent-a145f',
    storageBucket: 'multi-agent-a145f.firebasestorage.app',
  );
}
