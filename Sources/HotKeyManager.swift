import AppKit
import Carbon.HIToolbox

/// 全局快捷键管理器
///
/// 用的是 Carbon 框架的老接口 RegisterEventHotKey。
/// 为什么不用新接口？因为老接口有一个巨大优势：**不需要辅助功能权限**就能注册全局热键。
/// 这样即使用户还没授权，程序至少能被"叫醒"。
final class HotKeyManager {

    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let callback: () -> Void
    private let id: UInt32

    /// - Parameters:
    ///   - keyCode: 虚拟键码。0x02 = 字母 D
    ///   - modifiers: 修饰键。0x0800 = Option(⌥)，0x0100 = Command(⌘)，0x0200 = Shift
    init?(keyCode: UInt32, modifiers: UInt32, id: UInt32 = 1, callback: @escaping () -> Void) {
        self.callback = callback
        self.id = id

        // 事件回调（C 函数指针，不能捕获外部变量，所以用指针传 self）
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                var pressed = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed) == noErr,
                      pressed.signature == 0x53535949, pressed.id == manager.id else { return OSStatus(eventNotHandledErr) }
                manager.callback()
                return noErr
            },
            1,
            &eventType,
            selfPtr,
            &handlerRef
        )

        guard installStatus == noErr else {
            NSLog("[随手译] 安装热键事件处理器失败，错误码 \(installStatus)")
            return nil
        }

        // 签名 'SSYI' 用于区分本程序注册的热键
        let hotKeyID = EventHotKeyID(signature: OSType(0x53535949), id: id)

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            NSLog("[随手译] 注册热键失败（可能已被其他软件占用），错误码 \(registerStatus)")
            return nil
        }

        NSLog("[随手译] 全局热键 ID %u 注册成功", id)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
