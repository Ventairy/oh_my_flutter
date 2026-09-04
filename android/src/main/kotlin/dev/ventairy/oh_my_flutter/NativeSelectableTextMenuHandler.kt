package dev.ventairy.oh_my_flutter

import android.app.Activity
import android.graphics.Rect
import android.util.Log
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.view.View
import android.view.ViewGroup
import androidx.annotation.VisibleForTesting
import io.flutter.embedding.android.FlutterView
import io.flutter.plugin.common.BinaryMessenger
import java.lang.ref.WeakReference
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToInt

/** Presents Flutter text-selection commands through Android's floating action mode. */
internal class NativeSelectableTextMenuHandler private constructor(
    private val flutterApi: NativeSelectableTextMenuFlutterApi?,
    private val findHostViewOperation: (Activity) -> View?,
    private val startActionModeOperation: (View, ActionMode.Callback2) -> ActionMode?,
    private val densityOperation: (View) -> Float,
    private val locationOnScreenOperation: (View, IntArray) -> Unit,
    private val onActionOperation: ((Long, Long, () -> Unit) -> Unit)?,
    private val onDismissedOperation: ((Long, Boolean) -> Unit)?,
    private val logWarningOperation: (String, Throwable) -> Unit,
) : NativeSelectableTextMenuHostApi {
    constructor(binaryMessenger: BinaryMessenger) : this(
        flutterApi = NativeSelectableTextMenuFlutterApi(binaryMessenger),
        findHostViewOperation = Companion::findFlutterView,
        startActionModeOperation = { view, callback ->
            view.startActionMode(callback, ActionMode.TYPE_FLOATING)
        },
        densityOperation = { view -> view.resources.displayMetrics.density },
        locationOnScreenOperation = View::getLocationOnScreen,
        onActionOperation = null,
        onDismissedOperation = null,
        logWarningOperation = { message, error -> Log.w(LOG_TAG, message, error) },
    )

    private var activityReference: WeakReference<Activity>? = null
    private var hostView: View? = null
    private var request: NativeSelectableTextMenuRequestMessage? = null
    private var actionMode: ActionMode? = null
    private var contentLeft = 0
    private var contentTop = 0
    private var contentRight = 0
    private var contentBottom = 0
    private var selectionLeft = 0.0
    private var selectionTop = 0.0
    private var selectionRight = 0.0
    private var selectionBottom = 0.0
    private var anchorDx = 0.0
    private var anchorDy = 0.0
    private var hasGeometry = false
    private val hostLocationOnScreen = IntArray(2)
    private val callbackLocationOnScreen = IntArray(2)
    private var isDisposed = false

    private val actionModeCallback = object : ActionMode.Callback2() {
        override fun onCreateActionMode(mode: ActionMode, menu: Menu): Boolean {
            return populateMenu(menu)
        }

        override fun onPrepareActionMode(mode: ActionMode, menu: Menu): Boolean {
            menu.clear()
            return populateMenu(menu)
        }

        override fun onActionItemClicked(mode: ActionMode, item: MenuItem): Boolean {
            if (mode !== actionMode) return false
            val currentRequest = request ?: return false
            val itemIndex = item.itemId - MENU_ITEM_IDENTIFIER_BASE
            val actionIdentifier = currentRequest.items.getOrNull(itemIndex)?.identifier ?: return false

            val sessionIdentifier = currentRequest.sessionIdentifier
            val handlerReference = WeakReference(this@NativeSelectableTextMenuHandler)
            closeCurrentMenu(notifyFlutter = false)
            reportAction(sessionIdentifier, actionIdentifier) {
                val handler = handlerReference.get()
                if (handler != null && !handler.isDisposed) {
                    handler.reportDismissed(sessionIdentifier, didInvokeAction = true)
                }
            }
            return true
        }

        override fun onDestroyActionMode(mode: ActionMode) {
            if (mode !== actionMode) return
            val currentRequest = request
            clearCurrentMenu()
            if (currentRequest != null) {
                reportDismissed(
                    currentRequest.sessionIdentifier,
                    didInvokeAction = false,
                )
            }
        }

        override fun onGetContentRect(mode: ActionMode, view: View, outRect: Rect) {
            val currentHostView = hostView ?: return
            if (request == null) return
            setContentRectangle(
                output = outRect,
                callbackView = view,
                currentHostView = currentHostView,
            )
        }
    }

    /** Attaches native menu presentation to the current activity's Flutter view. */
    fun attachActivity(activity: Activity) {
        if (isDisposed) return
        closeCurrentMenu(notifyFlutter = true)
        activityReference = WeakReference(activity)
        hostView = null
    }

    /** Stops native presentation before the current activity is released. */
    fun detachActivity() {
        closeCurrentMenu(notifyFlutter = true)
        hostView = null
        activityReference = null
    }

    /** Releases the handler without messaging an engine that is detaching. */
    fun dispose() {
        isDisposed = true
        closeCurrentMenu(notifyFlutter = false)
        hostView = null
        activityReference = null
    }

    override fun show(request: NativeSelectableTextMenuRequestMessage): Boolean {
        if (this.request?.sessionIdentifier == request.sessionIdentifier) {
            return update(request)
        }

        closeCurrentMenu(notifyFlutter = true)
        val currentHostView = resolveHostView() ?: return false
        val density = densityOperation(currentHostView)
        if (!canPresent(request, currentHostView, density)) {
            return false
        }

        this.request = request
        updateContentRectangle(request, density)
        val presentedMode = try {
            startActionModeOperation(currentHostView, actionModeCallback)
        } catch (error: RuntimeException) {
            logWarningOperation("Android rejected the native text-selection menu.", error)
            null
        }
        if (presentedMode == null) {
            clearCurrentMenu()
            return false
        }
        actionMode = presentedMode
        return true
    }

    override fun update(request: NativeSelectableTextMenuRequestMessage): Boolean {
        val currentRequest = this.request ?: return false
        val currentActionMode = actionMode ?: return false
        if (currentRequest.sessionIdentifier != request.sessionIdentifier) return false

        val currentHostView = hostView
        if (currentHostView == null || isDisposed || !currentHostView.isAttachedToWindow) {
            closeCurrentMenu(notifyFlutter = false)
            return false
        }
        if (currentRequest == request && hasSameGeometry(request)) return true

        val density = densityOperation(currentHostView)
        if (!canPresent(request, currentHostView, density)) {
            closeCurrentMenu(notifyFlutter = false)
            return false
        }

        val itemsChanged = currentRequest.items != request.items
        this.request = request
        val geometryChanged = updateContentRectangle(request, density)
        try {
            if (itemsChanged) {
                currentActionMode.invalidate()
            } else if (geometryChanged) {
                currentActionMode.invalidateContentRect()
            }
        } catch (error: RuntimeException) {
            logWarningOperation("Android rejected the native text-selection menu update.", error)
            closeCurrentMenu(notifyFlutter = false)
            return false
        }
        return true
    }

    override fun updateGeometry(sessionIdentifier: Long, geometry: DoubleArray): Boolean {
        val currentRequest = request ?: return false
        val currentActionMode = actionMode ?: return false
        if (currentRequest.sessionIdentifier != sessionIdentifier) return false

        val currentHostView = hostView
        if (currentHostView == null || isDisposed || !currentHostView.isAttachedToWindow) {
            closeCurrentMenu(notifyFlutter = false)
            return false
        }
        if (!hasValidGeometry(geometry)) {
            closeCurrentMenu(notifyFlutter = false)
            return false
        }
        if (hasSameGeometry(geometry)) return true

        val density = densityOperation(currentHostView)
        if (!density.isFinite() || density <= 0) {
            closeCurrentMenu(notifyFlutter = false)
            return false
        }

        val geometryChanged = updateContentRectangle(
            left = geometry[GEOMETRY_LEFT_INDEX],
            top = geometry[GEOMETRY_TOP_INDEX],
            right = geometry[GEOMETRY_RIGHT_INDEX],
            bottom = geometry[GEOMETRY_BOTTOM_INDEX],
            primaryAnchorDx = geometry[GEOMETRY_ANCHOR_DX_INDEX],
            primaryAnchorDy = geometry[GEOMETRY_ANCHOR_DY_INDEX],
            density = density,
        )
        if (!geometryChanged) return true

        try {
            currentActionMode.invalidateContentRect()
        } catch (error: RuntimeException) {
            logWarningOperation("Android rejected the native text-selection menu update.", error)
            closeCurrentMenu(notifyFlutter = false)
            return false
        }
        return true
    }

    override fun hide(sessionIdentifier: Long) {
        if (request?.sessionIdentifier != sessionIdentifier) return
        closeCurrentMenu(notifyFlutter = true)
    }

    private fun populateMenu(menu: Menu): Boolean {
        val items = request?.items ?: return false
        if (items.isEmpty()) return false

        items.forEachIndexed { index, item ->
            val nativeIdentifier = MENU_ITEM_IDENTIFIER_BASE + index
            menu.add(
                Menu.NONE,
                nativeIdentifier,
                index,
                item.label,
            ).setShowAsAction(MenuItem.SHOW_AS_ACTION_IF_ROOM)
        }
        return true
    }

    private fun resolveHostView(): View? {
        val currentHostView = hostView
        if (currentHostView != null && currentHostView.isAttachedToWindow) {
            return currentHostView
        }

        val activity = activityReference?.get() ?: return currentHostView
        return findHostViewOperation(activity).also { hostView = it }
    }

    private fun canPresent(
        request: NativeSelectableTextMenuRequestMessage,
        hostView: View,
        density: Float,
    ): Boolean {
        if (isDisposed || !hostView.isAttachedToWindow || request.items.isEmpty()) return false
        if (request.items.any { it.label.isBlank() }) return false

        if (!hasValidGeometry(request)) return false

        return density.isFinite() && density > 0
    }

    private fun hasValidGeometry(request: NativeSelectableTextMenuRequestMessage): Boolean {
        val rectangle = request.selectionRectangle
        val anchor = request.primaryAnchor
        return hasValidGeometry(
            left = rectangle.left,
            top = rectangle.top,
            right = rectangle.right,
            bottom = rectangle.bottom,
            primaryAnchorDx = anchor.dx,
            primaryAnchorDy = anchor.dy,
        )
    }

    private fun hasValidGeometry(geometry: DoubleArray): Boolean {
        if (geometry.size != GEOMETRY_VALUE_COUNT) return false
        return hasValidGeometry(
            left = geometry[GEOMETRY_LEFT_INDEX],
            top = geometry[GEOMETRY_TOP_INDEX],
            right = geometry[GEOMETRY_RIGHT_INDEX],
            bottom = geometry[GEOMETRY_BOTTOM_INDEX],
            primaryAnchorDx = geometry[GEOMETRY_ANCHOR_DX_INDEX],
            primaryAnchorDy = geometry[GEOMETRY_ANCHOR_DY_INDEX],
        )
    }

    private fun hasValidGeometry(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        primaryAnchorDx: Double,
        primaryAnchorDy: Double,
    ): Boolean {
        return left.isFinite() &&
            top.isFinite() &&
            right.isFinite() &&
            bottom.isFinite() &&
            right >= left &&
            bottom >= top &&
            primaryAnchorDx.isFinite() &&
            primaryAnchorDy.isFinite()
    }

    private fun updateContentRectangle(
        request: NativeSelectableTextMenuRequestMessage,
        density: Float,
    ): Boolean {
        val rectangle = request.selectionRectangle
        val anchor = request.primaryAnchor
        return updateContentRectangle(
            left = rectangle.left,
            top = rectangle.top,
            right = rectangle.right,
            bottom = rectangle.bottom,
            primaryAnchorDx = anchor.dx,
            primaryAnchorDy = anchor.dy,
            density = density,
        )
    }

    private fun updateContentRectangle(
        left: Double,
        top: Double,
        right: Double,
        bottom: Double,
        primaryAnchorDx: Double,
        primaryAnchorDy: Double,
        density: Float,
    ): Boolean {
        selectionLeft = left
        selectionTop = top
        selectionRight = right
        selectionBottom = bottom
        anchorDx = primaryAnchorDx
        anchorDy = primaryAnchorDy
        hasGeometry = true

        val nextContentLeft: Int
        val nextContentTop: Int
        val nextContentRight: Int
        val nextContentBottom: Int
        if (selectionRight > selectionLeft && selectionBottom > selectionTop) {
            nextContentLeft = floor(selectionLeft * density).toInt()
            nextContentTop = floor(selectionTop * density).toInt()
            nextContentRight = ceil(selectionRight * density).toInt()
            nextContentBottom = ceil(selectionBottom * density).toInt()
        } else {
            nextContentLeft = (anchorDx * density).roundToInt()
            nextContentTop = (anchorDy * density).roundToInt()
            nextContentRight = nextContentLeft + 1
            nextContentBottom = nextContentTop + 1
        }
        if (contentLeft == nextContentLeft &&
            contentTop == nextContentTop &&
            contentRight == nextContentRight &&
            contentBottom == nextContentBottom
        ) {
            return false
        }
        contentLeft = nextContentLeft
        contentTop = nextContentTop
        contentRight = nextContentRight
        contentBottom = nextContentBottom
        return true
    }

    private fun hasSameGeometry(request: NativeSelectableTextMenuRequestMessage): Boolean {
        if (!hasGeometry) return false
        val rectangle = request.selectionRectangle
        val anchor = request.primaryAnchor
        return selectionLeft == rectangle.left &&
            selectionTop == rectangle.top &&
            selectionRight == rectangle.right &&
            selectionBottom == rectangle.bottom &&
            anchorDx == anchor.dx &&
            anchorDy == anchor.dy
    }

    private fun hasSameGeometry(geometry: DoubleArray): Boolean {
        return hasGeometry &&
            selectionLeft == geometry[GEOMETRY_LEFT_INDEX] &&
            selectionTop == geometry[GEOMETRY_TOP_INDEX] &&
            selectionRight == geometry[GEOMETRY_RIGHT_INDEX] &&
            selectionBottom == geometry[GEOMETRY_BOTTOM_INDEX] &&
            anchorDx == geometry[GEOMETRY_ANCHOR_DX_INDEX] &&
            anchorDy == geometry[GEOMETRY_ANCHOR_DY_INDEX]
    }

    private fun setContentRectangle(
        output: Rect,
        callbackView: View,
        currentHostView: View,
    ) {
        if (callbackView === currentHostView) {
            output.set(
                contentLeft,
                contentTop,
                contentRight,
                contentBottom,
            )
            return
        }

        locationOnScreenOperation(currentHostView, hostLocationOnScreen)
        locationOnScreenOperation(callbackView, callbackLocationOnScreen)
        val offsetX = hostLocationOnScreen[0] - callbackLocationOnScreen[0]
        val offsetY = hostLocationOnScreen[1] - callbackLocationOnScreen[1]
        output.set(
            contentLeft + offsetX,
            contentTop + offsetY,
            contentRight + offsetX,
            contentBottom + offsetY,
        )
    }

    private fun closeCurrentMenu(notifyFlutter: Boolean) {
        val currentMode = actionMode
        val currentRequest = request
        clearCurrentMenu()
        currentMode?.finish()
        if (notifyFlutter && currentRequest != null) {
            reportDismissed(
                currentRequest.sessionIdentifier,
                didInvokeAction = false,
            )
        }
    }

    private fun clearCurrentMenu() {
        actionMode = null
        request = null
        contentLeft = 0
        contentTop = 0
        contentRight = 0
        contentBottom = 0
        selectionLeft = 0.0
        selectionTop = 0.0
        selectionRight = 0.0
        selectionBottom = 0.0
        anchorDx = 0.0
        anchorDy = 0.0
        hasGeometry = false
    }

    private fun reportAction(
        sessionIdentifier: Long,
        actionIdentifier: Long,
        onCompleted: () -> Unit,
    ) {
        val operation = onActionOperation
        if (operation != null) {
            operation(sessionIdentifier, actionIdentifier, onCompleted)
            return
        }
        val api = flutterApi
        if (api == null) {
            onCompleted()
            return
        }
        sendFlutterCallback(
            operation = { callback -> api.onAction(sessionIdentifier, actionIdentifier, callback) },
            onCompleted = onCompleted,
        )
    }

    private fun reportDismissed(sessionIdentifier: Long, didInvokeAction: Boolean) {
        val operation = onDismissedOperation
        if (operation != null) {
            operation(sessionIdentifier, didInvokeAction)
            return
        }
        val api = flutterApi ?: return
        sendFlutterCallback(
            operation = { callback ->
                api.onDismissed(sessionIdentifier, didInvokeAction, callback)
            },
        )
    }

    private fun sendFlutterCallback(
        operation: ((Result<Unit>) -> Unit) -> Unit,
        onCompleted: () -> Unit = {},
    ) {
        val logWarning = logWarningOperation
        operation { result ->
            val error = result.exceptionOrNull()
            if (error != null) {
                logWarning("Flutter rejected a native text-selection event.", error)
            }
            onCompleted()
        }
    }

    companion object {
        private const val MENU_ITEM_IDENTIFIER_BASE = Menu.FIRST
        private const val LOG_TAG = "NativeSelectableText"
        private const val GEOMETRY_VALUE_COUNT = 6
        private const val GEOMETRY_LEFT_INDEX = 0
        private const val GEOMETRY_TOP_INDEX = 1
        private const val GEOMETRY_RIGHT_INDEX = 2
        private const val GEOMETRY_BOTTOM_INDEX = 3
        private const val GEOMETRY_ANCHOR_DX_INDEX = 4
        private const val GEOMETRY_ANCHOR_DY_INDEX = 5

        @VisibleForTesting
        fun test(
            findHostView: (Activity) -> View?,
            startActionMode: (View, ActionMode.Callback2) -> ActionMode?,
            density: (View) -> Float,
            locationOnScreen: (View, IntArray) -> Unit,
            onAction: (Long, Long, () -> Unit) -> Unit,
            onDismissed: (Long, Boolean) -> Unit,
        ): NativeSelectableTextMenuHandler {
            return NativeSelectableTextMenuHandler(
                flutterApi = null,
                findHostViewOperation = findHostView,
                startActionModeOperation = startActionMode,
                densityOperation = density,
                locationOnScreenOperation = locationOnScreen,
                onActionOperation = onAction,
                onDismissedOperation = onDismissed,
                logWarningOperation = { _, _ -> },
            )
        }

        @VisibleForTesting
        fun test(
            binaryMessenger: BinaryMessenger,
            findHostView: (Activity) -> View?,
            startActionMode: (View, ActionMode.Callback2) -> ActionMode?,
            density: (View) -> Float,
            locationOnScreen: (View, IntArray) -> Unit,
            logWarning: (String, Throwable) -> Unit,
        ): NativeSelectableTextMenuHandler {
            return NativeSelectableTextMenuHandler(
                flutterApi = NativeSelectableTextMenuFlutterApi(binaryMessenger),
                findHostViewOperation = findHostView,
                startActionModeOperation = startActionMode,
                densityOperation = density,
                locationOnScreenOperation = locationOnScreen,
                onActionOperation = null,
                onDismissedOperation = null,
                logWarningOperation = logWarning,
            )
        }

        private fun findFlutterView(activity: Activity): View? {
            var focusedView = activity.currentFocus
            while (focusedView != null) {
                if (focusedView is FlutterView) return focusedView
                focusedView = focusedView.parent as? View
            }

            val rootView = activity.window?.decorView ?: return null
            val pendingViews = ArrayDeque<View>()
            pendingViews.add(rootView)
            while (pendingViews.isNotEmpty()) {
                val view = pendingViews.removeFirst()
                if (view is FlutterView) return view
                if (view !is ViewGroup) continue
                for (index in 0 until view.childCount) {
                    pendingViews.add(view.getChildAt(index))
                }
            }
            return null
        }
    }
}
