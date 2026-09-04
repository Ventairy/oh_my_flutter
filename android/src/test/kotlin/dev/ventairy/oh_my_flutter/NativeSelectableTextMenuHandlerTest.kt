package dev.ventairy.oh_my_flutter

import android.app.Activity
import android.graphics.Rect
import android.view.ActionMode
import android.view.Menu
import android.view.MenuItem
import android.view.View
import io.flutter.plugin.common.BinaryMessenger
import java.lang.ref.WeakReference
import java.nio.ByteBuffer
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue
import org.mockito.ArgumentCaptor
import org.mockito.ArgumentMatchers.anyInt
import org.mockito.ArgumentMatchers.anyString
import org.mockito.Mockito
import org.mockito.Mockito.mock
import org.mockito.Mockito.never
import org.mockito.Mockito.times
import org.mockito.Mockito.verify

class NativeSelectableTextMenuHandlerTest {
    private lateinit var activity: Activity
    private lateinit var hostView: View
    private lateinit var callbackView: View
    private lateinit var actionMode: ActionMode
    private lateinit var menu: Menu
    private lateinit var callback: ActionMode.Callback2
    private val actions = mutableListOf<Pair<Long, Long>>()
    private val dismissals = mutableListOf<Pair<Long, Boolean>>()
    private val events = mutableListOf<String>()
    private var hostLocation = intArrayOf(0, 0)
    private var callbackLocation = intArrayOf(0, 0)
    private var density = 1f
    private var densityReadCount = 0
    private var locationReadCount = 0
    private var acceptsPresentation = true
    private var defersActionCompletion = false
    private var actionCompletion: (() -> Unit)? = null

    @BeforeTest
    fun setUp() {
        activity = mock(Activity::class.java)
        hostView = mock(View::class.java)
        callbackView = mock(View::class.java)
        actionMode = mock(ActionMode::class.java)
        menu = mock(Menu::class.java)
        actions.clear()
        dismissals.clear()
        events.clear()
        hostLocation = intArrayOf(0, 0)
        callbackLocation = intArrayOf(0, 0)
        density = 1f
        densityReadCount = 0
        locationReadCount = 0
        acceptsPresentation = true
        defersActionCompletion = false
        actionCompletion = null

        Mockito.`when`(hostView.isAttachedToWindow).thenReturn(true)
        Mockito.`when`(
            menu.add(
                Mockito.eq(Menu.NONE),
                anyInt(),
                anyInt(),
                anyString(),
            ),
        ).thenReturn(mock(MenuItem::class.java))
    }

    @Test
    fun `when no Flutter view is attached, it should reject presentation`() {
        val handler = handler(hostView = null)
        handler.attachActivity(activity)

        val accepted = handler.show(request())

        assertFalse(accepted)
    }

    @Test
    fun `when the Flutter view becomes available after activity attachment, it should present natively`() {
        var availableHostView: View? = null
        val handler = handler(findHostView = { availableHostView })
        handler.attachActivity(activity)
        availableHostView = hostView

        val accepted = handler.show(request())

        assertTrue(accepted)
    }

    @Test
    fun `when the activity detaches before presentation, it should clear lazy view resolution`() {
        var findHostViewCount = 0
        val handler = handler(
            findHostView = {
                findHostViewCount += 1
                hostView
            },
        )
        handler.attachActivity(activity)
        handler.detachActivity()

        val accepted = handler.show(request())

        assertEquals(false to 0, accepted to findHostViewCount)
    }

    @Test
    fun `when the handler is disposed before presentation, it should clear lazy view resolution`() {
        var findHostViewCount = 0
        val handler = handler(
            findHostView = {
                findHostViewCount += 1
                hostView
            },
        )
        handler.attachActivity(activity)
        handler.dispose()

        val accepted = handler.show(request())

        assertEquals(false to 0, accepted to findHostViewCount)
    }

    @Test
    fun `when the Flutter view is detached, it should reject presentation`() {
        Mockito.`when`(hostView.isAttachedToWindow).thenReturn(false)
        val handler = attachedHandler()

        val accepted = handler.show(request())

        assertFalse(accepted)
    }

    @Test
    fun `when native presentation is rejected, it should report fallback`() {
        acceptsPresentation = false
        val handler = attachedHandler()

        val accepted = handler.show(request())

        assertFalse(accepted)
    }

