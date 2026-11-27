package app.xhabit.tracker

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import java.util.concurrent.ConcurrentHashMap
import kotlin.math.ceil
import kotlin.math.max
import kotlin.math.min

/**
 * High-DPI Canvas bitmap renderers for native Android RemoteViews widgets:
 * - Rounded 20dp cards (dark/light + optional glow) with zero corner bleed
 * - True Vazirmatn / FiraSans typography for all widget text, always cleanly left-aligned
 * - MaterialIcons glyphs for 2x1 / 3x1 habit icon badges
 * - Circles, SVG-style arcs, capsules, checkboxes, and flames matching the prototype 1:1
 */
object WidgetCanvasHelper {

    private val typefaceCache = ConcurrentHashMap<String, Typeface>()

    fun containsPersianOrArabic(text: String): Boolean {
        for (ch in text) {
            val code = ch.code
            if ((code in 0x0600..0x06FF) ||
                (code in 0x0750..0x077F) ||
                (code in 0x08A0..0x08FF) ||
                (code in 0xFB50..0xFEFF)
            ) {
                return true
            }
        }
        return false
    }

    fun typefaceForText(context: Context, text: String, weight: Int = 1): Typeface {
        val isRtlScript = containsPersianOrArabic(text)
        val path = when {
            isRtlScript && weight >= 2 -> "fonts/Vazirmatn-ExtraBold.ttf"
            isRtlScript && weight == 1 -> "fonts/Vazirmatn-Bold.ttf"
            isRtlScript -> "fonts/Vazirmatn-Regular.ttf"
            weight >= 2 -> "fonts/FiraSans-ExtraBold.ttf"
            weight == 1 -> "fonts/FiraSans-Bold.ttf"
            else -> "fonts/FiraSans-Regular.ttf"
        }
        return loadAssetTypeface(context, path)
            ?: (if (weight >= 1) Typeface.DEFAULT_BOLD else Typeface.DEFAULT)
    }

    fun materialIconsTypeface(context: Context): Typeface? {
        return loadAssetTypeface(context, "flutter_assets/fonts/MaterialIcons-Regular.otf")
    }

    private fun loadAssetTypeface(context: Context, assetPath: String): Typeface? {
        typefaceCache[assetPath]?.let { return it }
        return try {
            val tf = Typeface.createFromAsset(context.assets, assetPath)
            typefaceCache[assetPath] = tf
            tf
        } catch (_: Throwable) {
            null
        }
    }

    fun contrastColor(bg: Int): Int {
        val lum = 0.299 * Color.red(bg) + 0.587 * Color.green(bg) + 0.114 * Color.blue(bg)
        return if (lum > 148) Color.BLACK else Color.WHITE
    }

    fun tintWithAlpha(color: Int, alpha: Float): Int {
        val a = (alpha.coerceIn(0f, 1f) * 255).toInt()
        return Color.argb(a, Color.red(color), Color.green(color), Color.blue(color))
    }

    fun dpToPx(context: Context, dp: Float): Int {
        val scale = context.resources.displayMetrics.density.coerceAtLeast(2f)
        return (dp * scale).toInt().coerceAtLeast(1)
    }

    fun dpToPxF(context: Context, dp: Float): Float {
        val scale = context.resources.displayMetrics.density.coerceAtLeast(2f)
        return dp * scale
    }

