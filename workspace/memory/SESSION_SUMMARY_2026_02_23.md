# Tóm tắt công việc — 23/02/2026

## 1. Fix App Crash Khi Khởi Động (APNs Loop) ✅

**Vấn đề**: App crash trên iOS do Watchdog timeout — `PushNotificationService.initialize()` chạy vòng lặp chờ APNs token 10 lần × 2s = 20 giây, block main thread.

**Giải pháp**:
- `main.dart`: Bỏ `await` khỏi `PushNotificationService().initialize()` — chạy nền, không block app
- `push_notification_service.dart`: Giảm retry loop từ 10×2s → 2×1s (4s max), thêm `return` sớm khi APNs không available (Apple ID miễn phí)
- `reRegisterToken()`: Giảm retry từ 5×2s → 2×1s, thêm `return` sớm

**Commit**: `9c51c5f`

---

## 2. Fix "Truy cập 01/01/1" — DateTime.MinValue ✅

**Vấn đề**: Người bạn chưa từng online → backend trả `lastSeen: 0001-01-01T00:00:00` (.NET DateTime.MinValue) → app hiện "Truy cập 01/01/1".

**Giải pháp**:
- `chat_screen.dart` → `_fetchInitialPresence()`: Lọc bỏ `year <= 1` → set `_lastSeen = null`

**Commit**: `f0e0f88`

---

## 3. Fix "Last Seen" hiện 0:00 ✅

**Vấn đề**: `timeAgo()` function hiện HH:mm cho mọi timestamp cũ → hiện "0:00" cho ngày lâu.

**Giải pháp**:
- `chat_message_helpers.dart` → `timeAgo()`: Hiện "X phút trước", "X giờ trước", "X ngày trước", "dd/MM" cho timestamp cũ hơn

**Commit**: `d4fe9e0`

---

## 4. Thêm HTTP Timeout Cho Tất Cả API Calls ✅

**Vấn đề**: Tất cả HTTP requests không có timeout → nếu server không phản hồi, app treo vĩnh viễn (mặc định 60s system timeout).

**Giải pháp**:

| Service | Methods | Timeout |
|---------|---------|---------|
| `auth_service.dart` | `sendOtp()`, `verifyOtp()` | **15 giây** |
| `user_service.dart` | `getFriends()`, `getPendingRequests()`, `getUserProfile()` | **10 giây** |

**Commit**: `3463706`

---

## 5. Fix UserProvider.loadData() Flash Empty ✅

**Vấn đề**: `loadData()` xóa `_friends = []` trước khi fetch → hiện spinner mỗi lần refresh, dù data đã có.

**Giải pháp**:
- `user_provider.dart`: Giữ data cũ khi refresh, chỉ hiện spinner lần đầu (khi data trống)

**Commit**: `3463706` (cùng commit với HTTP timeout)

---

## 6. Fix Logout Không Hoạt Động ✅

**Vấn đề**: `_logout()` gọi `await ChatService().disconnect()` → bên trong 3 lần `await hubConnection.stop()` treo vĩnh viễn khi SignalR connection bị hỏng.

**Giải pháp**:
- `chat_service.dart` → `disconnect()`: Thêm timeout 3s cho mỗi `stop()`, chạy song song bằng `Future.wait`, try-catch
- `profile_screen.dart` → `_logout()`: Đổi `void async` → `Future<void>`, thêm try-catch, **luôn navigate** về login dù disconnect fail

**Commit**: `53e3bc6`

---

## 7. Fix Realtime Rất Chậm — Tối Ưu SignalR ✅

**Vấn đề**: 
1. 3 SignalR hubs (Chat, Presence, User) nối **tuần tự** → tổng 6-15 giây
2. App **ngắt kết nối** khi tắt màn hình → mở lại phải reconnect 6-15s
3. SignalR dùng negotiate → có thể fallback Long Polling (chậm)

**Giải pháp**:
- `chat_service.dart` → `initSignalR()`: Refactor toàn bộ
  - 3 hubs build riêng (`_buildChatHub`, `_buildPresenceHub`, `_buildUserHub`)
  - Nối **song song** bằng `Future.wait` + helper `_connectHub()`
  - `skipNegotiation: true` + `transport: HttpTransportType.WebSockets` → WebSocket trực tiếp
  - Thêm `Stopwatch` logging đo thời gian kết nối
