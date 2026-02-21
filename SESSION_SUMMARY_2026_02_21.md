# Session Summary - 21/02/2026 (14:11 → 19:19)

## Mục tiêu
Fix các lỗi: kết bạn, đổi tên, logout, login chậm, cuộc gọi audio/video.

---

## ✅ ĐÃ FIX THÀNH CÔNG

### 1. Database & Backend
- **Drop toàn bộ bảng cũ** (`Users`, `Friendships`, `OtpEntries`) và tạo lại schema đúng EF Core convention (`UserProfiles`, `Friendships`)
- **Rename table** `Users` → `UserProfiles` để match EF Core DbContext mapping
- **Restart services**: `chat_identity`, `user_service`

### 2. Firewall VPS
- VPS chỉ mở port 22 (SSH) → **thêm UFW rules** cho port 5001-5005, 9000-9001
- App trên iPhone giờ kết nối được qua Gateway (port 5001)

### 3. Kết bạn ✅
- Friend request `/api/v1/friends/request` hoạt động qua Gateway
- Đã test thành công kết bạn giữa 2 iPhone

### 4. Chat ✅
- Chat realtime hoạt động (qua SignalR)
- Tin nhắn gửi/nhận OK

### 5. Fix Timezone (UTC → Local)
- **Vấn đề**: Backend trả timestamp UTC không có `Z` suffix → Dart parse sai timezone
- **File fix**: `mobile/lib/presentation/screens/chat/widgets/chat_message_helpers.dart`
  - `parseMessageDate()`: Thêm logic append `Z` nếu timestamp không có timezone info
- **File fix**: `mobile/lib/data/models/conversation_model.dart`  
  - `fromJson()`: Thêm `_parseUtcDateTime()` helper để parse đúng timezone cho conversation list
- **File fix**: `mobile/lib/core/utils/date_formatter.dart`
  - Đổi format từ `h:mm a` (12h AM/PM) → `HH:mm` (24h)

### 6. Fix Giao diện Cuộc gọi
- **File fix**: `mobile/lib/presentation/screens/call/call_screen.dart`
  - Thêm `crossAxisAlignment: CrossAxisAlignment.center` cho Column
  - Thêm `textAlign: TextAlign.center` cho tên và status
  - Wrap nút "Huỷ" trong `Center`
  - Thêm `width: double.infinity` cho Container controls
- UI cuộc gọi đã centered đẹp ✅

### 7. Agora App ID (Testing Mode)
- **Vấn đề**: Agora project cũ (`907e967d...`) có Primary Certificate → Secured Mode → cần token
- **Fix**: Tạo project Agora mới `appchat-test` ở **Testing Mode (APP ID only)**
- **App ID mới**: `37cc9df20f2d4cd9860e29b6b4b9517b`
- **File fix**: `mobile/lib/data/services/agora_service.dart`
  - Cập nhật App ID mới
  - Bỏ `getToken()` call (endpoint không tồn tại → timeout 60s)
  - Join channel với empty token (Testing Mode)
  - Fix `generateChannelName()` cho user ID < 8 ký tự
  - Thêm `onConnectionStateChanged` callback
  - Thêm print() debug logging
  - Fix `initialize()` handle trường hợp already initialized

### 8. ✅ FIX CUỘC GỌI AUDIO/VIDEO (Session chiều 15:41 → 19:19)

**3 root causes được xác định và fix:**

#### Root Cause 1: iOS Podfile thiếu permission macros
- **Vấn đề**: `permission_handler` package trên iOS yêu cầu khai báo `GCC_PREPROCESSOR_DEFINITIONS` trong Podfile. Nếu thiếu, **mọi quyền luôn trả về `denied`** dù có `NSMicrophoneUsageDescription` trong Info.plist
- **Triệu chứng**: Settings > Mobile KHÔNG hiện mục Microphone/Camera
- **File fix**: `mobile/ios/Podfile`
  ```ruby
  target.build_configurations.each do |config|
    config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
      '$(inherited)',
      'PERMISSION_MICROPHONE=1',
      'PERMISSION_CAMERA=1',
      'PERMISSION_PHOTOS=1',
      'PERMISSION_NOTIFICATIONS=1',
    ]
  end
  ```

#### Root Cause 2: Remote video dùng sai channelId (empty string)
- **Vấn đề**: `VideoViewController.remote()` có `channelId: AgoraService.generateChannelName('', widget.otherUserId)` → chuỗi rỗng thay vì userId thật
- **Fix**: Lưu `_channelName` vào state variable, dùng cho cả `_initAndJoinAgora()` và `AgoraVideoView.remote()`
- **File fix**: `mobile/lib/presentation/screens/call/call_screen.dart`