    /**
     * Renders ONLY the soft top-right radial glow overlay onto a transparent bitmap.
     * The card's solid background, hairline 1dp border, and anti-aliased rounded corners
     * are rendered natively by the GPU via `@drawable/widget_bg_dark` / `widget_bg_light`
     * with `@dimen/widget_corner_radius` (`system_app_widget_background_radius` on API 31+).
     */
    fun renderCardBackgroundBitmap(
        context: Context,
        isLight: Boolean,
        accent: Int,
        withGlow: Boolean,
        widthDp: Float,
        heightDp: Float,
    ): Bitmap {
        if (!withGlow) {
            return Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        }
        val baseScale = context.resources.displayMetrics.density.coerceIn(1.5f, 2.0f)
        val clampedW = widthDp.coerceIn(110f, 420f)
        val clampedH = heightDp.coerceIn(54f, 520f)
        var w = (clampedW * baseScale).toInt().coerceAtLeast(64)
        var h = (clampedH * baseScale).toInt().coerceAtLeast(64)
        val maxPixels = 512 * 640
        if (w.toLong() * h.toLong() > maxPixels) {
            val down = kotlin.math.sqrt(maxPixels.toDouble() / (w.toDouble() * h.toDouble())).toFloat()
            w = (w * down).toInt().coerceAtLeast(64)
            h = (h * down).toInt().coerceAtLeast(64)
        }
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.density = context.resources.displayMetrics.densityDpi
        val canvas = Canvas(bmp)
        val glowPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(
                w * 0.92f,
                h * 0.08f,
                max(w, h) * 0.68f,
                intArrayOf(tintWithAlpha(accent, if (isLight) 0.14f else 0.19f), Color.TRANSPARENT),
                floatArrayOf(0f, 1f),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRect(0f, 0f, w.toFloat(), h.toFloat(), glowPaint)
        return bmp
    }

    /**
     * Renders crisp single-line text onto a tight intrinsic-sized bitmap (with real display density
     * so wrap_content ImageViews match exact sp sizes cleanly with zero blur or OEM font override).
     * Shapes Persian/Arabic contextual glyphs properly while keeping tight left-anchored placement.
     */
    fun renderTextBitmap(
        context: Context,
        text: String,
        spSize: Float,
        color: Int,
        weight: Int = 1,
        maxWidthDp: Float = 260f,
        strikethrough: Boolean = false,
    ): Bitmap {
        val dm = context.resources.displayMetrics
        val pxText = TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_SP, spSize, dm)
        val maxPx = (maxWidthDp * dm.density.coerceAtLeast(1.5f)).toInt().coerceAtLeast(16)

        val tp = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            this.textSize = pxText
            this.typeface = typefaceForText(context, text, weight)
            this.isStrikeThruText = strikethrough
        }

        val safeText = if (text.isEmpty()) " " else text
        val ellipsized = TextUtils.ellipsize(safeText, tp, maxPx.toFloat(), TextUtils.TruncateAt.END)
        val dir = if (containsPersianOrArabic(safeText)) {
            TextDirectionHeuristics.ANYRTL_LTR
        } else {
            TextDirectionHeuristics.LTR
        }

        val layoutW = maxPx
        val probe = StaticLayout.Builder.obtain(ellipsized, 0, ellipsized.length, tp, layoutW)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setTextDirection(dir)
            .setMaxLines(1)
            .setIncludePad(false)
            .build()

        val lineW = if (probe.lineCount > 0) ceil(probe.getLineWidth(0)).toInt() else 4
        val tightW = max(4, min(layoutW, lineW + (2f * dm.density).toInt()))
        val tightH = max(8, probe.height + (2f * dm.density).toInt())

        val finalLayout = StaticLayout.Builder.obtain(ellipsized, 0, ellipsized.length, tp, tightW)
            .setAlignment(Layout.Alignment.ALIGN_NORMAL)
            .setTextDirection(dir)
            .setMaxLines(1)
            .setIncludePad(false)
            .build()

