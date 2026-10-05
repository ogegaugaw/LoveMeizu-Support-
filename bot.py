import os
import logging
from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    CallbackQueryHandler,
    ContextTypes,
)

# =========================================================
# CONFIG
# =========================================================

TOKEN = os.getenv("BOT_TOKEN")

if not TOKEN:
    raise RuntimeError("Chưa thiết lập biến môi trường BOT_TOKEN.")

BOT_NAME = "LoveMeizu"
BOT_USERNAME = "@lovemeizusupportbot"

KEY_SYSTEM_URL = "https://ogegaugaw.github.io/ogebeta1/index.html"
BIO_URL = "https://beacons.ai/ogegaugaw"

# Nếu sau này có link cộng đồng / app cụ thể,
# chỉ cần thay các giá trị bên dưới.
SUPPORT_URL = ""
COMMUNITY_URL = ""

# =========================================================
# LOGGING
# =========================================================

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)

logging.getLogger("httpx").setLevel(logging.WARNING)

logger = logging.getLogger(__name__)


# =========================================================
# TEXT
# =========================================================

START_TEXT = """
👋 <b>Chào mừng đến với LoveMeizu</b>

Nơi chia sẻ ứng dụng Android, app Việt hoá,
tiện ích và các nội dung liên quan đến Android.

👇 Chọn một mục bên dưới để tiếp tục:
"""

# =========================================================
# MAIN MENU
# =========================================================

def main_menu():
    keyboard = [
        [
            InlineKeyboardButton("🔑 GET KEY", callback_data="menu_key"),
            InlineKeyboardButton("📱 ỨNG DỤNG", callback_data="menu_apps"),
        ],
        [
            InlineKeyboardButton("🛠️ FIX LỖI APP", callback_data="menu_fix"),
            InlineKeyboardButton("🔗 LINK BIO", callback_data="menu_bio"),
        ],
        [
            InlineKeyboardButton("🆕 APP MỚI", callback_data="menu_new"),
            InlineKeyboardButton("❓ HƯỚNG DẪN", callback_data="menu_guide"),
        ],
        [
            InlineKeyboardButton("🆘 HỖ TRỢ", callback_data="menu_support"),
            InlineKeyboardButton("ℹ️ THÔNG TIN", callback_data="menu_info"),
        ],
    ]

    return InlineKeyboardMarkup(keyboard)


def back_menu():
    return InlineKeyboardMarkup([
        [
            InlineKeyboardButton(
                "⬅️ Quay lại",
                callback_data="menu_main"
            )
        ]
    ])


# =========================================================
# GET KEY
# =========================================================

def key_menu():
    keyboard = [
        [
            InlineKeyboardButton(
                "🔑 LẤY KEY",
                url=KEY_SYSTEM_URL
            )
        ],
        [
            InlineKeyboardButton(
                "📖 HƯỚNG DẪN LẤY KEY",
                callback_data="key_guide"
            )
        ],
        [
            InlineKeyboardButton(
                "⬅️ Quay lại",
                callback_data="menu_main"
            )
        ],
    ]

    return InlineKeyboardMarkup(keyboard)


KEY_TEXT = """
🔑 <b>GET KEY</b>

Đây là khu vực lấy key để sử dụng các
dịch vụ/app yêu cầu key của LoveMeizu.

👉 Nhấn <b>🔑 LẤY KEY</b> để mở Key System.

⚠️ Chỉ sử dụng link chính thức được cung cấp
bởi LoveMeizu.
"""


KEY_GUIDE_TEXT = """
📖 <b>HƯỚNG DẪN LẤY KEY</b>

1️⃣ Nhấn <b>🔑 LẤY KEY</b>.

2️⃣ Làm theo các bước được hiển thị trên
trang Key System.

3️⃣ Sau khi hoàn thành, hệ thống sẽ cung cấp key.

4️⃣ Nhập key vào ứng dụng đang yêu cầu key.

⚠️ Không chia sẻ key cá nhân cho người khác
nếu ứng dụng quy định key chỉ sử dụng một lần.
"""


# =========================================================
# APPLICATION MENU
# =========================================================

def apps_menu():
    keyboard = [
        [
            InlineKeyboardButton(
                "🇻🇳 APP VIỆT HOÁ",
                callback_data="apps_vh"
            )
        ],
        [
            InlineKeyboardButton(
                "🧰 TIỆN ÍCH ANDROID",
                callback_data="apps_utils"
            )
        ],
        [
            InlineKeyboardButton(
                "⭐ APP NỔI BẬT",
                callback_data="apps_featured"
            )
        ],
        [
            InlineKeyboardButton(
                "⬅️ Quay lại",
                callback_data="menu_main"
            )
        ],
    ]

    return InlineKeyboardMarkup(keyboard)