    @Test
    fun `when native presentation is rejected, it should preserve the selection for fallback`() {
        acceptsPresentation = false
        val handler = attachedHandler()

        val accepted = handler.show(request())

        assertEquals(false to emptyList<Pair<Long, Boolean>>(), accepted to dismissals)
    }

    @Test
    fun `when native presentation succeeds, it should report acceptance`() {
        val handler = attachedHandler()

        val accepted = handler.show(request())

        assertTrue(accepted)
    }

    @Test
    fun `when a menu is created, it should preserve Flutter action order and labels`() {
        val handler = attachedHandler()

        handler.show(
            request(
                items = listOf(
                    item(identifier = 7, label = "Copy"),
                    item(identifier = 11, label = "Select all"),
                ),
            ),
        )

        val labels = ArgumentCaptor.forClass(String::class.java)
        verify(menu, times(2)).add(
            Mockito.eq(Menu.NONE),
            anyInt(),
            anyInt(),
            labels.capture(),
        )
        assertEquals(listOf("Copy", "Select all"), labels.allValues)
    }

    @Test
    fun `when Android asks for content bounds, it should convert logical pixels into view pixels`() {
        density = 2f
        hostLocation = intArrayOf(100, 200)
        callbackLocation = intArrayOf(40, 50)
        val handler = attachedHandler()
        handler.show(
            request(
                rectangle = rectangle(left = 10.25, top = 20.25, right = 30.25, bottom = 40.25),
            ),
        )
        val output = mock(Rect::class.java)

        callback.onGetContentRect(actionMode, callbackView, output)

        verify(output).set(80, 190, 121, 231)
    }

    @Test
    fun `when selection bounds collapse, it should position from the primary anchor`() {
        density = 2f
        hostLocation = intArrayOf(100, 200)
        callbackLocation = intArrayOf(40, 50)
        val handler = attachedHandler()
        handler.show(
            request(
                rectangle = rectangle(left = 10, top = 20, right = 10, bottom = 20),
                anchor = point(dx = 15, dy = 25),
            ),
        )
        val output = mock(Rect::class.java)

        callback.onGetContentRect(actionMode, callbackView, output)

        verify(output).set(90, 200, 91, 201)
    }

    @Test
    fun `when Android repeatedly asks the host view for content bounds, it should reuse converted geometry`() {
        density = 2f
        val handler = attachedHandler()
        handler.show(
            request(
                rectangle = rectangle(left = 10.25, top = 20.25, right = 30.25, bottom = 40.25),
            ),
        )
        val output = mock(Rect::class.java)
        val readsBeforeCallbacks = densityReadCount to locationReadCount

        callback.onGetContentRect(actionMode, hostView, output)
        callback.onGetContentRect(actionMode, hostView, output)

        assertEquals(
            readsBeforeCallbacks,
            densityReadCount to locationReadCount,
        )
    }

    @Test
    fun `when the selection geometry is invalid, it should reject presentation`() {
        val handler = attachedHandler()

        val accepted = handler.show(
            request(rectangle = rectangle(left = 30, top = 20, right = 10, bottom = 40)),
        )

        assertFalse(accepted)
    }

    @Test
    fun `when an action is chosen, it should report its Flutter identifier`() {
        val handler = attachedHandler()
        handler.show(request(items = listOf(item(identifier = 47, label = "Copy"))))
        val nativeIdentifier = ArgumentCaptor.forClass(Int::class.java)
        verify(menu).add(
            Mockito.eq(Menu.NONE),
            nativeIdentifier.capture(),
            Mockito.eq(0),
            Mockito.eq("Copy"),
        )
        val selectedItem = mock(MenuItem::class.java)
        Mockito.`when`(selectedItem.itemId).thenReturn(nativeIdentifier.value)

        callback.onActionItemClicked(actionMode, selectedItem)

        assertEquals(listOf(1L to 47L), actions)
    }

    @Test
    fun `when an action closes the menu, it should mark the dismissal as invoked`() {
        val handler = attachedHandler()
        handler.show(request(items = listOf(item(identifier = 47, label = "Copy"))))
        val nativeIdentifier = ArgumentCaptor.forClass(Int::class.java)
        verify(menu).add(
            Mockito.eq(Menu.NONE),
            nativeIdentifier.capture(),
            Mockito.eq(0),
            Mockito.eq("Copy"),
        )
        val selectedItem = mock(MenuItem::class.java)
        Mockito.`when`(selectedItem.itemId).thenReturn(nativeIdentifier.value)

        callback.onActionItemClicked(actionMode, selectedItem)

        assertEquals(listOf(1L to true), dismissals)
    }