#### Root Cause 3: `setEnableSpeakerphone()` gọi quá sớm → AgoraRtcException(-3)
- **Vấn đề**: `setEnableSpeakerphone(false)` được gọi ngay trong `initialize()` trước khi engine sẵn sàng → crash toàn bộ Agora init flow
- **Fix**: Xóa `setEnableSpeakerphone` khỏi `initialize()`, để user toggle sau
- **File fix**: `mobile/lib/data/services/agora_service.dart`

### 9. ✅ FIX LOGOUT/RE-LOGIN DATA LOSS
- **Vấn đề**: Sau logout → login lại, `ChatProvider` và `UserProvider` giữ stale data → `ChatList` không tải data mới
- **Fix**: 
  - `auth_provider.dart`: Thêm `_logoutCallbacks` system
  - `main.dart`: `AuthChecker` register callback → `ChatProvider.clear()` + `UserProvider.clear()` khi logout
  - `chat_list.dart`: Luôn refresh conversations khi widget mount

---

## ❌ CÒN LỖI / CẦN CẢI THIỆN

### 1. Xóa debug overlay trên call screen
- Hiện tại đang hiện dòng chữ xanh lá debug ở đầu màn hình call
- Cần xóa hoặc ẩn sau khi xác nhận ổn định

### 2. Agora Token (Production)
- Hiện tại dùng **Testing Mode** (không cần token) → phù hợp development
- Khi lên production cần:
  - Bật App Certificate trên Agora Console
  - Backend có endpoint `/agora/token` trả token (đã có `getToken()` method)
  - Call screen đã có logic try backend token → fallback testing mode

### 3. Duplicate conversations ("Double Hao")
- Danh sách chat hiện 2 conversation "Hao" giống nhau
- Nhấn vào 1 cái → không có tin nhắn
- Có thể do tạo lại DB → conversation cũ còn cache trên app

### 4. Realtime chậm (Mười Phone)
- Mười Phone dùng WiFi chung MacBook → bandwidth thấp
- SignalR WebSocket dễ mất kết nối
- Giải pháp: Dùng 4G/5G hoặc cải thiện reconnection logic

### 5. Push Notification cho cuộc gọi đến
- Hiện tại incoming call chỉ nhận được khi app đang mở (foreground)
- Cần FCM push notification + CallKit integration cho background calls

---

## FILES ĐÃ SỬA (Session chiều)
1. `mobile/ios/Podfile` — **CRITICAL**: thêm permission macros cho microphone/camera
2. `mobile/lib/data/services/agora_service.dart` — fix init/dispose, remove premature setEnableSpeakerphone, improve permission handling
3. `mobile/lib/presentation/screens/call/call_screen.dart` — fix channelId, add debug overlay, add visible logs, startPreview()
4. `mobile/lib/presentation/providers/auth_provider.dart` — logout callbacks system
5. `mobile/lib/main.dart` — register provider cleanup on logout
6. `mobile/lib/presentation/screens/home/widgets/chat_list.dart` — force refresh on mount

## FILES ĐÃ SỬA (Session sáng)
1. `mobile/lib/presentation/screens/chat/widgets/chat_message_helpers.dart` — timezone fix
2. `mobile/lib/data/models/conversation_model.dart` — timezone fix cho conversation list
3. `mobile/lib/core/utils/date_formatter.dart` — 12h → 24h format
4. `mobile/lib/presentation/screens/call/call_screen.dart` — UI centered + debug logging
5. `mobile/lib/data/services/agora_service.dart` — new App ID, skip token, debug logging

## THÔNG TIN QUAN TRỌNG
- **VPS**: 139.180.217.83, password: `C%k7[C{DhVwC}gYU`
- **Gateway**: port 5001, Identity: 5002, Chat: 5003, User: 5004, Presence: 5005
- **Agora App ID (Testing Mode)**: `37cc9df20f2d4cd9860e29b6b4b9517b`
- **Agora App ID (Secured, cũ)**: `907e967d3be9444b9336adbd6bf6a6d6`
- **iPhone M**: `00008110-00167CAE340BA01E`
- **Mười Phone**: `00008030-000604CC2E40802E`

## GIT COMMITS
1. `1904b83` — fix: Logout data loss + Agora call audio/video not working
2. `b8a5043` — fix: Agora call working - Podfile permissions + engine init