APPS_TEXT = """
📱 <b>ỨNG DỤNG</b>

Khu vực tổng hợp các ứng dụng được
LoveMeizu chia sẻ.

Bạn có thể chọn loại ứng dụng bên dưới.
"""


APPS_VH_TEXT = """
🇻🇳 <b>APP VIỆT HOÁ</b>

Danh mục các ứng dụng được Việt hoá
hoặc có nội dung tiếng Việt do LoveMeizu
chia sẻ.

📦 Khi có app mới, thông tin tải xuống
sẽ được cập nhật theo từng bài/app.
"""


APPS_UTILS_TEXT = """
🧰 <b>TIỆN ÍCH ANDROID</b>

Các ứng dụng tiện ích dành cho Android,
bao gồm những công cụ hỗ trợ tùy chỉnh
và sử dụng thiết bị.

📌 Danh sách app cụ thể sẽ được cập nhật
khi có bản phát hành mới.
"""


APPS_FEATURED_TEXT = """
⭐ <b>APP NỔI BẬT</b>

Đây là khu vực dành cho những ứng dụng
được LoveMeizu giới thiệu nổi bật.

🆕 Khi có app nổi bật mới, thông tin
sẽ được cập nhật tại đây.
"""


# =========================================================
# FIX APP
# =========================================================

def fix_menu():
    keyboard = [
        [
            InlineKeyboardButton(
                "💥 APP BỊ VĂNG",
                callback_data="fix_crash"
            ),
            InlineKeyboardButton(
                "📦 KHÔNG CÀI ĐƯỢC APK",
                callback_data="fix_install"
            ),
        ],
        [
            InlineKeyboardButton(
                "🔔 LỖI THÔNG BÁO",
                callback_data="fix_notification"
            ),
            InlineKeyboardButton(
                "⚙️ LỖI QUYỀN",
                callback_data="fix_permission"
            ),
        ],
        [
            InlineKeyboardButton(
                "🔑 LỖI KEY",
                callback_data="fix_key"
            ),
            InlineKeyboardButton(
                "📥 LỖI TẢI APP",
                callback_data="fix_download"
            ),
        ],
        [
            InlineKeyboardButton(
                "⬅️ Quay lại",
                callback_data="menu_main"
            )
        ],
    ]

    return InlineKeyboardMarkup(keyboard)


FIX_TEXT = """
🛠️ <b>FIX LỖI APP</b>

Chọn đúng loại lỗi bạn đang gặp để xem
hướng xử lý cơ bản.
"""


FIX_CRASH_TEXT = """
💥 <b>APP BỊ VĂNG</b>

Một số nguyên nhân thường gặp:

• Phiên bản Android không tương thích.
• App yêu cầu quyền nhưng chưa được cấp.
• APK bị lỗi hoặc cài đặt không hoàn chỉnh.
• App xung đột với phiên bản cũ.

👉 Thử gỡ phiên bản cũ rồi cài lại APK
chính thức.
"""


FIX_INSTALL_TEXT = """
📦 <b>KHÔNG CÀI ĐƯỢC APK</b>

Kiểm tra:

• APK đã tải đầy đủ chưa.
• Thiết bị có đủ dung lượng không.
• APK có phù hợp với Android/kiến trúc thiết bị không.
• Có phiên bản cũ đang cài hay không.

👉 Nếu vẫn lỗi, hãy gửi ảnh lỗi để được hỗ trợ.
"""


FIX_NOTIFICATION_TEXT = """
🔔 <b>LỖI THÔNG BÁO</b>

Kiểm tra:

• Quyền thông báo của ứng dụng.
• Ứng dụng có đang bị hạn chế chạy nền không.
• Chế độ tiết kiệm pin.
• Quyền tự khởi động nếu thiết bị yêu cầu.

⚠️ Một số hãng Android có cơ chế quản lý
ứng dụng nền riêng.
"""


FIX_PERMISSION_TEXT = """
⚙️ <b>LỖI QUYỀN</b>

Nếu app yêu cầu quyền nhưng không hoạt động:

1️⃣ Mở Cài đặt.
2️⃣ Vào Ứng dụng.
3️⃣ Chọn ứng dụng.
4️⃣ Mở Quyền.
5️⃣ Cấp các quyền mà app yêu cầu.

Sau đó mở lại ứng dụng.
"""