    @Test
    fun `when an action closes the menu, it should invoke the command before dismissal`() {
        val handler = attachedHandler()
        handler.show(request(items = listOf(item(identifier = 47, label = "Copy"))))
        val nativeIdentifier = ArgumentCaptor.forClass(Int::class.java)
        verify(menu).add(
            Mockito.eq(Menu.NONE),
            nativeIdentifier.capture(),
            Mockito.eq(0),
            Mockito.eq("Copy"),
        )
        val selectedItem = mock(MenuItem::class.java)
        Mockito.`when`(selectedItem.itemId).thenReturn(nativeIdentifier.value)

        callback.onActionItemClicked(actionMode, selectedItem)

        assertEquals(listOf("action", "dismissed"), events)
    }

    @Test
    fun `when action delivery is pending, it should delay the invoked dismissal`() {
        defersActionCompletion = true
        val handler = attachedHandler()
        handler.show(request(items = listOf(item(identifier = 47, label = "Copy"))))
        val nativeIdentifier = ArgumentCaptor.forClass(Int::class.java)
        verify(menu).add(
            Mockito.eq(Menu.NONE),
            nativeIdentifier.capture(),
            Mockito.eq(0),
            Mockito.eq("Copy"),
        )
        val selectedItem = mock(MenuItem::class.java)
        Mockito.`when`(selectedItem.itemId).thenReturn(nativeIdentifier.value)

        callback.onActionItemClicked(actionMode, selectedItem)
        val eventsBeforeCompletion = events.toList()
        actionCompletion?.invoke()

        assertEquals(
            listOf("action") to listOf("action", "dismissed"),
            eventsBeforeCompletion to events,
        )
    }

    @Test
    fun `when disposal interrupts action delivery, it should suppress the invoked dismissal`() {
        defersActionCompletion = true
        val handler = attachedHandler()
        handler.show(request(items = listOf(item(identifier = 47, label = "Copy"))))
        val nativeIdentifier = ArgumentCaptor.forClass(Int::class.java)
        verify(menu).add(
            Mockito.eq(Menu.NONE),
            nativeIdentifier.capture(),
            Mockito.eq(0),
            Mockito.eq("Copy"),
        )
        val selectedItem = mock(MenuItem::class.java)
        Mockito.`when`(selectedItem.itemId).thenReturn(nativeIdentifier.value)

        callback.onActionItemClicked(actionMode, selectedItem)
        handler.dispose()
        actionCompletion?.invoke()

        assertEquals(listOf("action"), events)
    }

    @Test
    fun `when disposal interrupts an unanswered Flutter action, it should release the handler`() {
        val pendingReplies = mutableListOf<BinaryMessenger.BinaryReply>()

        val handlerReference = disposeHandlerWithPendingAction(pendingReplies)
        awaitCollection(handlerReference)

        assertEquals(1 to null, pendingReplies.size to handlerReference.get())
    }

    @Test
    fun `when disposal interrupts an unanswered Flutter dismissal, it should release the handler`() {
        val pendingReplies = mutableListOf<BinaryMessenger.BinaryReply>()

        val handlerReference = disposeHandlerWithPendingDismissal(pendingReplies)
        awaitCollection(handlerReference)

        assertEquals(1 to null, pendingReplies.size to handlerReference.get())
    }

    @Test
    fun `when Android dismisses the toolbar, it should report an external dismissal`() {
        val handler = attachedHandler()
        handler.show(request(sessionIdentifier = 73))

        callback.onDestroyActionMode(actionMode)

        assertEquals(listOf(73L to false), dismissals)
    }

    @Test
    fun `when a stale action mode is destroyed, it should ignore the callback`() {
        val handler = attachedHandler()
        handler.show(request())

        callback.onDestroyActionMode(mock(ActionMode::class.java))

        assertTrue(dismissals.isEmpty())
    }

