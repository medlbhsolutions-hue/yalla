import 'package:supabase_flutter/supabase_flutter.dart';

const String mockSupabaseUrl = 'https://mock.supabase.co';
const String mockSupabaseKey = 'mock-key';

class MockSupabaseClient extends SupabaseClient {
  final _mockGoTrueClient = _MockGoTrueClient();
  
  MockSupabaseClient() : super(mockSupabaseUrl, mockSupabaseKey);

  @override
  GoTrueClient get auth => _mockGoTrueClient;
}

class _MockGoTrueClient extends GoTrueClient {
  User? _currentUser;
  Session? _currentSession;

  _MockGoTrueClient() : super(url: mockSupabaseUrl, headers: {});

  @override
  Future<AuthResponse> signUp({
    String? email,
    String? phone,
    String? password,
    Map<String, dynamic>? data,
    Map<String, String>? options,
    String? captchaToken,
    OtpChannel? channel,
    String? emailRedirectTo,
  }) async {
    if ((email == 'test_patient@example.com' && password == 'Test123!') ||
        (email == 'test_driver@example.com' && password == 'Driver123!')) {
      final userId = email == 'test_patient@example.com' ? 'test-patient-id' : 'test-driver-id';
      final user = User(
        id: userId,
        email: email,
        phone: phone,
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
        appMetadata: data ?? {},
        userMetadata: {},
        aud: 'authenticated',
      );
      final session = Session(
        accessToken: 'mock-access-token',
        refreshToken: 'mock-refresh-token',
        tokenType: 'bearer',
        expiresIn: 3600,
        user: user,
      );
      _currentUser = user;
      _currentSession = session;
      return AuthResponse(user: user, session: session);
    } else {
      throw AuthException('Invalid email or password');
    }
  }

  @override
  Future<AuthResponse> signInWithPassword({
    String? email,
    String? phone,
    String? password,
    String? captchaToken,
  }) async {
    if ((email == 'test_patient@example.com' && password == 'Test123!') ||
        (email == 'test_driver@example.com' && password == 'Driver123!')) {
      return await signUp(email: email, password: password);
    } else {
      throw AuthException('Invalid email or password');
    }
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Session? get currentSession => _currentSession;

  @override
  Future<void> signOut({SignOutScope? scope}) async {
    _currentUser = null;
    _currentSession = null;
  }
}
