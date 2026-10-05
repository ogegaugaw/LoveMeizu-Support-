import os
import logging

from telegram import Update, InlineKeyboardButton, InlineKeyboardMarkup
from telegram.ext import (
    Application,
    CommandHandler,
    CallbackQueryHandler,
    ContextTypes,
)

# =========================
# CONFIG
# =========================

TOKEN = os.getenv("BOT_TOKEN")

if not TOKEN:
    raise RuntimeError(
        "Chưa thiết lập BOT_TOKEN. "
        "Hãy thêm BOT_TOKEN trong Environment Variables của Render."
    )

logging.basicConfig(
    format="%(asctime)s - %(name)s - %(levelname)s - %(message)s",
    level=logging.INFO,
)

logger = logging.getLogger(__name__)


# =========================
# MENU
# =========================

def main_keyboard():
    keyboard = [
        [
            InlineKeyboardButton("🔑 GET KEY", callback_data="get_key"),
            InlineKeyboardButton("📱 ỨNG DỤNG", callback_data="apps"),
        ],
        [
            InlineKeyboardButton("🛠️ FIX LỖI APP", callback_data="fix"),
            InlineKeyboardButton("🔗 LINK BIO", callback_data="bio"),
        ],
        [
            InlineKeyboardButton("🆕 APP MỚI", callback_data="new_apps"),
            InlineKeyboardButton("❓ HƯỚNG DẪN", callback_data="guide"),
        ],
        [
            InlineKeyboardButton("🆘 HỖ TRỢ", callback_data="support"),
            InlineKeyboardButton("ℹ️ THÔNG TIN", callback_data="info"),
        ],
    ]

    return InlineKeyboardMarkup(keyboard)


# =========================
# /start
# =========================

async def start(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE,
):
    user = update.effective_user

    text = (
        f"👋 Chào {user.first_name}!\n\n"
        "🤖 Chào mừng bạn đến với LoveMeizu Support.\n\n"
        "📱 Nơi chia sẻ ứng dụng Android, app Việt hoá "
        "và các tiện ích dành cho Android.\n\n"
        "👇 Chọn chức năng bên dưới để tiếp tục."
    )

    if update.message:
        await update.message.reply_text(
            text,
            reply_markup=main_keyboard(),
        )


# =========================
# FIX LỖI APP
# =========================

async def fixloiapp(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE,
):
    text = (
        "🛠️ FIX LỖI APP\n\n"
        "Nếu ứng dụng bị lỗi, văng hoặc không hoạt động:\n\n"
        "1️⃣ Kiểm tra đúng phiên bản APK.\n"
        "2️⃣ Thử xoá dữ liệu ứng dụng.\n"
        "3️⃣ Cài lại bản mới nhất.\n"
        "4️⃣ Nếu vẫn lỗi, gửi tên app + mô tả lỗi cho hỗ trợ.\n\n"
        "💬 Bạn có thể liên hệ hỗ trợ để được kiểm tra."
    )

    if update.message:
        await update.message.reply_text(
            text,
            reply_markup=main_keyboard(),
        )


# =========================
# CALLBACK
# =========================