FIX_KEY_TEXT = """
🔑 <b>LỖI KEY</b>

Nếu key không hoạt động:

• Kiểm tra key đã nhập chính xác chưa.
• Không thêm khoảng trắng khi nhập.
• Kiểm tra key đã được sử dụng chưa.
• Nếu key đã hết hiệu lực, hãy lấy key mới.

👉 Nếu vẫn gặp lỗi, hãy gửi thông tin lỗi
để được kiểm tra.
"""


FIX_DOWNLOAD_TEXT = """
📥 <b>LỖI TẢI APP</b>

Nếu không tải được ứng dụng:

• Kiểm tra kết nối mạng.
• Kiểm tra dung lượng thiết bị.
• Thử tải lại.
• Đảm bảo link tải còn hoạt động.

⚠️ Chỉ tải APK từ nguồn được LoveMeizu
cung cấp.
"""


# =========================================================
# BIO
# =========================================================

def bio_menu():
    keyboard = [
        [
            InlineKeyboardButton(
                "🌐 MỞ LINK BIO",
                url=BIO_URL
            )
        ],
        [
            InlineKeyboardButton(
                "⬅️ Quay lại",
                callback_data="menu_main"
            )
        ],
    ]

    return InlineKeyboardMarkup(keyboard)


BIO_TEXT = """
🔗 <b>LINK BIO</b>

Toàn bộ liên kết chính của LoveMeizu
được tổng hợp tại Link Bio.

👇 Nhấn nút bên dưới để mở.
"""


# =========================================================
# NEW APPS
# =========================================================

NEW_APPS_TEXT = """
🆕 <b>APP MỚI</b>

Đây là khu vực cập nhật những ứng dụng
mới được LoveMeizu chia sẻ.

📌 Khi có app mới, thông tin phiên bản
và link tải sẽ được cập nhật tại đây.

🔔 Hãy theo dõi các kênh chính thức để
không bỏ lỡ bản cập nhật.
"""


# =========================================================
# GUIDE
# =========================================================

def guide_menu():
    keyboard = [
        [
            InlineKeyboardButton(
                "🔑 CÁCH LẤY KEY",
                callback_data="guide_key"
            )
        ],
        [
            InlineKeyboardButton(
                "📦 CÁCH CÀI APK",
                callback_data="guide_apk"
            )
        ],
        [
            InlineKeyboardButton(
                "🛠️ CÁCH XỬ LÝ LỖI",
                callback_data="guide_fix"
            )
        ],
        [
            InlineKeyboardButton(
                "🔄 CÁCH CẬP NHẬT APP",
                callback_data="guide_update"
            )
        ],
        [
            InlineKeyboardButton(
                "⬅️ Quay lại",
                callback_data="menu_main"
            )
        ],
    ]

    return InlineKeyboardMarkup(keyboard)


GUIDE_TEXT = """
❓ <b>HƯỚNG DẪN</b>

Chọn nội dung bạn muốn xem.
"""


GUIDE_KEY_TEXT = """
🔑 <b>CÁCH LẤY KEY</b>

Mở mục <b>GET KEY</b> → nhấn
<b>🔑 LẤY KEY</b> → hoàn thành các bước
trên Key System → nhận key.
"""


GUIDE_APK_TEXT = """
📦 <b>CÁCH CÀI APK</b>

1️⃣ Tải APK về thiết bị.
2️⃣ Mở file APK.
3️⃣ Cho phép cài đặt nếu Android yêu cầu.
4️⃣ Tiến hành cài đặt.
5️⃣ Mở ứng dụng sau khi cài xong.

⚠️ Chỉ cài APK từ nguồn bạn tin tưởng.
"""


GUIDE_FIX_TEXT = """
🛠️ <b>CÁCH XỬ LÝ LỖI</b>

Vào:

🛠️ FIX LỖI APP

Sau đó chọn đúng lỗi bạn đang gặp để
xem hướng xử lý tương ứng.
"""


GUIDE_UPDATE_TEXT = """
🔄 <b>CÁCH CẬP NHẬT APP</b>

Khi có phiên bản mới:

1️⃣ Tải bản APK mới.
2️⃣ Cài đè lên phiên bản hiện tại nếu
ứng dụng hỗ trợ.
3️⃣ Mở lại ứng dụng.
4️⃣ Kiểm tra các chức năng.

Nếu bản mới yêu cầu gỡ bản cũ, hãy làm
theo hướng dẫn của phiên bản đó.
"""


# =========================================================
# SUPPORT
# =========================================================

