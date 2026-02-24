import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  String _appVersion = '';
  String _buildNumber = '';

  // FAQ data
  final List<_FaqItem> _faqItems = [
    _FaqItem(
      question: 'Làm sao để thêm bạn bè?',
      answer:
          'Vào tab "Danh bạ" → Tìm kiếm bạn bè theo email hoặc quét mã QR. '
          'Bạn cũng có thể chia sẻ mã QR cá nhân từ tab "Bạn" → "QR của tôi".',
    ),
    _FaqItem(
      question: 'Làm sao để tạo nhóm chat?',
      answer:
          'Trên màn hình Chat, nhấn nút "+" ở góc phải → chọn "Tạo nhóm" → '
          'chọn thành viên và đặt tên nhóm. Bạn cũng có thể mời thêm bạn bằng link hoặc QR.',
    ),
    _FaqItem(
      question: 'Cuộc gọi video/audio hoạt động như nào?',
      answer:
          'Mở cuộc trò chuyện với bạn bè → nhấn biểu tượng 📞 (audio) hoặc 📹 (video) '
          'ở góc phải trên AppBar. Cuộc gọi sử dụng công nghệ Agora RTC cho chất lượng tốt nhất.',
    ),
    _FaqItem(
      question: 'Tin nhắn có được mã hóa không?',
      answer:
          'Hiện tại tin nhắn được truyền qua kết nối bảo mật (WSS/HTTPS). '
          'Mã hóa đầu cuối (E2E) đang được phát triển cho phiên bản tiếp theo.',
    ),
    _FaqItem(
      question: 'Làm sao để đổi ảnh đại diện?',
      answer:
          'Vào tab "Bạn" → nhấn vào biểu tượng camera ở góc ảnh đại diện → '
          'chọn ảnh từ thư viện. Ảnh sẽ được cập nhật ngay lập tức.',
    ),
    _FaqItem(
      question: 'Tại sao tôi không nhận được thông báo?',
      answer:
          'Kiểm tra:\n'
          '1. Cài đặt thông báo của ứng dụng trong Settings điện thoại\n'
          '2. Đảm bảo ứng dụng không bị tắt chạy nền\n'
          '3. Kiểm tra kết nối internet\n'
          '4. Thử đăng xuất và đăng nhập lại',
    ),
    _FaqItem(
      question: 'Làm sao để rời khỏi nhóm?',
      answer:
          'Mở nhóm chat → nhấn vào tên nhóm trên AppBar → cuộn xuống → nhấn "Rời nhóm". '
          'Nếu bạn là admin, bạn cần chuyển quyền admin trước hoặc giải tán nhóm.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
  }

  Future<void> _loadAppInfo() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
    } catch (e) {
      setState(() {
        _appVersion = '1.0.0';
        _buildNumber = '1';
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở liên kết')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  Future<void> _sendSupportEmail() async {
    final uri = Uri(
      scheme: 'mailto',
      path: 'support@appchat.vn',
      queryParameters: {
        'subject': 'Hỗ trợ MChat v$_appVersion',
        'body':
            'Mô tả vấn đề của bạn tại đây...\n\n---\nPhiên bản: $_appVersion+$_buildNumber',
      },
    );
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        // Copy email to clipboard instead
        if (mounted) {
          Clipboard.setData(const ClipboardData(text: 'support@appchat.vn'));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đã sao chép email hỗ trợ: support@appchat.vn'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Clipboard.setData(const ClipboardData(text: 'support@appchat.vn'));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã sao chép email hỗ trợ: support@appchat.vn'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trợ giúp & Hỗ trợ'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    AppColors.accent.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      color: AppColors.primary,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'MChat',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phiên bản $_appVersion (Build $_buildNumber)',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Ứng dụng nhắn tin & gọi điện bảo mật',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FAQ Section
            _buildSectionHeader('CÂU HỎI THƯỜNG GẶP'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: ExpansionPanelList.radio(
                  elevation: 0,
                  expansionCallback: (int index, bool isExpanded) {},
                  children: _faqItems.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return ExpansionPanelRadio(
                      value: index,
                      backgroundColor: AppColors.surface,
                      canTapOnHeader: true,
                      headerBuilder: (BuildContext context, bool isExpanded) {
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            isExpanded
                                ? Icons.remove_circle_outline
                                : Icons.add_circle_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          title: Text(
                            item.question,
                            style: TextStyle(
                              color: isExpanded
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                      body: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.answer,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Contact Support Section
            _buildSectionHeader('LIÊN HỆ HỖ TRỢ'),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.email_outlined,
                iconColor: AppColors.primary,
                title: 'Email hỗ trợ',
                subtitle: 'support@appchat.vn',
                onTap: _sendSupportEmail,
              ),
              _buildCardDivider(),
              _buildActionTile(
                icon: Icons.bug_report_outlined,
                iconColor: AppColors.warning,
                title: 'Báo lỗi',
                subtitle: 'Gửi báo cáo lỗi cho đội ngũ phát triển',
                onTap: _sendSupportEmail,
              ),
            ]),

            const SizedBox(height: 24),

            // Legal Section
            _buildSectionHeader('PHÁP LÝ'),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.description_outlined,
                title: 'Điều khoản sử dụng',
                subtitle: 'Xem điều khoản và điều kiện',
                onTap: () => _launchUrl('https://appchat.vn/terms'),
              ),
              _buildCardDivider(),
              _buildActionTile(
                icon: Icons.security_outlined,
                title: 'Chính sách bảo mật',
                subtitle: 'Xem chính sách bảo mật dữ liệu',
                onTap: () => _launchUrl('https://appchat.vn/privacy'),
              ),
              _buildCardDivider(),
              _buildActionTile(
                icon: Icons.open_in_new,
                title: 'Giấy phép mã nguồn mở',
                subtitle: 'Xem các giấy phép thư viện sử dụng',
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'MChat',
                    applicationVersion: 'v$_appVersion',
                    applicationLegalese: '© 2026 MChat Team',
                  );
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Rate & Share
            _buildSectionHeader('ĐÁNH GIÁ'),
            const SizedBox(height: 8),
            _buildSettingsCard([
              _buildActionTile(
                icon: Icons.star_outline,
                iconColor: AppColors.warning,
                title: 'Đánh giá ứng dụng',
                subtitle: 'Để lại đánh giá trên App Store / Play Store',
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Tính năng sẽ có khi ứng dụng lên App Store',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
              _buildCardDivider(),
              _buildActionTile(
                icon: Icons.share_outlined,
                iconColor: AppColors.primary,
                title: 'Giới thiệu cho bạn bè',
                subtitle: 'Chia sẻ MChat với bạn bè của bạn',
                onTap: () {
                  Clipboard.setData(
                    const ClipboardData(
                      text:
                          'Tải MChat - Ứng dụng nhắn tin bảo mật! https://appchat.vn',
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Đã sao chép link giới thiệu'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
              ),
            ]),

            const SizedBox(height: 32),

            // Footer
            Center(
              child: Column(
                children: [
                  const Text(
                    'Made with ❤️ in Vietnam',
                    style: TextStyle(
                      color: AppColors.textTertiary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '© 2026 MChat Team • v$_appVersion',
                    style: const TextStyle(
                      color: AppColors.textPlaceholder,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---- UI Helpers ----

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildCardDivider() {
    return const Padding(
      padding: EdgeInsets.only(left: 52),
      child: Divider(height: 1, color: AppColors.divider),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    Color? iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textPlaceholder,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem {
  final String question;
  final String answer;

  _FaqItem({required this.question, required this.answer});
}
