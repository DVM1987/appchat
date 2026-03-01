# Session Summary — 2026-02-28
## Conversation ID: `2d6a1f28-39fd-4810-af8b-e7b2f410e7d1`

> **⚠️ CHO SESSION MỚI**: Đọc conversation ID `2d6a1f28-39fd-4810-af8b-e7b2f410e7d1` để nắm toàn bộ công việc đã làm.
> Đọc TẤT CẢ các file trong folder `workspace/memory/` trước khi bắt đầu làm việc.
> KHÔNG làm lại những việc đã hoàn thành. Tham khảo các conversation liên quan ở mục "Related Conversations" bên dưới.

---

## 🎯 Các Bugs Đã Fix Trong Session Này

### 1. ✅ Push Notification — Hiện sai user "Chat"
**Vấn đề**: User A nhắn tin User B, push noti show ra user "Chat" thay vì tên người gửi.
**Nguyên nhân**: Backend `NotificationService` dùng `ConversationName` (mặc định "Chat") thay vì tên người gửi.
**Fix**: Sửa `NotificationService.cs` để dùng `senderName` thay vì `conversation.Name`.
**File**: `backend/src/Services/Chat/Chat.Application/Services/NotificationService.cs`

### 2. ✅ Online Status Không Ổn Định
**Vấn đề**: Status online không hiện hoặc không ổn định giữa các máy.
**Nguyên nhân**: Nhiều issues — UI không rebuild khi status thay đổi, heartbeat interval quá dài, không reconnect SignalR khi mất kết nối.
**Fix**: 
- Sửa `PresenceProvider` thêm `notifyListeners()` khi status thay đổi
- Giảm heartbeat interval từ 30s → 15s
- Thêm auto-reconnect cho SignalR
**Files**: `mobile/lib/presentation/providers/presence_provider.dart`, `mobile/lib/data/services/signalr_service.dart`

### 3. ✅ Call/Video Call Không Hoạt Động
**Vấn đề**: Màn hình trắng, không nhận cuộc gọi, không chuyển đến màn hình call.
**Nguyên nhân**: Missing Agora App ID, SignalR hub handler cho incoming calls không được register, call screen không render đúng.
**Fix**: 
- Thêm Agora App ID vào `AppConfig`
- Register SignalR handlers trong `CallProvider`
- Sửa `call_screen.dart` UI
**Files**: `mobile/lib/core/config/app_config.dart`, `mobile/lib/presentation/providers/call_provider.dart`, `mobile/lib/presentation/screens/call/call_screen.dart`

### 4. ✅ OTP Verification Server Error
**Vấn đề**: Sau khi nhập OTP, báo lỗi server "Object reference not set to an instance of an object".
**Nguyên nhân**: `firebase-admin-sdk.json` không được mount vào container `identity_service` trên VPS → `FirebaseAuth.DefaultInstance` = null → NullReferenceException.
**Fix**: 
- Copy `firebase-admin-sdk.json` vào đúng path trên VPS
- Cập nhật `docker-compose.yml` để mount từ `/opt/appchat/firebase-admin-sdk.json`
- Cập nhật CI/CD workflow để auto-copy file khi deploy
**Files**: `backend/docker-compose.yml`, `.github/workflows/deploy-backend.yml`

### 5. ✅ OTP reCAPTCHA Fallback (QUAN TRỌNG)
**Vấn đề**: Firebase Phone Auth luôn hiện reCAPTCHA thay vì dùng silent push (APNs).
**Nguyên nhân gốc**: `Runner.entitlements` ghi `aps-environment = production` nhưng Xcode auto-signing luôn ký với `development` → APNs token gửi sai APNS server → silent push fail → Firebase fallback sang reCAPTCHA.
**Quá trình debug**:
1. Thử đổi `FirebaseAppDelegateProxyEnabled` = true → gây "internal error" do conflict với `firebase_messaging` plugin
2. Thử `.prod` APNs token type → vẫn reCAPTCHA
3. Kiểm tra Firebase Console → APNs key `N737HNWZ65` đã upload đúng cả Dev + Production ✅
4. Dùng `codesign -d --entitlements -` kiểm tra binary → thấy `aps-environment = development` (Xcode override)
5. **Fix**: Đổi `Runner.entitlements` sang `development` → match với Xcode auto-signing → APNs hoạt động → không cần reCAPTCHA nữa

**Fix cuối cùng**:
- `Runner.entitlements`: `aps-environment = development`
- `Info.plist`: `FirebaseAppDelegateProxyEnabled = false`
- `AppDelegate.swift`: Manual APNs handling với `.unknown` token type
- **Commit**: `fadf60d`

**Files đã sửa**:
- `mobile/ios/Runner/Runner.entitlements`
- `mobile/ios/Runner/Info.plist`
- `mobile/ios/Runner/AppDelegate.swift`

### 6. ✅ Nhấn Push Notification Mở Sai Conversation
**Vấn đề**: Nhấn notification từ lock screen → mở conversation MỚI trống (cùng tên nhưng không có tin nhắn, không avatar) thay vì mở conversation đã có.
**Nguyên nhân**: Push notification gửi `conversationId`, nhưng `ChatScreen` dùng nó làm `friendId` cho 1-1 chat → gọi `createConversation(conversationId)` → tạo conversation mới.
**Fix**: Thêm tham số `conversationId` vào `ChatScreen`. Khi có `conversationId` (từ notification), dùng trực tiếp thay vì gọi `createConversation`.
**Commit**: `c4b20ff`
**Files**: `mobile/lib/presentation/screens/chat/chat_screen.dart`, `mobile/lib/presentation/screens/home/home_screen.dart`