async def button_handler(
    update: Update,
    context: ContextTypes.DEFAULT_TYPE,
):
    query = update.callback_query

    await query.answer()

    data = query.data

    # -------------------------
    # GET KEY
    # -------------------------

    if data == "get_key":
        text = (
            "🔑 GET KEY\n\n"
            "Bạn có thể lấy key thông qua hệ thống Key System "
            "của LoveMeizu.\n\n"
            "🌐 Link lấy key:\n"
            "https://ogegaugaw.github.io/ogebeta1/index.html"
        )

    # -------------------------
    # APPS
    # -------------------------

    elif data == "apps":
        text = (
            "📱 ỨNG DỤNG\n\n"
            "LoveMeizu chia sẻ:\n\n"
            "• 📱 Ứng dụng Android\n"
            "• 🇻🇳 App Việt hoá\n"
            "• 🧰 Tiện ích Android\n"
            "• ✨ Các bản cập nhật mới\n\n"
            "Theo dõi kênh để nhận app mới."
        )

    # -------------------------
    # FIX
    # -------------------------

    elif data == "fix":
        text = (
            "🛠️ FIX LỖI APP\n\n"
            "Nếu app bị văng hoặc lỗi, hãy gửi:\n\n"
            "📱 Tên ứng dụng\n"
            "📦 Phiên bản\n"
            "❌ Mô tả lỗi\n"
            "📸 Ảnh/video lỗi nếu có\n\n"
            "Mình sẽ hỗ trợ kiểm tra."
        )

    # -------------------------
    # BIO
    # -------------------------

    elif data == "bio":
        text = (
            "🔗 LINK BIO\n\n"
            "Tổng hợp link LoveMeizu:\n\n"
            "https://beacons.ai/ogegaugaw"
        )

    # -------------------------
    # APP MỚI
    # -------------------------

    elif data == "new_apps":
        text = (
            "🆕 APP MỚI\n\n"
            "Các ứng dụng và bản Việt hoá mới "
            "sẽ được cập nhật thường xuyên.\n\n"
            "📢 Theo dõi LoveMeizu để không bỏ lỡ."
        )

    # -------------------------
    # HƯỚNG DẪN
    # -------------------------

    elif data == "guide":
        text = (
            "❓ HƯỚNG DẪN\n\n"
            "🔑 GET KEY\n"
            "→ Lấy key thông qua hệ thống Key System.\n\n"
            "📱 ỨNG DỤNG\n"
            "→ Xem thông tin ứng dụng được chia sẻ.\n\n"
            "🛠️ FIX LỖI APP\n"
            "→ Xem hướng dẫn xử lý lỗi.\n\n"
            "🔗 LINK BIO\n"
            "→ Mở trang tổng hợp liên kết."
        )

    # -------------------------
    # SUPPORT
    # -------------------------

    elif data == "support":
        text = (
            "🆘 HỖ TRỢ\n\n"
            "Nếu bạn gặp lỗi với app, hãy gửi:\n\n"
            "• Tên app\n"
            "• Phiên bản app\n"
            "• Thiết bị đang sử dụng\n"
            "• Nội dung lỗi\n"
            "• Ảnh/video nếu có\n\n"
            "💬 LoveMeizu sẽ hỗ trợ khi có thể."
        )

    # -------------------------
    # INFO
    # -------------------------

    elif data == "info":
        text = (
            "ℹ️ THÔNG TIN\n\n"
            "❤️ LoveMeizu\n\n"
            "📱 Chia sẻ app Android\n"
            "🇻🇳 Việt hoá ứng dụng\n"
            "🧰 Tiện ích Android\n"
            "🛠️ Hỗ trợ & sửa lỗi\n\n"
            "Cảm ơn bạn đã sử dụng LoveMeizu."
        )

    else:
        text = "❌ Không tìm thấy chức năng này."

    await query.edit_message_text(
        text,
        reply_markup=main_keyboard(),
    )


# =========================
# ERROR HANDLER
# =========================

async def error_handler(
    update: object,
    context: ContextTypes.DEFAULT_TYPE,
):
    logger.error(
        "Bot error: %s",
        context.error,
        exc_info=context.error,
    )


# =========================
# MAIN
# =========================

def main():
    app = Application.builder().token(TOKEN).build()

    app.add_handler(
        CommandHandler("start", start)
    )

    app.add_handler(
        CommandHandler("fixloiapp", fixloiapp)
    )

    app.add_handler(
        CallbackQueryHandler(button_handler)
    )

    app.add_error_handler(error_handler)

    print("🤖 LoveMeizu Bot đang chạy...")

    app.run_polling(
        drop_pending_updates=True
    )


if __name__ == "__main__":
    main()