- `didChangeAppLifecycleState()`: **Không disconnect khi pause** nữa — chỉ disconnect khi detach (app bị kill)

**Commit**: `0010cf0`

---

## 8. Xác Nhận Trạng Thái VPS Backend ✅

**Đã kiểm tra trực tiếp qua SSH + API:**
- ✅ Tất cả **12 containers** đang chạy (UP 42 giờ)
- ✅ OTP endpoint phản hồi trong **0.15 giây**
- ✅ Friends API phản hồi trong **0.12 giây**
- ✅ Presence API phản hồi trong **0.15 giây**
- ⚠️ Conversations list trống `[]` — data mất từ phiên 21/02 (drop bảng DB)
- ⚠️ Friend presence trả `lastSeen: 0001-01-01T00:00:00` cho user chưa bao giờ online

---

## 9. Cài App Lên 2 iPhone ✅

| Điện thoại | Device ID | iOS | Trạng thái |
|-----------|-----------|-----|-----------|
| **iPhone M** | `00008110-00167CAE340BA01E` | 26.3 | ✅ Cài thành công (sau flutter clean) |
| **Mười Phone** | `00008030-000604CC2E40802E` | 26.2.1 | ✅ Cài thành công |

---

## 10. Git Push + CI/CD ✅

- ✅ Tất cả commits đã push lên GitHub `origin/main`
- ⚠️ CI/CD không trigger — đúng behavior vì workflow chỉ chạy khi thay đổi `backend/**`, hôm nay chỉ sửa `mobile/`

---

## Danh sách Commits — 23/02/2026

| Commit | Mô tả |
|--------|--------|
| `4f52ece` | fix: App crash on launch due to iOS Watchdog timeout caused by APNs blocking loop |
| `d4fe9e0` | fix: Last seen showing 0:00 + add debug logging for message loading |
| `9c51c5f` | perf: Reduce APNs retry loop from 20s to 2s + add HTTP timeouts for auth calls |
| `f0e0f88` | fix: Filter out DateTime.MinValue (01/01/0001) from lastSeen display |
| `3463706` | perf: Add HTTP timeouts to UserService, fix loadData clearing data on refresh |
| `53e3bc6` | fix: Logout button not responding - add timeout to SignalR disconnect |
| `0010cf0` | perf: Major SignalR optimization - parallel connections, WebSocket transport, no disconnect on pause |

---

## Danh sách File Đã Thay Đổi

| File | Thay đổi |
|------|----------|
| `mobile/lib/main.dart` | Bỏ `await` PushNotificationService |
| `mobile/lib/data/services/push_notification_service.dart` | Giảm APNs retry + return sớm |
| `mobile/lib/data/services/auth_service.dart` | +HTTP timeout 15s, +print logging |
| `mobile/lib/data/services/user_service.dart` | +HTTP timeout 10s, +print logging |
| `mobile/lib/data/services/chat_service.dart` | Refactor SignalR (parallel, WebSocket, timeout disconnect) |
| `mobile/lib/presentation/screens/chat/chat_screen.dart` | Fix lastSeen DateTime.MinValue, fix UTC parse |
| `mobile/lib/presentation/screens/chat/widgets/chat_message_helpers.dart` | Fix timeAgo() hiện "X ngày trước" |
| `mobile/lib/presentation/screens/profile/profile_screen.dart` | Fix logout async + try-catch |
| `mobile/lib/presentation/providers/user_provider.dart` | Fix loadData() không clear data khi refresh |

---

## TODO còn lại

| # | Việc | Ưu tiên | Ghi chú |
|---|------|---------|---------|
| 1 | HTTPS + Domain | 🟡 | Nginx reverse proxy + Let's Encrypt |
| 2 | Cài lại app mỗi 7 ngày | ⚠️ | Apple free profile hết hạn |
| 3 | JWT token refresh | 🟡 | Hiện tại user phải login lại khi token hết hạn |
| 4 | Test realtime giữa 2 máy | 🔴 | Cần user test |