        val bmp = Bitmap.createBitmap(tightW, tightH, Bitmap.Config.ARGB_8888)
        bmp.density = dm.densityDpi
        val canvas = Canvas(bmp)
        canvas.translate(0f, 1f * dm.density)
        finalLayout.draw(canvas)
        return bmp
    }

    /** Draws `.aw-card` circular action button (`actionCircle`) cleanly on a 3x canvas. */
    fun renderActionCircleBitmap(
        context: Context,
        style: String,
        isQuit: Boolean,
        done: Boolean,
        slipped: Boolean,
        ratio: Float,
        accent: Int,
        isLight: Boolean,
        dpSize: Float = 36f,
    ): Bitmap {
        val sz = dpToPx(context, dpSize)
        val bmp = Bitmap.createBitmap(sz, sz, Bitmap.Config.ARGB_8888)
        bmp.density = context.resources.displayMetrics.densityDpi
        val canvas = Canvas(bmp)
        val cx = sz / 2f
        val cy = sz / 2f
        val r = sz / 2f - sz * 0.04f

        val wText = if (isLight) Color.parseColor("#0F172A") else Color.WHITE
        val wMuted = if (isLight) Color.parseColor("#64748B") else Color.parseColor("#94A3B8")
        val wBorder = if (isLight) Color.argb(62, 15, 23, 42) else Color.argb(54, 255, 255, 255)
        val idleFill = if (isLight) Color.argb(15, 15, 23, 42) else Color.argb(18, 255, 255, 255)
        val fg = contrastColor(accent)

        val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.style = Paint.Style.FILL }
        val strokePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.style = Paint.Style.STROKE
            this.strokeCap = Paint.Cap.ROUND
            this.strokeJoin = Paint.Join.ROUND
        }

        if (style == "count" && !isQuit) {
            if (done) {
                fillPaint.color = accent
                canvas.drawCircle(cx, cy, r, fillPaint)
                drawCheckmark(canvas, cx, cy, sz * 0.24f, fg, sz * 0.085f)
            } else {
                fillPaint.color = tintWithAlpha(accent, 0.09f)
                canvas.drawCircle(cx, cy, r, fillPaint)
                val arcSw = sz * 0.075f
                val arcRect = RectF(arcSw, arcSw, sz - arcSw, sz - arcSw)
                strokePaint.color = tintWithAlpha(accent, 0.24f)
                strokePaint.strokeWidth = arcSw
                canvas.drawArc(arcRect, 0f, 360f, false, strokePaint)
                if (ratio > 0f) {
                    strokePaint.color = accent
                    strokePaint.strokeWidth = arcSw * 1.08f
                    canvas.drawArc(arcRect, -90f, 360f * ratio.coerceIn(0f, 1f), false, strokePaint)
                }
                drawPlus(canvas, cx, cy, sz * 0.19f, wText, sz * 0.075f)
            }
            return bmp
        }

        if (isQuit && slipped) {
            fillPaint.color = Color.argb(46, 239, 68, 68)
            canvas.drawCircle(cx, cy, r, fillPaint)
            strokePaint.color = Color.parseColor("#EF4444")
            strokePaint.strokeWidth = sz * 0.05f
            canvas.drawCircle(cx, cy, r - strokePaint.strokeWidth / 2f, strokePaint)
            drawCross(canvas, cx, cy, sz * 0.17f, Color.parseColor("#EF4444"), sz * 0.078f)
            return bmp
        }

        if (done) {
            fillPaint.color = accent
            canvas.drawCircle(cx, cy, r, fillPaint)
            drawCheckmark(canvas, cx, cy, sz * 0.24f, fg, sz * 0.085f)
        } else {
            fillPaint.color = idleFill
            canvas.drawCircle(cx, cy, r, fillPaint)
            strokePaint.color = wBorder
            strokePaint.strokeWidth = sz * 0.038f
            canvas.drawCircle(cx, cy, r - strokePaint.strokeWidth / 2f, strokePaint)
            drawCheckmark(canvas, cx, cy, sz * 0.22f, wMuted, sz * 0.075f)
        }
        return bmp
    }

    /**
     * Draws `2x1` / `3x1` rounded square icon badge with the real MaterialIcons habit glyph.
     */
    fun renderHabitIconBadgeBitmap(
        context: Context,
        accent: Int,
        iconCodePoint: Int,
        dpSize: Float = 32f,
    ): Bitmap {
        val sz = dpToPx(context, dpSize)
        val bmp = Bitmap.createBitmap(sz, sz, Bitmap.Config.ARGB_8888)
        bmp.density = context.resources.displayMetrics.densityDpi
        val canvas = Canvas(bmp)
        val rad = sz * 0.30f
        val bgPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = tintWithAlpha(accent, 0.18f)
        }
        canvas.drawRoundRect(RectF(0f, 0f, sz.toFloat(), sz.toFloat()), rad, rad, bgPaint)

        val tf = materialIconsTypeface(context)
        if (iconCodePoint > 0 && tf != null) {
            val glyph = String(Character.toChars(iconCodePoint))
            val glyphPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = accent
                this.typeface = tf
                this.textSize = sz * 0.56f
                this.textAlign = Paint.Align.CENTER
            }
            val fm = glyphPaint.fontMetrics
            val baseline = sz / 2f - (fm.ascent + fm.descent) / 2f
            canvas.drawText(glyph, sz / 2f, baseline, glyphPaint)
            return bmp
        }

        // Defensive fallback only if MaterialIcons font is unavailable
        val ringPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = accent
            style = Paint.Style.STROKE
            strokeWidth = sz * 0.075f
        }
        canvas.drawCircle(sz / 2f, sz / 2f, sz * 0.26f, ringPaint)
        return bmp
    }

    /** Renders rounded horizontal progress track + capsule fill matching `.w-prog-track`. */
    fun renderProgressBarBitmap(
        context: Context,
        ratio: Float,
        fillColor: Int,
        isLight: Boolean,
        widthDp: Float = 220f,
        heightDp: Float = 4.5f,
    ): Bitmap {
        val w = dpToPx(context, widthDp)
        val h = dpToPx(context, heightDp).coerceAtLeast(8)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.density = context.resources.displayMetrics.densityDpi
        val canvas = Canvas(bmp)
        val r = h / 2f
        val trackPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isLight) Color.argb(26, 15, 23, 42) else Color.argb(32, 255, 255, 255)
        }
        canvas.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), r, r, trackPaint)

        val clamped = ratio.coerceIn(0f, 1f)
        if (clamped > 0.01f) {
            val fillW = (w * clamped).coerceAtLeast(h.toFloat())
            val fillPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = fillColor }
            canvas.drawRoundRect(RectF(0f, 0f, fillW, h.toFloat()), r, r, fillPaint)
        }
        return bmp
    }

    /** Renders rounded vertical capsule bar for Daily List rows (`3.5dp x 15dp`). */
    fun renderAccentCapsuleBitmap(context: Context, color: Int): Bitmap {
        val w = dpToPx(context, 4f)
        val h = dpToPx(context, 15f)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.density = context.resources.displayMetrics.densityDpi
        val canvas = Canvas(bmp)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        canvas.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), w / 2f, w / 2f, p)
        return bmp
    }

    /** Renders crisp `<` / `>` circular control pill for Day Mode Switcher widget. */
    fun renderChevronButtonBitmap(
        context: Context,
        isNext: Boolean,
        accent: Int,
        isLight: Boolean,
        dpSize: Float = 28f,
    ): Bitmap {
        val sz = dpToPx(context, dpSize)
        val bmp = Bitmap.createBitmap(sz, sz, Bitmap.Config.ARGB_8888)
        bmp.density = context.resources.displayMetrics.densityDpi
        val canvas = Canvas(bmp)
        val cx = sz / 2f
        val cy = sz / 2f
        val r = sz / 2f - sz * 0.04f

        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isLight) Color.argb(14, 15, 23, 42) else Color.argb(20, 255, 255, 255)
        }
        canvas.drawCircle(cx, cy, r, fill)

        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = tintWithAlpha(accent, if (isLight) 0.42f else 0.36f)
            style = Paint.Style.STROKE
            strokeWidth = sz * 0.045f
        }
        canvas.drawCircle(cx, cy, r - border.strokeWidth / 2f, border)

        val chev = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (isLight) Color.parseColor("#0F172A") else Color.WHITE
            style = Paint.Style.STROKE
            strokeWidth = sz * 0.09f
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val arm = sz * 0.16f
        val dir = if (isNext) 1f else -1f
        val path = Path().apply {
            moveTo(cx - dir * arm * 0.45f, cy - arm)
            lineTo(cx + dir * arm * 0.55f, cy)
            lineTo(cx - dir * arm * 0.45f, cy + arm)
        }
        canvas.drawPath(path, chev)
        return bmp
    }

    /** Renders rounded-5dp checklist checkbox for Daily List widgets (`w-sub-box`). */
    fun renderSubCheckboxBitmap(
        context: Context,
        done: Boolean,
        accent: Int,
        isLight: Boolean,
    ): Bitmap {
        val sz = dpToPx(context, 16f)
        val bmp = Bitmap.createBitmap(sz, sz, Bitmap.Config.ARGB_8888)
        bmp.density = context.resources.displayMetrics.densityDpi
        val canvas = Canvas(bmp)
        val rad = sz * 0.30f
        val pad = sz * 0.06f
        val rect = RectF(pad, pad, sz - pad, sz - pad)
        if (done) {
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent }
            canvas.drawRoundRect(rect, rad, rad, fill)
            drawCheckmark(canvas, sz / 2f, sz / 2f, sz * 0.25f, contrastColor(accent), sz * 0.11f)
        } else {
            val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = tintWithAlpha(accent, if (isLight) 0.65f else 0.55f)
                style = Paint.Style.STROKE
                strokeWidth = sz * 0.10f
            }
            canvas.drawRoundRect(rect, rad, rad, stroke)
        }
        return bmp
    }

    /** Renders clean streak flame vector badge for widgets. */
    fun renderFlameBitmap(context: Context, color: Int, dpSize: Float = 14f): Bitmap {
        val sz = dpToPx(context, dpSize)
        val bmp = Bitmap.createBitmap(sz, sz, Bitmap.Config.ARGB_8888)
        bmp.density = context.resources.displayMetrics.densityDpi
        val canvas = Canvas(bmp)
        val s = sz / 24f
        canvas.scale(s, s)
        val flame = Path().apply {
            moveTo(13.5f, 2f)
            cubicTo(13.5f, 2f, 18.8f, 6.4f, 18.8f, 12.6f)
            cubicTo(18.8f, 17.5f, 15.6f, 21f, 12f, 21f)
            cubicTo(8.3f, 21f, 5.4f, 17.8f, 5.4f, 13.6f)
            cubicTo(5.4f, 10.6f, 7.1f, 8.2f, 8.6f, 6.8f)
            cubicTo(8.3f, 9.0f, 9.4f, 10.4f, 10.6f, 10.6f)
            cubicTo(9.9f, 7.7f, 11.4f, 4.4f, 13.5f, 2f)
            close()
        }
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color }
        canvas.drawPath(flame, paint)
        return bmp
    }

    private fun drawCheckmark(canvas: Canvas, cx: Float, cy: Float, r: Float, color: Int, sw: Float) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = sw
            strokeCap = Paint.Cap.ROUND
            strokeJoin = Paint.Join.ROUND
        }
        val path = Path().apply {
            moveTo(cx - r * 0.95f, cy + r * 0.05f)
            lineTo(cx - r * 0.22f, cy + r * 0.78f)
            lineTo(cx + r * 1.05f, cy - r * 0.68f)
        }
        canvas.drawPath(path, p)
    }

    private fun drawPlus(canvas: Canvas, cx: Float, cy: Float, r: Float, color: Int, sw: Float) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = sw
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawLine(cx - r, cy, cx + r, cy, p)
        canvas.drawLine(cx, cy - r, cx, cy + r, p)
    }

    private fun drawCross(canvas: Canvas, cx: Float, cy: Float, r: Float, color: Int, sw: Float) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.STROKE
            strokeWidth = sw
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawLine(cx - r, cy - r, cx + r, cy + r, p)
        canvas.drawLine(cx + r, cy - r, cx - r, cy + r, p)
    }
}
