import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nl_flutter/screens/auth/welcome_screen.dart';

void main() {
  Widget createTestWidget() {
    return const MaterialApp(
      home: WelcomeScreen(),
    );
  }

  testWidgets('WelcomeScreen renders all Art Deco elements and controls', (WidgetTester tester) async {
    // Render the welcome screen
    await tester.pumpWidget(createTestWidget());

    // Verify presence of "01 · THE ENTRY" eyebrow line
    expect(find.text('01 · THE ENTRY'), findsOneWidget);

    // Verify presence of Hero typography parts
    expect(find.textContaining('After dark,'), findsOneWidget);
    expect(find.textContaining('by invitation.'), findsOneWidget);

    // Verify presence of Enter Your Code input label
    expect(find.text('ENTER YOUR CODE'), findsOneWidget);

    // Verify presence of the code input text field
    expect(find.byType(TextField), findsOneWidget);

    // Verify presence of the Primary Action button
    expect(find.text('CLAIM INVITATION'), findsOneWidget);

    // Verify presence of the Secondary Action ghost button
    expect(find.text('EXISTING MEMBER LOGIN'), findsOneWidget);
  });

  testWidgets('Claiming invitation with empty code displays warning snackbar', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    // Tap the CLAIM INVITATION button with an empty input field
    await tester.tap(find.text('CLAIM INVITATION'));
    await tester.pumpAndSettle();

    // Verify the warning SnackBar is presented
    expect(find.text('PLEASE ENTER A VALID INVITATION CODE'), findsOneWidget);
  });

  testWidgets('Claiming invitation with non-empty code functions correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget());

    // Enter a valid invite code
    await tester.enterText(find.byType(TextField), 'VIPCODE2026');
    await tester.pump();

    // Tap the CLAIM INVITATION button
    await tester.tap(find.text('CLAIM INVITATION'));
    await tester.pump(); // Start navigation/snackbar display

    // Verify acceptance SnackBar is presented
    expect(find.text('INVITATION CODE ACCEPTED. WELCOME TO THE ENTRY.'), findsOneWidget);
  });
}
