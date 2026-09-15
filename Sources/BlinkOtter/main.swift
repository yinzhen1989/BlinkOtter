import AppKit

private final class PlayerWindow: NSWindowController {
    private let video = BOPlayerView(frame: .zero)
    private let playButton = NSButton(title: "▶", target: nil, action: nil)
    private let seekSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
    private let titleLabel = NSTextField(labelWithString: "Drop a video here or press ⌘O")
    private var mpv: BOEngine?
    private var timer: Timer?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 600),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "BlinkOtter"
        window.minSize = NSSize(width: 520, height: 330)
        window.center()
        super.init(window: window)
        buildUI()
        video.onOpen = { [weak self] url in self?.open(url as URL) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor.black.cgColor
        video.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(video)
        let controls = NSVisualEffectView()
        controls.material = .hudWindow
        controls.blendingMode = .withinWindow
        controls.state = .active
        controls.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(controls)
        let openButton = NSButton(title: "Open", target: self, action: #selector(openPanel))
        playButton.target = self
        playButton.action = #selector(togglePause)
        playButton.bezelStyle = .inline
        seekSlider.target = self
        seekSlider.action = #selector(seek)
        timeLabel.textColor = .secondaryLabelColor
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.lineBreakMode = .byTruncatingMiddle
        let fullScreenButton = NSButton(title: "⛶", target: self, action: #selector(fullScreen))
        let row = NSStackView(views: [openButton, playButton, seekSlider, timeLabel, fullScreenButton])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 10
        row.translatesAutoresizingMaskIntoConstraints = false
        seekSlider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controls.addSubview(row)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            video.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            video.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            video.topAnchor.constraint(equalTo: content.topAnchor),
            video.bottomAnchor.constraint(equalTo: controls.topAnchor),
            controls.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            controls.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            controls.heightAnchor.constraint(equalToConstant: 62),
            row.leadingAnchor.constraint(equalTo: controls.leadingAnchor, constant: 14),
            row.trailingAnchor.constraint(equalTo: controls.trailingAnchor, constant: -14),
            row.centerYAnchor.constraint(equalTo: controls.centerYAnchor),
            titleLabel.centerXAnchor.constraint(equalTo: video.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: video.centerYAnchor),
            titleLabel.widthAnchor.constraint(lessThanOrEqualTo: video.widthAnchor, multiplier: 0.8)
        ])
    }

    func open(_ url: URL) {
        window?.makeKeyAndOrderFront(nil)
        if mpv == nil {
            mpv = BOEngine(view: video)
            if mpv == nil {
                NSAlert(error: NSError(domain: "BlinkOtter", code: 1,
                                       userInfo: [NSLocalizedDescriptionKey: "The mpv playback engine could not start."])).runModal()
                return
            }
        }
        guard mpv?.loadFile(url.path) == true else { return }
        titleLabel.isHidden = true
        window?.title = "\(url.lastPathComponent) — BlinkOtter"
    }

    @objc func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url { open(url) }
    }
    @objc func togglePause() { mpv?.togglePause() }
    @objc func seek() {
        guard let mpv, mpv.duration() > 0 else { return }
        mpv.seek(to: seekSlider.doubleValue * mpv.duration())
    }
    @objc func fullScreen() { window?.toggleFullScreen(nil) }
    func jump(_ seconds: Int) { mpv?.jump(by: Int32(seconds)) }

    private func refresh() {
        guard let mpv else { return }
        let position = mpv.timePosition()
        let duration = mpv.duration()
        if duration > 0 { seekSlider.doubleValue = min(1, max(0, position / duration)) }
        timeLabel.stringValue = "\(clock(position)) / \(clock(duration))"
        playButton.title = mpv.isPaused() ? "▶" : "Ⅱ"
    }
    private func clock(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.isFinite ? seconds : 0))
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, (total / 60) % 60, total % 60)
                             : String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    private var player: PlayerWindow?
    private var openedURLs: [URL] = []
    func applicationDidFinishLaunching(_ notification: Notification) {
        player = PlayerWindow()
        player?.showWindow(nil)
        if let url = openedURLs.last { player?.open(url) }
        makeMenu()
    }
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        let url = URL(fileURLWithPath: filename)
        if let player { player.open(url) } else { openedURLs.append(url) }
        return true
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    private func makeMenu() {
        let main = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit BlinkOtter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        main.addItem(appItem)
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…", action: #selector(PlayerWindow.openPanel), keyEquivalent: "o").target = player
        fileItem.submenu = fileMenu
        main.addItem(fileItem)
        let playbackItem = NSMenuItem()
        let playbackMenu = NSMenu(title: "Playback")
        playbackMenu.addItem(withTitle: "Play / Pause", action: #selector(PlayerWindow.togglePause), keyEquivalent: " ").target = player
        playbackMenu.addItem(withTitle: "Full Screen", action: #selector(PlayerWindow.fullScreen), keyEquivalent: "f").target = player
        playbackItem.submenu = playbackMenu
        main.addItem(playbackItem)
        NSApp.mainMenu = main
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
private let delegate = AppDelegate()
application.delegate = delegate
application.run()
