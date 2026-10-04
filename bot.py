import os
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
class HealthHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"LoveMeizu Bot is running")

    def log_message(self, format, *args):
        pass


def run_health_server():
    port = int(os.environ.get("PORT", 10000))
    server = HTTPServer(("0.0.0.0", port), HealthHandler)
    server.serve_forever()

def run_health_server():
    port = int(os.environ.get("PORT", 10000))
    server = HTTPServer(("0.0.0.0", port), HealthHandler)
    server.serve_forever()
import os
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    CallbackQueryHandler,
    ContextTypes,
)

TOKEN = os.getenv("BOT_TOKEN")

if not TOKEN:
    raise RuntimeError("Chưa thiết lập biến môi trường BOT_TOKEN.")


# =========================
# LINKS
# =========================

KEY_URL = "https://ogegaugaw.github.io/ogebeta1/index.html"

APPS = [
    ("🎵 TikTok Mod", "https://link4sub.com/ejER355J3O"),
    ("🎬 CapCut Pro Mod", "https://link4sub.com/DplevRcXra"),
    ("🏝️ Liquid Island VH", "https://link4sub.com/UC4alOo2Dm"),
    ("🪟 Icon App Liquid Glass", "https://link4sub.com/3xxfxDO6hy"),
    ("🚀 Smart Launcher", "https://link4sub.com/1JQf4X4dA4"),
    ("💧 Photo Watermark VH", "https://link4sub.com/5Xg5x9vj3q"),
    ("🎨 20 LUTs", "https://link4sub.com/76pgMH5KcR"),
    ("🚀 Duo Launcher", "https://link4sub.com/mZlhWORoK1"),
    ("🪟 Tùy biến Windows", "https://link4sub.com/xmbYGNcMyu"),
]

COMMUNITY = [
    ("🌐 Link Bio", "https://beacons.ai/ogegaugaw"),
    ("📱 Telegram", "https://t.me/ogegaugaw"),
    ("💬 Discord", "https://discord.gg/6UGdKYRx6"),
    ("🎵 TikTok", "https://www.tiktok.com/@meizulovers"),
]


# =========================
# MENU
# =========================

def main_keyboard():
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton("🔑 GET KEY", callback_data="getkey"),
            InlineKeyboardButton("📱 ỨNG DỤNG", callback_data="apps"),
        ],
        [
            InlineKeyboardButton("🛠️ FIX LỖI APP", callback_data="fix"),
            InlineKeyboardButton("🔗 LINK BIO", callback_data="community"),
        ],
        [
            InlineKeyboardButton("🆕 APP MỚI", callback_data="newapps"),
            InlineKeyboardButton("❓ HƯỚNG DẪN", callback_data="guide"),
        ],
        [
            InlineKeyboardButton("🆘 HỖ TRỢ", callback_data="support"),
            InlineKeyboardButton("ℹ️ THÔNG TIN", callback_data="info"),
        ],
    ])


def back_home_keyboard():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("🏠 Menu chính", callback_data="home")]
    ])


def apps_keyboard():
    buttons = []

    for name, url in APPS:
        buttons.append([
            InlineKeyboardButton(name, url=url)
        ])

    buttons.append([
        InlineKeyboardButton("🏠 Menu chính", callback_data="home")
    ])

    return InlineKeyboardMarkup(buttons)


def community_keyboard():
    buttons = []

    for name, url in COMMUNITY:
        buttons.append([
            InlineKeyboardButton(name, url=url)
        ])

    buttons.append([
        InlineKeyboardButton("🏠 Menu chính", callback_data="home")
    ])

    return InlineKeyboardMarkup(buttons)


def fix_keyboard():
    return InlineKeyboardMarkup([
        [InlineKeyboardButton("❌ Lỗi cài đặt", callback_data="fix_install")],
        [InlineKeyboardButton("🔐 Không bật được quyền", callback_data="fix_permission")],
        [InlineKeyboardButton("🚫 App không mở", callback_data="fix_notopen")],
        [InlineKeyboardButton("📱 Không tương thích", callback_data="fix_compatible")],
        [InlineKeyboardButton("🔔 Không nhận thông báo", callback_data="fix_notification")],
        [InlineKeyboardButton("🪟 Không hiện popup", callback_data="fix_popup")],
        [InlineKeyboardButton("⚙️ App hoạt động không đúng", callback_data="fix_wrong")],
        [InlineKeyboardButton("🆘 Lỗi khác", callback_data="fix_other")],
        [InlineKeyboardButton("🏠 Menu chính", callback_data="home")],
    ])


# =========================
# NỘI DUNG
# =========================

WELCOME = """💎 <b>LOVE MEIZU BOT</b>

Chào mừng bạn đến với bot của LoveMeizu.

📱 App Việt hóa • Tiện ích Android
🔑 Get Key • 🛠️ Fix lỗi • 🔗 Cộng đồng

Chọn một mục bên dưới:"""