def support_menu():
    keyboard = []

    if SUPPORT_URL:
        keyboard.append([
            InlineKeyboardButton(
                "💬 LIÊN HỆ HỖ TRỢ",
                url=SUPPORT_URL
            )
        ])

    keyboard.extend([
        [
            InlineKeyboardButton(
                "🐛 BÁO LỖI APP",
                callback_data="support_bug"
            )
        ],
        [
            InlineKeyboardButton(
                "🔑 LỖI KEY",
                callback_data="support_key"
            )
        ],
        [
            InlineKeyboardButton(
                "📥 LỖI TẢI APP",
                callback_data="support_download"
            )
        ],
        [
            InlineKeyboardButton(
                "⬅️ Quay lại",
                callback_data="menu_main"
            )
        ],
    ])

    return InlineKeyboardMarkup(keyboard)


SUPPORT_TEXT = """
🆘 <b>HỖ TRỢ</b>

Nếu gặp vấn đề với app hoặc Key System,
hãy chọn đúng loại lỗi bên dưới.

Khi báo lỗi, nên gửi:

• Tên ứng dụng.
• Phiên bản ứng dụng.
• Phiên bản Android.
• Mô tả lỗi.
• Ảnh/video lỗi nếu có.
"""


SUPPORT_BUG_TEXT = """
🐛 <b>BÁO LỖI APP</b>

Khi báo lỗi hãy cung cấp:

📱 Tên app:
🔢 Phiên bản:
📱 Thiết bị:
🤖 Android:
❌ Lỗi gặp phải:

Nếu có ảnh hoặc video lỗi, hãy gửi kèm
để việc kiểm tra dễ dàng hơn.
"""


SUPPORT_KEY_TEXT = """
🔑 <b>HỖ TRỢ KEY</b>

Nếu key không hoạt động, hãy kiểm tra:

• Nhập đúng key.
• Không có khoảng trắng.
• Key chưa được sử dụng.
• Key được lấy từ đúng Key System.

Không gửi token hoặc thông tin nhạy cảm
của tài khoản cho người khác.
"""


SUPPORT_DOWNLOAD_TEXT = """
📥 <b>HỖ TRỢ TẢI APP</b>

Nếu link tải không hoạt động, hãy gửi:

• Tên ứng dụng.
• Link đang sử dụng.
• Ảnh lỗi nếu có.

Không gửi thông tin tài khoản cá nhân.
"""


# =========================================================
# INFO
# =========================================================

INFO_TEXT = """
ℹ️ <b>THÔNG TIN LOVE MEIZU</b>

<b>Thương hiệu:</b> LoveMeizu
<b>Bot:</b> @lovemeizusupportbot

LoveMeizu tập trung chia sẻ:

• Ứng dụng Android
• App Việt hoá
• Tiện ích Android
• Hướng dẫn sử dụng
• Hỗ trợ xử lý lỗi app

⚠️ Hãy kiểm tra đúng kênh chính thức
trước khi tải file hoặc sử dụng dịch vụ.
"""


# =========================================================
# /START
# =========================================================

