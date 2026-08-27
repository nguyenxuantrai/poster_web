import 'package:flutter_test/flutter_test.dart';
import 'package:poster_app/main.dart';

void main() {
  testWidgets('Test khoi tao PosterApp', (WidgetTester tester) async {
    // Sua MyApp() thanh PosterApp()
    await tester.pumpWidget(const PosterApp());
  });
}