---

## 📋 Cấu Hình Quan Trọng (KHÔNG ĐƯỢC ĐỔI)

### iOS Firebase Phone Auth — Config Working
```
Runner.entitlements:
  aps-environment = development  (PHẢI là development khi dùng auto-signing)

Info.plist:
  FirebaseAppDelegateProxyEnabled = false  (PHẢI là false, true gây conflict với firebase_messaging)
  CFBundleURLSchemes:
    - com.googleusercontent.apps.351965128781-5s6k88166cq3k0hfppor9qgse928ho1q  (REVERSED_CLIENT_ID)
    - app-1-351965128781-ios-3f06a5ed06fb5e2b065404  (ENCODED_APP_ID)
  UIBackgroundModes: fetch, remote-notification

AppDelegate.swift:
  - registerForRemoteNotifications() trong didFinishLaunchingWithOptions
  - Auth.auth().setAPNSToken(deviceToken, type: .unknown)  (PHẢI là .unknown)
  - Auth.auth().canHandle(url) cho reCAPTCHA redirect
  - Auth.auth().canHandleNotification(notification) cho silent push
```

### Firebase Console
- **Project**: appchat-55da0
- **Plan**: Blaze (pay-as-you-go)
- **APNs Key**: N737HNWZ65 (Dev + Production)
- **Team ID**: 8NJMK5RXJ5
- **Bundle ID**: com.appchat.mobile
- **Phone Auth**: Enabled

### VPS Server (139.180.217.83)
- **SSH**: root@139.180.217.83, password: `C%k7[C{DhVwC}gYU`
- **firebase-admin-sdk.json**: `/opt/appchat/firebase-admin-sdk.json` (backup) + mounted into containers
- **Docker services**: chat_service, chat_identity, nginx, user_service, chat_presence, chat_gateway, chat_seq, chat_redis, chat_rabbitmq, chat_postgres, chat_minio, chat_mongo
- **Databases**: PostgreSQL (chat_db), MongoDB (ChatDb), Redis

### CI/CD
- **GitHub Actions**: `.github/workflows/deploy-backend.yml`
- **Auto-deploy**: Triggers on push to `main` with changes in `backend/`
- **firebase-admin-sdk.json**: CI/CD copies from `/opt/appchat/firebase-admin-sdk.json` to correct path after pulling code

---

## 📱 Thiết Bị Test

| Device | ID | Connection |
|--------|-----|-----------|
| iPhone M | 00008110-00167CAE340BA01E | USB cable |
| Mười Phone | 00008030-000604CC2E40802E | Wireless |

### Build & Install Commands
```bash
# Clean build
cd /Volumes/DVM/appchat/mobile
flutter clean && flutter build ios --release

# Install
flutter install --release -d 00008110-00167CAE340BA01E  # iPhone M
flutter install --release -d 00008030-000604CC2E40802E  # Mười Phone
```

---

## 🔗 Related Conversations
- **2d6a1f28**: (CHAT NÀY) Fix push noti, online status, call, OTP, reCAPTCHA, notification tap
- **f4582b65**: Fixing Firebase Phone Auth Crash — set up OAuth client, URL schemes, APNs key upload
- **f040cd90**: Switching SMS Provider — migrated from Stringee to SpeedSMS (later replaced by Firebase Phone Auth)
- **3ac667bf**: App Store Release Preparation
- **d6fcbff0**: Fixing Call Audio/Video

---

## ⚠️ Lưu Ý Quan Trọng Cho Session Mới

1. **KHÔNG đổi `FirebaseAppDelegateProxyEnabled`** — phải giữ `false`
2. **KHÔNG đổi `aps-environment`** — phải giữ `development` (cho auto-signing dev builds)
3. **KHÔNG đơn giản hóa AppDelegate** — cần đầy đủ 4 override methods cho Firebase Auth
4. Khi deploy backend mới, phải đảm bảo `firebase-admin-sdk.json` được copy đúng path
5. **External drive `/Volumes/DVM/appchat`** hay bị I/O error — nếu gặp thì rút cắm lại USB
6. Khi cài app nhiều lần, APNs token có thể bị reset — cho phép notifications khi app hỏi

---

## 📱 Quy Trình Cài App Lên iPhone (Wireless — KHÔNG cần cắm cable)

Cả 2 iPhone đều đã pair wireless với Mac. Chỉ cần **cùng mạng WiFi** là cài được:

```bash
# 1. Build iOS release
cd /Volumes/DVM/appchat/mobile
flutter build ios --release

# 2. Cài lên iPhone M (wireless)
flutter install --release -d 00008110-00167CAE340BA01E

# 3. Cài lên Mười Phone (wireless)
flutter install --release -d 00008030-000604CC2E40802E
```

> **Lưu ý**: Nếu wireless timeout → retry 1-2 lần. Nếu vẫn fail → cắm cable USB.

---

## 🔄 Quy Trình Xử Lý Bug Chuẩn

```
1. Phân tích bug → xác định file liên quan
2. Sửa code
3. git add -A && git commit -m "fix: ..." && git push origin main
4. flutter build ios --release
5. flutter install --release -d <iPhone_M_ID>
6. flutter install --release -d <Muoi_Phone_ID>
7. Thông báo user test
```
