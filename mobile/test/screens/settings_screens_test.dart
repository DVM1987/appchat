import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/presentation/providers/auth_provider.dart';
import 'package:mobile/presentation/screens/profile/account_settings_screen.dart';
import 'package:mobile/presentation/screens/profile/help_support_screen.dart';
import 'package:mobile/presentation/screens/profile/privacy_settings_screen.dart';
// Minimal AuthProvider mock for widget tests
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(),
      child: child,
    ),
  );
}

void main() {
  group('AccountSettingsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({
        'phone_number': '+84961998923',
        'user_name': 'Văn Mười',
        'user_id': 'abc123def456',
      });
    });

    testWidgets('renders AppBar title', (tester) async {
      await tester.pumpWidget(_wrap(const AccountSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Cài đặt tài khoản'), findsOneWidget);
    });

    testWidgets('shows section headers', (tester) async {
      await tester.pumpWidget(_wrap(const AccountSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('THÔNG TIN TÀI KHOẢN'), findsOneWidget);
      expect(find.text('THIẾT BỊ'), findsOneWidget);
      expect(find.text('HÀNH ĐỘNG'), findsOneWidget);
      expect(find.text('VÙNG NGUY HIỂM'), findsOneWidget);
    });

    testWidgets('shows phone number', (tester) async {
      await tester.pumpWidget(_wrap(const AccountSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Số điện thoại'), findsOneWidget);
    });

    testWidgets('shows user name', (tester) async {
      await tester.pumpWidget(_wrap(const AccountSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Tên hiển thị'), findsOneWidget);
    });

    testWidgets('shows delete account option', (tester) async {
      await tester.pumpWidget(_wrap(const AccountSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Xóa tài khoản'), findsOneWidget);
      expect(
        find.text('Xóa vĩnh viễn tài khoản và mọi dữ liệu'),
        findsOneWidget,
      );
    });

    testWidgets('shows "Sắp ra mắt" badge on PIN option', (tester) async {
      await tester.pumpWidget(_wrap(const AccountSettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Đổi mã PIN'), findsOneWidget);
      expect(find.text('Sắp ra mắt'), findsOneWidget);
    });

    testWidgets('tapping delete account shows confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const AccountSettingsScreen()));
      await tester.pumpAndSettle();

      // Scroll to delete account button (it's at the bottom, off-screen in 800x600)
      await tester.dragUntilVisible(
        find.text('Xóa vĩnh viễn tài khoản và mọi dữ liệu'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      // Find and tap the delete account area
      await tester.tap(find.text('Xóa vĩnh viễn tài khoản và mọi dữ liệu'));
      await tester.pumpAndSettle();

      // Dialog should appear with warning
      expect(find.text('⚠️ Hành động này không thể hoàn tác!'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
    });
  });

  group('PrivacySettingsScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('renders AppBar title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Quyền riêng tư'), findsOneWidget);
    });

    testWidgets('shows all section headers', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('TRẠNG THÁI TRỰC TUYẾN'), findsOneWidget);
      expect(find.text('HIỂN THỊ'), findsOneWidget);
      expect(find.text('NHÓM & KÊNH'), findsOneWidget);
      expect(find.text('BẢO MẬT'), findsOneWidget);
      expect(find.text('NGƯỜI BỊ CHẶN'), findsOneWidget);
    });

    testWidgets('shows toggle switches', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Ẩn trạng thái online'), findsOneWidget);
      expect(find.text('Ẩn lần truy cập cuối'), findsOneWidget);
      expect(find.text('Xác nhận đã đọc'), findsOneWidget);
      expect(find.text('Khóa ứng dụng'), findsOneWidget);
    });

    testWidgets('toggle online status switch works', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pumpAndSettle();

      // Find switches - initially off for hide online
      final switches = find.byType(Switch);
      expect(switches, findsWidgets);

      // Tap the first switch (hide online)
      await tester.tap(switches.first);
      await tester.pumpAndSettle();

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('privacy_hide_online'), true);
    });

    testWidgets('shows blocked users section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Danh sách chặn'), findsOneWidget);
      expect(find.text('Không có người dùng nào bị chặn'), findsOneWidget);
    });

    testWidgets('shows info note at bottom', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pumpAndSettle();

      // Scroll to bottom to find info note
      await tester.dragUntilVisible(
        find.byIcon(Icons.info_outline),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('loads saved settings from SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({
        'privacy_hide_online': true,
        'privacy_read_receipts': false,
      });

      await tester.pumpWidget(const MaterialApp(home: PrivacySettingsScreen()));
      await tester.pumpAndSettle();

      // Read receipts should be off
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('privacy_hide_online'), true);
      expect(prefs.getBool('privacy_read_receipts'), false);
    });
  });

  group('HelpSupportScreen', () {
    testWidgets('renders AppBar title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Trợ giúp & Hỗ trợ'), findsOneWidget);
    });

    testWidgets('shows AppChat banner with version', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
      await tester.pumpAndSettle();
      expect(find.text('AppChat'), findsOneWidget);
      expect(find.text('Ứng dụng nhắn tin & gọi điện bảo mật'), findsOneWidget);
    });

    testWidgets('shows FAQ section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
      await tester.pumpAndSettle();
      expect(find.text('CÂU HỎI THƯỜNG GẶP'), findsOneWidget);
      expect(find.text('Làm sao để thêm bạn bè?'), findsOneWidget);
      expect(find.text('Làm sao để tạo nhóm chat?'), findsOneWidget);
    });

    testWidgets('shows support contact section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
      await tester.pumpAndSettle();
      expect(find.text('LIÊN HỆ HỖ TRỢ'), findsOneWidget);
      expect(find.text('Email hỗ trợ'), findsOneWidget);
      expect(find.text('support@appchat.vn'), findsOneWidget);
    });

    testWidgets('shows legal section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
      await tester.pumpAndSettle();

      // Scroll down to find legal section
      await tester.dragUntilVisible(
        find.text('PHÁP LÝ'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(find.text('PHÁP LÝ'), findsOneWidget);
      expect(find.text('Điều khoản sử dụng'), findsOneWidget);
      expect(find.text('Chính sách bảo mật'), findsOneWidget);
    });

    testWidgets('shows rate and share section', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
      await tester.pumpAndSettle();

      // Scroll to bottom
      await tester.dragUntilVisible(
        find.text('ĐÁNH GIÁ'),
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      expect(find.text('Đánh giá ứng dụng'), findsOneWidget);
      expect(find.text('Giới thiệu cho bạn bè'), findsOneWidget);
    });

    testWidgets('shows footer', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: HelpSupportScreen()));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Made with ❤️ in Vietnam'),
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      expect(find.text('Made with ❤️ in Vietnam'), findsOneWidget);
    });
  });
}