    @Test
    fun `when only current selection geometry changes, it should invalidate content once`() {
        val handler = attachedHandler()
        handler.show(request())

        val updated = handler.update(
            request(rectangle = rectangle(left = 12, top = 22, right = 32, bottom = 42)),
        )

        verify(actionMode).invalidateContentRect()
        verify(actionMode, never()).invalidate()
        assertTrue(updated)
    }

    @Test
    fun `when compact geometry changes for the current session, it should invalidate content once`() {
        val handler = attachedHandler()
        handler.show(request())

        val updated = handler.updateGeometry(
            1,
            geometry(left = 12, top = 22, right = 32, bottom = 42),
        )

        verify(actionMode).invalidateContentRect()
        verify(actionMode, never()).invalidate()
        assertTrue(updated)
    }

    @Test
    fun `when compact geometry is unchanged, it should perform no action mode work`() {
        val handler = attachedHandler()
        handler.show(request())

        val updated = handler.updateGeometry(1, geometry())

        verify(actionMode, never()).invalidateContentRect()
        verify(actionMode, never()).invalidate()
        assertTrue(updated)
    }

    @Test
    fun `when compact geometry is unchanged, it should not reread display density`() {
        val handler = attachedHandler()
        handler.show(request())
        val readsBeforeUpdate = densityReadCount

        handler.updateGeometry(1, geometry())

        assertEquals(readsBeforeUpdate, densityReadCount)
    }

    @Test
    fun `when compact geometry uses a stale session, it should leave the toolbar unchanged`() {
        val handler = attachedHandler()
        handler.show(request(sessionIdentifier = 4))

        val updated = handler.updateGeometry(3, geometry(left = 12))

        verify(actionMode, never()).invalidateContentRect()
        assertFalse(updated)
    }

    @Test
    fun `when compact geometry has the wrong length, it should reject the update`() {
        val handler = attachedHandler()
        handler.show(request())

        val updated = handler.updateGeometry(1, doubleArrayOf(1.0, 2.0, 3.0))

        assertFalse(updated)
    }

    @Test
    fun `when compact geometry is not finite, it should reject the update`() {
        val handler = attachedHandler()
        handler.show(request())

        val updated = handler.updateGeometry(1, geometry(anchorDx = Double.NaN))

        assertFalse(updated)
    }

    @Test
    fun `when compact geometry is inverted, it should reject the update`() {
        val handler = attachedHandler()
        handler.show(request())

        val updated = handler.updateGeometry(1, geometry(left = 31, right = 30))

        assertFalse(updated)
    }

    @Test
    fun `when the host detaches before compact geometry changes, it should reject the update`() {
        val handler = attachedHandler()
        handler.show(request())
        Mockito.`when`(hostView.isAttachedToWindow).thenReturn(false)

        val updated = handler.updateGeometry(1, geometry(left = 12))

        assertFalse(updated)
    }

    @Test
    fun `when compact geometry changes, it should preserve the current action table`() {
        val handler = attachedHandler()
        handler.show(request(items = listOf(item(identifier = 47, label = "Copy"))))
        val nativeIdentifier = ArgumentCaptor.forClass(Int::class.java)
        verify(menu).add(
            Mockito.eq(Menu.NONE),
            nativeIdentifier.capture(),
            Mockito.eq(0),
            Mockito.eq("Copy"),
        )
        val selectedItem = mock(MenuItem::class.java)
        Mockito.`when`(selectedItem.itemId).thenReturn(nativeIdentifier.value)

        handler.updateGeometry(1, geometry(left = 12))
        callback.onActionItemClicked(actionMode, selectedItem)

        assertEquals(listOf(1L to 47L), actions)
    }

    @Test
    fun `when a full update follows compact geometry, it should restore the requested bounds`() {
        val handler = attachedHandler()
        handler.show(request())
        handler.updateGeometry(1, geometry(left = 12, top = 22, right = 32, bottom = 42))

        val updated = handler.update(request())

        verify(actionMode, times(2)).invalidateContentRect()
        assertTrue(updated)
    }

    @Test
    fun `when current menu items change, it should invalidate the action mode once`() {
        val handler = attachedHandler()
        handler.show(request())

        val updated = handler.update(request(items = listOf(item(9, "Share"))))

        verify(actionMode).invalidate()
        verify(actionMode, never()).invalidateContentRect()
        assertTrue(updated)
    }

