package com.ezyventas.app

import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity (y no FlutterActivity) es lo que exige `local_auth`
// para lanzar BiometricPrompt desde la pantalla de inicio de sesion.
class MainActivity : FlutterFragmentActivity()
