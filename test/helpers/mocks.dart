import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockConnectivity extends Mock implements Connectivity {}

void setupConnectivityMock([
  List<ConnectivityResult> result = const [ConnectivityResult.wifi],
]) {
  final mock = MockConnectivity();
  when(
    () => mock.onConnectivityChanged,
  ).thenAnswer((_) => Stream.value(result));
  Connectivity();
}

class MockSharedPreferences extends Mock implements SharedPreferences {}

SharedPreferences createMockPrefs() {
  final mock = MockSharedPreferences();
  when(() => mock.getString(any())).thenReturn(null);
  when(() => mock.setString(any(), any())).thenAnswer((_) async => true);
  when(() => mock.setInt(any(), any())).thenAnswer((_) async => true);
  when(() => mock.setBool(any(), any())).thenAnswer((_) async => true);
  return mock;
}
