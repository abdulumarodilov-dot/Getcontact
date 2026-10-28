// Bu fayl andoza (shablon). tool/patch_android.sh uni
// android/app/src/main/kotlin/<paket>/MainActivity.kt ga ko'chiradi va
// pastdagi o'rinbosarni loyihaning haqiqiy paket nomiga almashtiradi.
//
// Nega android/ papkasida saqlanmaydi? Chunki u har bir build'da
// `flutter create` tomonidan qaytadan yaratiladi va qo'lda qo'yilgan
// fayllar yo'qoladi.
//
// Uchta narsa shu faylda:
//   MainActivity    — Flutter bilan bog'lovchi, ruxsat so'rash kanali
//   CallerIdService — kiruvchi qo'ng'iroqni ushlaydi
//   CallerIdOverlay — ekran ustidagi kichik oyna
//
// Kotlin'da bir faylda bir nechta sinf bo'lishi mumkin, shuning uchun
// hammasi bitta joyda — qo'shimcha fayl ko'chirish shart emas.
package __PACKAGE__

import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.telecom.Call
import android.telecom.CallScreeningService
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val TAG = "CallerId"

/// Flutter bilan aloqa kanali nomi — Dart tomonida ham shunday yozilgan
private const val CHANNEL = "getcontact/callerid"

// ──────────────────────────────────────────────────────────
// MainActivity
// ──────────────────────────────────────────────────────────

// DIQQAT: FlutterActivity emas, FlutterFragmentActivity.
// local_auth (barmoq izi) androidx.biometric'ni ishlatadi, u esa
// FragmentActivity talab qiladi.
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(
                        mapOf(
                            // CallScreeningService Android 10 (API 29) dan bor
                            "supported" to (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q),
                            "overlay" to Settings.canDrawOverlays(this),
                            "role" to hasScreeningRole()
                        )
                    )
                    "requestOverlay" -> {
                        requestOverlay()
                        result.success(null)
                    }
                    "requestRole" -> {
                        requestScreeningRole()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// "Boshqa ilovalar ustida ko'rsatish" sozlamasini ochadi
    private fun requestOverlay() {
        try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
            )
        } catch (e: Throwable) {
            // Ba'zi qobiqlarda package bilan ochilmaydi — umumiy ro'yxatni ochamiz
            Log.w(TAG, "Oyna sozlamasi: $e")
            try {
                startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION))
            } catch (e2: Throwable) {
                Log.e(TAG, "Oyna sozlamasini ochib bo'lmadi: $e2")
            }
        }
    }

    private fun hasScreeningRole(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return false
        val rm = getSystemService(RoleManager::class.java) ?: return false
        return rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING) &&
                rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)
    }

    /// Tizimdan "qo'ng'iroqlarni tekshirish" rolini so'raydi.
    /// Foydalanuvchiga tizim oynasi chiqadi — biz majburlay olmaymiz.
    private fun requestScreeningRole() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return
        val rm = getSystemService(RoleManager::class.java) ?: return
        if (!rm.isRoleAvailable(RoleManager.ROLE_CALL_SCREENING)) {
            Log.w(TAG, "Bu qurilmada rol mavjud emas")
            return
        }
        if (rm.isRoleHeld(RoleManager.ROLE_CALL_SCREENING)) return
        try {
            startActivityForResult(
                rm.createRequestRoleIntent(RoleManager.ROLE_CALL_SCREENING),
                7001
            )
        } catch (e: Throwable) {
            Log.e(TAG, "Rol so'rovi: $e")
        }
    }
}

// ──────────────────────────────────────────────────────────
// Kiruvchi qo'ng'iroqni ushlovchi xizmat
// ──────────────────────────────────────────────────────────

/// Tizim bu xizmatni faqat ilovaga "qo'ng'iroqlarni tekshirish" roli
/// berilgandagina chaqiradi. Rol berilmasa — hech narsa bo'lmaydi.
@RequiresApi(Build.VERSION_CODES.Q)
class CallerIdService : CallScreeningService() {