async def start(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not update.message:
        return

    await update.message.reply_text(
        START_TEXT,
        parse_mode="HTML",
        reply_markup=main_menu(),
        disable_web_page_preview=True,
    )


# =========================================================
# /HELP
# =========================================================

async def help_command(update: Update, context: ContextTypes.DEFAULT_TYPE):
    if not update.message:
        return

    text = """
❓ <b>TRỢ GIÚP LOVE MEIZU</b>

Sử dụng /start để mở menu chính.

Các mục chính:

🔑 GET KEY
📱 ỨNG DỤNG
🛠️ FIX LỖI APP
🔗 LINK BIO
🆕 APP MỚI
❓ HƯỚNG DẪN
🆘 HỖ TRỢ
ℹ️ THÔNG TIN
"""

    await update.message.reply_text(
        text,
        parse_mode="HTML",
        reply_markup=main_menu(),
    )


# =========================================================
# CALLBACK HANDLER
# =========================================================

async def button_handler(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE
):
    query = update.callback_query

    if not query:
        return

    # Telegram yêu cầu callback query nên được answer
    # để nút không tiếp tục hiển thị trạng thái loading.
    await query.answer()

    data = query.data

    # -----------------------------------------------------
    # MAIN
    # -----------------------------------------------------

    if data == "menu_main":
        await query.edit_message_text(
            START_TEXT,
            parse_mode="HTML",
            reply_markup=main_menu(),
        )
        return

    # -----------------------------------------------------
    # KEY
    # -----------------------------------------------------

    if data == "menu_key":
        await query.edit_message_text(
            KEY_TEXT,
            parse_mode="HTML",
            reply_markup=key_menu(),
        )
        return

    if data == "key_guide":
        await query.edit_message_text(
            KEY_GUIDE_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    # -----------------------------------------------------
    # APPS
    # -----------------------------------------------------

    if data == "menu_apps":
        await query.edit_message_text(
            APPS_TEXT,
            parse_mode="HTML",
            reply_markup=apps_menu(),
        )
        return

    if data == "apps_vh":
        await query.edit_message_text(
            APPS_VH_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "apps_utils":
        await query.edit_message_text(
            APPS_UTILS_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "apps_featured":
        await query.edit_message_text(
            APPS_FEATURED_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    # -----------------------------------------------------
    # FIX APP
    # -----------------------------------------------------

    if data == "menu_fix":
        await query.edit_message_text(
            FIX_TEXT,
            parse_mode="HTML",
            reply_markup=fix_menu(),
        )
        return

    if data == "fix_crash":
        await query.edit_message_text(
            FIX_CRASH_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "fix_install":
        await query.edit_message_text(
            FIX_INSTALL_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "fix_notification":
        await query.edit_message_text(
            FIX_NOTIFICATION_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "fix_permission":
        await query.edit_message_text(
            FIX_PERMISSION_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "fix_key":
        await query.edit_message_text(
            FIX_KEY_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "fix_download":
        await query.edit_message_text(
            FIX_DOWNLOAD_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    # -----------------------------------------------------
    # BIO
    # -----------------------------------------------------

    if data == "menu_bio":
        await query.edit_message_text(
            BIO_TEXT,
            parse_mode="HTML",
            reply_markup=bio_menu(),
        )
        return

    # -----------------------------------------------------
    # NEW APP
    # -----------------------------------------------------

    if data == "menu_new":
        await query.edit_message_text(
            NEW_APPS_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    # -----------------------------------------------------
    # GUIDE
    # -----------------------------------------------------

    if data == "menu_guide":
        await query.edit_message_text(
            GUIDE_TEXT,
            parse_mode="HTML",
            reply_markup=guide_menu(),
        )
        return

    if data == "guide_key":
        await query.edit_message_text(
            GUIDE_KEY_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "guide_apk":
        await query.edit_message_text(
            GUIDE_APK_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "guide_fix":
        await query.edit_message_text(
            GUIDE_FIX_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "guide_update":
        await query.edit_message_text(
            GUIDE_UPDATE_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    # -----------------------------------------------------
    # SUPPORT
    # -----------------------------------------------------

    if data == "menu_support":
        await query.edit_message_text(
            SUPPORT_TEXT,
            parse_mode="HTML",
            reply_markup=support_menu(),
        )
        return

    if data == "support_bug":
        await query.edit_message_text(
            SUPPORT_BUG_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "support_key":
        await query.edit_message_text(
            SUPPORT_KEY_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    if data == "support_download":
        await query.edit_message_text(
            SUPPORT_DOWNLOAD_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    # -----------------------------------------------------
    # INFO
    # -----------------------------------------------------

    if data == "menu_info":
        await query.edit_message_text(
            INFO_TEXT,
            parse_mode="HTML",
            reply_markup=back_menu(),
        )
        return

    # -----------------------------------------------------
    # UNKNOWN CALLBACK
    # -----------------------------------------------------

    await query.edit_message_text(
        "⚠️ Chức năng này không tồn tại hoặc đã được thay đổi.",
        reply_markup=back_menu(),
    )


# =========================================================
# ERROR HANDLER
# =========================================================

async def error_handler(update: object, context: ContextTypes.DEFAULT_TYPE):
    logger.error(
        "Bot error: %s",
        context.error,
        exc_info=context.error,
    )


# =========================================================
# SET COMMANDS
# =========================================================

async def post_init(application: Application):
    await application.bot.set_my_commands([
        ("start", "Mở menu LoveMeizu"),
        ("help", "Xem hướng dẫn sử dụng bot"),
    ])

    logger.info("Bot commands đã được thiết lập.")


# =========================================================
# MAIN
# =========================================================

def main():
    application = (
        Application.builder()
        .token(TOKEN)
        .post_init(post_init)
        .build()
    )

    application.add_handler(
        CommandHandler("start", start)
    )

    application.add_handler(
        CommandHandler("help", help_command)
    )

    application.add_handler(
        CallbackQueryHandler(button_handler)
    )

    application.add_error_handler(error_handler)

    logger.info("🤖 LoveMeizu Bot đang chạy...")

    # Dùng polling cho Telegram bot.
    # Không thêm HTTPServer/PORT vào file này.
    application.run_polling(
        allowed_updates=Update.ALL_TYPES,
        drop_pending_updates=True,
    )


if __name__ == "__main__":
    main()