FIX_INSTALL = """❌ <b>LỖI CÀI ĐẶT</b>

Nếu gặp “Ứng dụng chưa được cài đặt”
hoặc “Cài đặt không hợp lệ”:

• Kiểm tra file APK đã tải đầy đủ chưa.
• Kiểm tra phiên bản Android có phù hợp không.
• Kiểm tra APK có đúng kiến trúc thiết bị không.
• Nếu hệ thống cảnh báo Play Protect, xem kỹ cảnh báo trước khi cài.
• Nếu vẫn lỗi, gửi ảnh lỗi + tên máy + phiên bản Android để được kiểm tra."""


FIX_PERMISSION = """🔐 <b>KHÔNG BẬT ĐƯỢC QUYỀN</b>

Thử các bước sau:

1. Vào Cài đặt → Ứng dụng.
2. Chọn ứng dụng đang bị lỗi.
3. Bấm dấu ⋮ ở góc trên nếu máy có.
4. Nếu có “Unlock permissions” hoặc
“Cho phép tất cả quyền”, chọn mục đó.
5. Quay lại phần Quyền của ứng dụng và thử bật lại.

Tên mục có thể khác nhau tùy hãng máy
và phiên bản Android."""


FIX_NOTOPEN = """🚫 <b>APP KHÔNG MỞ ĐƯỢC</b>

• Khởi động lại điện thoại.
• Vào Cài đặt → Ứng dụng → chọn app → Buộc dừng.
• Mở lại app.
• Kiểm tra app có yêu cầu quyền đặc biệt nào chưa.
• Nếu vẫn bị thoát, gửi ảnh/video lỗi để được kiểm tra."""


FIX_COMPATIBLE = """📱 <b>KHÔNG TƯƠNG THÍCH</b>

Kiểm tra:

• Phiên bản Android.
• Kiến trúc CPU: ARM64, ARMv7...
• Phiên bản APK.
• Dung lượng trống trên máy.

Nếu không biết kiểm tra,
gửi tên máy + phiên bản Android để được hướng dẫn."""


FIX_NOTIFICATION = """🔔 <b>KHÔNG NHẬN ĐƯỢC THÔNG BÁO</b>

• Vào Cài đặt → Ứng dụng → chọn app → Thông báo.
• Bật thông báo cho ứng dụng.
• Kiểm tra chế độ Không làm phiền.
• Kiểm tra app có bị hạn chế chạy nền hoặc tiết kiệm pin không.
• Nếu máy có quản lý tự khởi động, cho phép app hoạt động."""


FIX_POPUP = """🪟 <b>KHÔNG HIỆN POPUP</b>

• Kiểm tra quyền “Hiển thị trên ứng dụng khác”.
• Kiểm tra quyền thông báo.
• Cho phép app chạy nền nếu ứng dụng yêu cầu.
• Tắt hạn chế pin cho ứng dụng nếu cần.
• Mở lại app sau khi cấp quyền."""


FIX_WRONG = """⚙️ <b>APP HOẠT ĐỘNG KHÔNG ĐÚNG</b>

• Đóng hoàn toàn ứng dụng rồi mở lại.
• Kiểm tra các quyền cần thiết.
• Kiểm tra phiên bản app có mới nhất không.
• Xóa cache của app rồi thử lại.
• Nếu vẫn lỗi, gửi ảnh/video + tên máy + Android để kiểm tra."""


FIX_OTHER = """🆘 <b>LỖI KHÁC</b>

Bạn gửi:

• Tên ứng dụng
• Tên máy
• Phiên bản Android
• Ảnh hoặc video lỗi
• Mô tả ngắn lỗi xảy ra lúc nào

Mình sẽ dựa vào thông tin đó để hướng dẫn kiểm tra."""


GUIDE = """❓ <b>HƯỚNG DẪN SỬ DỤNG</b>

🔑 GET KEY
→ Mở trang Key System để lấy key.

📱 ỨNG DỤNG
→ Chọn app muốn tải.

🛠️ FIX LỖI APP
→ Chọn đúng lỗi đang gặp để xem hướng dẫn.

🔗 LINK BIO
→ Các kênh và liên kết chính thức của LoveMeizu.

🆘 HỖ TRỢ
→ Gửi thông tin lỗi để được hỗ trợ."""


SUPPORT = """🆘 <b>HỖ TRỢ</b>

Khi cần hỗ trợ, hãy gửi:

• Tên app
• Tên máy
• Phiên bản Android
• Ảnh/video lỗi
• Các bước bạn đã thử

Không gửi mật khẩu, mã OTP hoặc thông tin tài khoản cá nhân."""


INFO = """ℹ️ <b>LOVE MEIZU</b>

Nơi chia sẻ app Việt hóa, tiện ích Android
và các công cụ được cập nhật bởi LoveMeizu.

📱 Hỗ trợ Android
🔗 Link chính thức nằm trong mục Link Bio."""


NEW_APPS = """🆕 <b>APP MỚI CẬP NHẬT</b>

Các app mới sẽ được cập nhật tại đây.

🔔 Theo dõi Telegram/TikTok để nhận thông báo
khi có bản mới."""