    @Test
    fun `when the current request is identical, it should perform no action mode work`() {
        val handler = attachedHandler()
        handler.show(request())

        val updated = handler.update(request())

        verify(actionMode, never()).invalidate()
        verify(actionMode, never()).invalidateContentRect()
        assertTrue(updated)
    }

    @Test
    fun `when a current update becomes unavailable, it should preserve the selection for fallback`() {
        val handler = attachedHandler()
        handler.show(request())
        Mockito.`when`(hostView.isAttachedToWindow).thenReturn(false)

        val updated = handler.update(request())

        assertEquals(false to emptyList<Pair<Long, Boolean>>(), updated to dismissals)
    }

    @Test
    fun `when Android rejects a current update, it should preserve the selection for fallback`() {
        val handler = attachedHandler()
        handler.show(request())
        Mockito.doThrow(RuntimeException("rejected")).`when`(actionMode).invalidate()

        val updated = handler.update(request(items = listOf(item(9, "Share"))))

        assertEquals(false to emptyList<Pair<Long, Boolean>>(), updated to dismissals)
    }

    @Test
    fun `when a stale session updates, it should leave the current toolbar unchanged`() {
        val handler = attachedHandler()
        handler.show(request(sessionIdentifier = 4))

        val updated = handler.update(request(sessionIdentifier = 3))

        assertFalse(updated)
    }

    @Test
    fun `when a stale session hides, it should leave the current toolbar visible`() {
        val handler = attachedHandler()
        handler.show(request(sessionIdentifier = 4))

        handler.hide(3)

        verify(actionMode, never()).finish()
    }

    @Test
    fun `when the current session hides, it should finish its native toolbar`() {
        val handler = attachedHandler()
        handler.show(request(sessionIdentifier = 4))

        handler.hide(4)

        verify(actionMode).finish()
    }

    @Test
    fun `when a new session replaces the current one, it should dismiss the old session`() {
        val handler = attachedHandler()
        handler.show(request(sessionIdentifier = 4))
        acceptsPresentation = true

        handler.show(request(sessionIdentifier = 5))

        assertEquals(listOf(4L to false), dismissals)
    }

    @Test
    fun `when the activity detaches, it should tear down the native toolbar`() {
        val handler = attachedHandler()
        handler.show(request())

        handler.detachActivity()

        verify(actionMode).finish()
    }

    @Test
    fun `when the handler is disposed, it should not send a dismissal to a detached engine`() {
        val handler = attachedHandler()
        handler.show(request())

        handler.dispose()

        assertTrue(dismissals.isEmpty())
    }

    private fun attachedHandler(): NativeSelectableTextMenuHandler {
        return handler().also { it.attachActivity(activity) }
    }

    private fun disposeHandlerWithPendingAction(
        pendingReplies: MutableList<BinaryMessenger.BinaryReply>,
    ): WeakReference<NativeSelectableTextMenuHandler> {
        var handler: NativeSelectableTextMenuHandler? = binaryMessengerHandler(pendingReplies)
        handler?.attachActivity(activity)
        handler?.show(request(items = listOf(item(identifier = 47, label = "Copy"))))
        val nativeIdentifier = ArgumentCaptor.forClass(Int::class.java)
        verify(menu).add(
            Mockito.eq(Menu.NONE),
            nativeIdentifier.capture(),
            Mockito.eq(0),
            Mockito.eq("Copy"),
        )
        val selectedItem = mock(MenuItem::class.java)
        Mockito.`when`(selectedItem.itemId).thenReturn(nativeIdentifier.value)
        callback.onActionItemClicked(actionMode, selectedItem)
        val reference = WeakReference(requireNotNull(handler))

        handler.dispose()
        callback = mock(ActionMode.Callback2::class.java)
        handler = null
        return reference
    }

    private fun disposeHandlerWithPendingDismissal(
        pendingReplies: MutableList<BinaryMessenger.BinaryReply>,
    ): WeakReference<NativeSelectableTextMenuHandler> {
        var handler: NativeSelectableTextMenuHandler? = binaryMessengerHandler(pendingReplies)
        handler?.attachActivity(activity)
        handler?.show(request())
        callback.onDestroyActionMode(actionMode)
        val reference = WeakReference(requireNotNull(handler))

        handler.dispose()
        callback = mock(ActionMode.Callback2::class.java)
        handler = null
        return reference
    }