    override fun onScreenCall(callDetails: Call.Details) {
        // DIQQAT: respondToCall HAR QANDAY holatda chaqirilishi shart.
        // Chaqirilmasa tizim qo'ng'iroqni kutib osib qo'yadi.
        // Bo'sh javob = "aralashma, odatdagidek jiringlasin".
        try {
            respondToCall(callDetails, CallResponse.Builder().build())
        } catch (e: Throwable) {
            Log.e(TAG, "respondToCall: $e")
        }

        if (callDetails.callDirection != Call.Details.DIRECTION_INCOMING) return

        // handle "tel:+998901234567" ko'rinishida keladi
        val number = callDetails.handle?.schemeSpecificPart?.trim()
        if (number.isNullOrEmpty()) {
            Log.w(TAG, "Raqam yashirilgan")
            return
        }

        Log.i(TAG, "Kiruvchi qo'ng'iroq: $number")
        CallerIdOverlay.show(applicationContext, number, lookupName(number))
    }

    /// 2-bosqich: shu yerda bazadan F.I.Sh. qidiriladi.
    /// Hozir ataylab bo'sh — avval oyna umuman chiqishini tekshiramiz.
    private fun lookupName(number: String): String? = null
}

// ──────────────────────────────────────────────────────────
// Ekran ustidagi oyna
// ──────────────────────────────────────────────────────────

/// Oyna XML layout'siz, to'g'ridan-to'g'ri kodda yasaladi — shunda
/// qo'shimcha resurs fayllarini ko'chirish kerak bo'lmaydi.
object CallerIdOverlay {

    private const val SHOW_MS = 25_000L

    private val main = Handler(Looper.getMainLooper())
    private var view: View? = null
    private var appCtx: Context? = null
    private val hideTask = Runnable { hideNow() }

    fun show(ctx: Context, number: String, name: String?) {
        val app = ctx.applicationContext
        main.post {
            if (!Settings.canDrawOverlays(app)) {
                Log.w(TAG, "Ekran ustida ko'rsatish ruxsati yo'q")
                return@post
            }

            appCtx = app
            hideNow()

            val wm = app.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            if (wm == null) {
                Log.e(TAG, "WindowManager topilmadi")
                return@post
            }

            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val lp = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                type,
                // Fokus olmaydi — qo'ng'iroq ekrani tugmalari ishlayveradi
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
                PixelFormat.TRANSLUCENT
            )
            lp.gravity = Gravity.TOP
            lp.y = dp(app, 80)

            try {
                val v = buildView(app, number, name)
                wm.addView(v, lp)
                view = v
                main.removeCallbacks(hideTask)
                main.postDelayed(hideTask, SHOW_MS)
                Log.i(TAG, "Oyna chiqarildi")
            } catch (e: Throwable) {
                // Ba'zi qobiqlar (MIUI va h.k.) ruxsat berilgan bo'lsa ham
                // fon ilovasiga oyna chiqarishni to'sadi
                Log.e(TAG, "Oynani chiqarib bo'lmadi: $e")
            }
        }
    }

    fun hide() = main.post { hideNow() }

    private fun hideNow() {
        val v = view ?: return
        view = null
        main.removeCallbacks(hideTask)
        try {
            val wm = appCtx?.getSystemService(Context.WINDOW_SERVICE) as? WindowManager
            wm?.removeView(v)
        } catch (e: Throwable) {
            Log.w(TAG, "Oynani yopishda: $e")
        }
    }

    private fun buildView(ctx: Context, number: String, name: String?): View {
        val pad = dp(ctx, 16)

        val card = LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad, pad, pad)
            background = GradientDrawable().apply {
                cornerRadius = dp(ctx, 18).toFloat()
                setColor(Color.parseColor("#081F47"))   // AppColors.cardBg
                setStroke(dp(ctx, 1), Color.parseColor("#1A478C"))
            }
            setOnClickListener { hideNow() }
        }

        card.addView(TextView(ctx).apply {
            text = name ?: "Bazada topilmadi"
            setTextColor(
                if (name != null) Color.WHITE else Color.parseColor("#8CB8F2")
            )
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setTypeface(typeface, Typeface.BOLD)
        })

        card.addView(TextView(ctx).apply {
            text = number
            setTextColor(Color.parseColor("#66A8FF"))   // AppColors.accent
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        })

        // Chetlardan bo'shliq qoldirish uchun tashqi qatlam
        return LinearLayout(ctx).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(ctx, 12), 0, dp(ctx, 12), 0)
            addView(
                card,
                LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.MATCH_PARENT,
                    LinearLayout.LayoutParams.WRAP_CONTENT
                )
            )
        }
    }

    private fun dp(ctx: Context, value: Int): Int =
        (value * ctx.resources.displayMetrics.density).toInt()
}