# =========================
# COMMANDS
# =========================

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        WELCOME,
        parse_mode="HTML",
        reply_markup=main_keyboard()
    )


async def fixloiapp(update: Update, context: ContextTypes.DEFAULT_TYPE):
    await update.message.reply_text(
        "🛠️ <b>FIX LỖI APP</b>\n\n"
        "Chọn lỗi bạn đang gặp:",
        parse_mode="HTML",
        reply_markup=fix_keyboard()
    )


# =========================
# CALLBACK
# =========================

async def button_handler(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE
):
    query = update.callback_query
    await query.answer()

    data = query.data

    if data == "home":
        await query.edit_message_text(
            WELCOME,
            parse_mode="HTML",
            reply_markup=main_keyboard()
        )

    elif data == "getkey":
        keyboard = InlineKeyboardMarkup([
            [
                InlineKeyboardButton(
                    "🔑 LẤY KEY",
                    url=KEY_URL
                )
            ],
            [
                InlineKeyboardButton(
                    "🏠 Menu chính",
                    callback_data="home"
                )
            ],
        ])

        await query.edit_message_text(
            "🔑 <b>GET KEY</b>\n\n"
            "Nhấn nút bên dưới để mở Key System "
            "và lấy key.",
            parse_mode="HTML",
            reply_markup=keyboard
        )

    elif data == "apps":
        await query.edit_message_text(
            "📱 <b>ỨNG DỤNG LOVE MEIZU</b>\n\n"
            "Chọn ứng dụng bạn muốn tải:",
            parse_mode="HTML",
            reply_markup=apps_keyboard()
        )

    elif data == "community":
        await query.edit_message_text(
            "🔗 <b>LINK BIO & CỘNG ĐỒNG</b>\n\n"
            "Các liên kết chính thức:",
            parse_mode="HTML",
            reply_markup=community_keyboard()
        )

    elif data == "fix":
        await query.edit_message_text(
            "🛠️ <b>FIX LỖI APP</b>\n\n"
            "Chọn lỗi bạn đang gặp:",
            parse_mode="HTML",
            reply_markup=fix_keyboard()
        )

    elif data == "guide":
        await query.edit_message_text(
            GUIDE,
            parse_mode="HTML",
            reply_markup=back_home_keyboard()
        )

    elif data == "support":
        await query.edit_message_text(
            SUPPORT,
            parse_mode="HTML",
            reply_markup=back_home_keyboard()
        )

    elif data == "info":
        await query.edit_message_text(
            INFO,
            parse_mode="HTML",
            reply_markup=back_home_keyboard()
        )

    elif data == "newapps":
        await query.edit_message_text(
            NEW_APPS,
            parse_mode="HTML",
            reply_markup=back_home_keyboard()
        )

    elif data == "fix_install":
        await query.edit_message_text(
            FIX_INSTALL,
            parse_mode="HTML",
            reply_markup=fix_detail_keyboard()
        )

    elif data == "fix_permission":
        await query.edit_message_text(
            FIX_PERMISSION,
            parse_mode="HTML",
            reply_markup=fix_detail_keyboard()
        )

    elif data == "fix_notopen":
        await query.edit_message_text(
            FIX_NOTOPEN,
            parse_mode="HTML",
            reply_markup=fix_detail_keyboard()
        )

    elif data == "fix_compatible":
        await query.edit_message_text(
            FIX_COMPATIBLE,
            parse_mode="HTML",
            reply_markup=fix_detail_keyboard()
        )

    elif data == "fix_notification":
        await query.edit_message_text(
            FIX_NOTIFICATION,
            parse_mode="HTML",
            reply_markup=fix_detail_keyboard()
        )

    elif data == "fix_popup":
        await query.edit_message_text(
            FIX_POPUP,
            parse_mode="HTML",
            reply_markup=fix_detail_keyboard()
        )

    elif data == "fix_wrong":
        await query.edit_message_text(
            FIX_WRONG,
            parse_mode="HTML",
            reply_markup=fix_detail_keyboard()
        )

    elif data == "fix_other":
        await query.edit_message_text(
            FIX_OTHER,
            parse_mode="HTML",
            reply_markup=fix_detail_keyboard()
        )


def fix_detail_keyboard():
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton(
                "🔙 Danh sách lỗi",
                callback_data="fix"
            )
        ],
        [
            InlineKeyboardButton(
                "🏠 Menu chính",
                callback_data="home"
            )
        ],
    ])


# =========================
# ERROR
# =========================

async def error_handler(
    update: object,
    context: ContextTypes.DEFAULT_TYPE
):
    print(f"Bot error: {context.error}")


# =========================
# MAIN
# =========================

def main():
    app = Application.builder().token(TOKEN).build()

    app.add_handler(CommandHandler("start", start))
    app.add_handler(CommandHandler("fixloiapp", fixloiapp))
    app.add_handler(CallbackQueryHandler(button_handler))
    app.add_error_handler(error_handler)

    print("🤖 LoveMeizu Bot đang chạy...")
    app.run_polling()


if __name__ == "__main__":
    main()