    private fun binaryMessengerHandler(
        pendingReplies: MutableList<BinaryMessenger.BinaryReply>,
    ): NativeSelectableTextMenuHandler {
        val binaryMessenger = mock(BinaryMessenger::class.java)
        Mockito.doAnswer { invocation ->
            pendingReplies.add(invocation.getArgument(2))
            null
        }.`when`(binaryMessenger).send(
            anyString(),
            Mockito.any(ByteBuffer::class.java),
            Mockito.any(BinaryMessenger.BinaryReply::class.java),
        )
        return NativeSelectableTextMenuHandler.test(
            binaryMessenger = binaryMessenger,
            findHostView = { hostView },
            startActionMode = { _, actionModeCallback ->
                callback = actionModeCallback
                if (!callback.onCreateActionMode(actionMode, menu)) return@test null
                actionMode
            },
            density = { density },
            locationOnScreen = { _, output ->
                output[0] = hostLocation[0]
                output[1] = hostLocation[1]
            },
            logWarning = { _, _ -> },
        )
    }

    private fun awaitCollection(reference: WeakReference<*>) {
        repeat(100) {
            if (reference.get() == null) return
            System.gc()
            System.runFinalization()
            Thread.yield()
        }
    }

    private fun handler(
        hostView: View? = this.hostView,
        findHostView: ((Activity) -> View?)? = null,
    ): NativeSelectableTextMenuHandler {
        return NativeSelectableTextMenuHandler.test(
            findHostView = findHostView ?: { hostView },
            startActionMode = { _, actionModeCallback ->
                callback = actionModeCallback
                if (!acceptsPresentation) return@test null
                if (!callback.onCreateActionMode(actionMode, menu)) return@test null
                actionMode
            },
            density = {
                densityReadCount += 1
                density
            },
            locationOnScreen = { view, output ->
                locationReadCount += 1
                val location = if (view === this.hostView) hostLocation else callbackLocation
                output[0] = location[0]
                output[1] = location[1]
            },
            onAction = { sessionIdentifier, actionIdentifier, onCompleted ->
                actions.add(sessionIdentifier to actionIdentifier)
                events.add("action")
                if (defersActionCompletion) {
                    actionCompletion = onCompleted
                } else {
                    onCompleted()
                }
            },
            onDismissed = { sessionIdentifier, actionInvoked ->
                dismissals.add(sessionIdentifier to actionInvoked)
                events.add("dismissed")
            },
        )
    }

    private fun request(
        sessionIdentifier: Long = 1,
        rectangle: NativeSelectableTextRectangleMessage = rectangle(),
        anchor: NativeSelectableTextPointMessage = point(),
        items: List<NativeSelectableTextMenuItemMessage> = listOf(item()),
    ): NativeSelectableTextMenuRequestMessage {
        return NativeSelectableTextMenuRequestMessage(
            sessionIdentifier = sessionIdentifier,
            selectionRectangle = rectangle,
            primaryAnchor = anchor,
            items = items,
        )
    }

    private fun rectangle(
        left: Number = 10,
        top: Number = 20,
        right: Number = 30,
        bottom: Number = 40,
    ): NativeSelectableTextRectangleMessage {
        return NativeSelectableTextRectangleMessage(
            left = left.toDouble(),
            top = top.toDouble(),
            right = right.toDouble(),
            bottom = bottom.toDouble(),
        )
    }

    private fun point(
        dx: Number = 20,
        dy: Number = 20,
    ): NativeSelectableTextPointMessage {
        return NativeSelectableTextPointMessage(dx.toDouble(), dy.toDouble())
    }

    private fun geometry(
        left: Number = 10,
        top: Number = 20,
        right: Number = 30,
        bottom: Number = 40,
        anchorDx: Number = 20,
        anchorDy: Number = 20,
    ): DoubleArray {
        return doubleArrayOf(
            left.toDouble(),
            top.toDouble(),
            right.toDouble(),
            bottom.toDouble(),
            anchorDx.toDouble(),
            anchorDy.toDouble(),
        )
    }

    private fun item(
        identifier: Long = 1,
        label: String = "Copy",
    ): NativeSelectableTextMenuItemMessage {
        return NativeSelectableTextMenuItemMessage(identifier, label)
    }
}
