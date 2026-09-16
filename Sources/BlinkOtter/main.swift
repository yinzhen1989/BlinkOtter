import AppKit

private enum Theme {
    static let background = NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.12, alpha: 1)
    static let panel = NSColor(calibratedRed: 0.09, green: 0.12, blue: 0.19, alpha: 1)
    static let surface = NSColor(calibratedRed: 0.17, green: 0.22, blue: 0.31, alpha: 1)
    static let mint = NSColor(calibratedRed: 0.48, green: 0.93, blue: 0.81, alpha: 1)
    static let text = NSColor(calibratedRed: 0.95, green: 0.98, blue: 0.98, alpha: 1)
    static let secondary = NSColor(calibratedRed: 0.55, green: 0.65, blue: 0.73, alpha: 1)
}

private final class PassthroughStackView: NSStackView {
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

private final class PlayerWindow: NSWindowController {
    private let video = BOPlayerView(frame: .zero)
    private let playButton = NSButton(title: "▶", target: nil, action: nil)
    private let seekSlider = NSSlider(value: 0, minValue: 0, maxValue: 1, target: nil, action: nil)
    private let timeLabel = NSTextField(labelWithString: "00:00 / 00:00")
    private let titleLabel = NSTextField(labelWithString: "Drop a video here or press ⌘O")
    private let fileLabel = NSTextField(labelWithString: "No video opened")
    private let queueLabel = NSTextField(labelWithString: "READY TO PLAY")
    private let previousButton = NSButton()
    private let nextButton = NSButton()
    private let muteButton = NSButton()
    private let speedButton = NSButton()
    private let subtitleButton = NSButton()
    private let audioButton = NSButton()
    private let volumeSlider = NSSlider(value: 80, minValue: 0, maxValue: 100, target: nil, action: nil)
    private var mpv: BOEngine?
    private var timer: Timer?
    private var playlist: [URL] = []
    private var playlistIndex = 0
    private var welcomeView: NSStackView?

    init() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 690),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.title = "BlinkOtter"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = Theme.background
        window.minSize = NSSize(width: 760, height: 480)
        window.center()
        super.init(window: window)
        buildUI()
        video.onOpen = { [weak self] url in self?.open(url as URL) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in self?.refresh() }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    deinit { timer?.invalidate() }

    private func panel(_ color: NSColor) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        view.layer?.backgroundColor = color.cgColor
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }
    private func icon(_ size: CGFloat) -> NSImageView {
        let image = Bundle.main.path(forResource: "BlinkOtter-1024", ofType: "png")
            .flatMap { NSImage(contentsOfFile: $0) } ?? NSImage()
        let view = NSImageView(image: image)
        view.imageScaling = .scaleProportionallyUpOrDown
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: size).isActive = true
        view.heightAnchor.constraint(equalToConstant: size).isActive = true
        return view
    }
    private func style(_ button: NSButton, symbol: String, fallback: String, tooltip: String,
                       size: CGFloat = 36, prominent: Bool = false) {
        if let image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip) {
            button.image = image
            button.imagePosition = .imageOnly
            button.title = ""
        } else { button.title = fallback }
        button.toolTip = tooltip
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = size / 2
        button.layer?.backgroundColor = (prominent ? Theme.mint : Theme.surface).cgColor
        button.contentTintColor = prominent ? Theme.background : Theme.text
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: size).isActive = true
        button.heightAnchor.constraint(equalToConstant: size).isActive = true
    }
    private func symbol(_ name: String, fallback: String, tooltip: String,
                        action: Selector, size: CGFloat = 36) -> NSButton {
        let button = NSButton(title: fallback, target: self, action: action)
        style(button, symbol: name, fallback: fallback, tooltip: tooltip, size: size)
        return button
    }
    private func textButton(_ text: String, action: Selector, width: CGFloat, accent: Bool = false) -> NSButton {
        let button = NSButton(title: text, target: self, action: action)
        button.font = .systemFont(ofSize: 12, weight: .semibold)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 11
        button.layer?.backgroundColor = (accent ? Theme.mint : Theme.surface).cgColor
        button.contentTintColor = accent ? Theme.background : Theme.text
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
        return button
    }
    private func buildUI() {
        guard let content = window?.contentView else { return }
        content.wantsLayer = true
        content.layer?.backgroundColor = Theme.background.cgColor
        let header = panel(Theme.panel)
        let stage = panel(Theme.background)
        let controls = panel(Theme.panel)
        content.addSubview(header)
        content.addSubview(stage)
        content.addSubview(controls)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            header.topAnchor.constraint(equalTo: content.topAnchor),
            header.heightAnchor.constraint(equalToConstant: 76),
            stage.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stage.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stage.topAnchor.constraint(equalTo: header.bottomAnchor),
            stage.bottomAnchor.constraint(equalTo: controls.topAnchor),
            controls.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            controls.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            controls.heightAnchor.constraint(equalToConstant: 118)
        ])

        let brand = NSTextField(labelWithString: "BlinkOtter")
        brand.font = .systemFont(ofSize: 18, weight: .bold)
        brand.textColor = Theme.text
        let brandRow = NSStackView(views: [icon(34), brand])
        brandRow.spacing = 9
        brandRow.alignment = .centerY
        brandRow.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(brandRow)
        fileLabel.font = .systemFont(ofSize: 13, weight: .medium)
        fileLabel.textColor = Theme.text
        fileLabel.lineBreakMode = .byTruncatingMiddle
        queueLabel.font = .systemFont(ofSize: 10, weight: .bold)
        queueLabel.textColor = Theme.secondary
        let fileInfo = NSStackView(views: [fileLabel, queueLabel])
        fileInfo.orientation = .vertical
        fileInfo.alignment = .leading
        fileInfo.spacing = 2
        fileInfo.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(fileInfo)
        let openButton = textButton("＋  Open video", action: #selector(openPanel), width: 132, accent: true)
        header.addSubview(openButton)
        NSLayoutConstraint.activate([
            brandRow.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 86),
            brandRow.centerYAnchor.constraint(equalTo: header.centerYAnchor, constant: 8),
            fileInfo.leadingAnchor.constraint(greaterThanOrEqualTo: brandRow.trailingAnchor, constant: 24),
            fileInfo.centerYAnchor.constraint(equalTo: brandRow.centerYAnchor),
            fileInfo.trailingAnchor.constraint(equalTo: openButton.leadingAnchor, constant: -20),
            fileLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            openButton.trailingAnchor.constraint(equalTo: header.trailingAnchor, constant: -22),
            openButton.centerYAnchor.constraint(equalTo: brandRow.centerYAnchor)
        ])

        video.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(video)
        NSLayoutConstraint.activate([
            video.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
            video.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
            video.topAnchor.constraint(equalTo: stage.topAnchor),
            video.bottomAnchor.constraint(equalTo: stage.bottomAnchor)
        ])
        titleLabel.stringValue = "Your screen, your story."
        titleLabel.font = .systemFont(ofSize: 24, weight: .bold)
        titleLabel.textColor = Theme.text
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let hint = NSTextField(labelWithString: "Drop a video here or choose one to begin")
        hint.font = .systemFont(ofSize: 14)
        hint.textColor = Theme.secondary
        hint.alignment = .center
        let formats = NSTextField(labelWithString: "MP4  ·  MKV  ·  MOV  ·  AVI  ·  WEBM  + more")
        formats.font = .systemFont(ofSize: 11, weight: .medium)
        formats.textColor = Theme.secondary
        formats.alignment = .center
        let welcome = PassthroughStackView(views: [icon(116), titleLabel, hint, formats])
        welcome.orientation = .vertical
        welcome.alignment = .centerX
        welcome.spacing = 13
        welcome.translatesAutoresizingMaskIntoConstraints = false
        stage.addSubview(welcome)
        welcomeView = welcome
        NSLayoutConstraint.activate([
            welcome.centerXAnchor.constraint(equalTo: stage.centerXAnchor),
            welcome.centerYAnchor.constraint(equalTo: stage.centerYAnchor)
        ])

        seekSlider.target = self
        seekSlider.action = #selector(seek)
        seekSlider.isContinuous = false
        seekSlider.trackFillColor = Theme.mint
        timeLabel.textColor = Theme.secondary
        timeLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let timeline = NSStackView(views: [seekSlider, timeLabel])
        timeline.alignment = .centerY
        timeline.spacing = 12
        timeline.translatesAutoresizingMaskIntoConstraints = false
        seekSlider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        controls.addSubview(timeline)

        previousButton.target = self
        previousButton.action = #selector(previousFile)
        style(previousButton, symbol: "backward.end.fill", fallback: "⏮", tooltip: "Previous video")
        nextButton.target = self
        nextButton.action = #selector(nextFile)
        style(nextButton, symbol: "forward.end.fill", fallback: "⏭", tooltip: "Next video")
        let back = symbol("gobackward.10", fallback: "↶", tooltip: "Back 10 seconds", action: #selector(rewindTen))
        let ahead = symbol("goforward.10", fallback: "↷", tooltip: "Forward 10 seconds", action: #selector(forwardTen))
        playButton.target = self
        playButton.action = #selector(togglePause)
        style(playButton, symbol: "play.fill", fallback: "▶", tooltip: "Play or pause", size: 48, prominent: true)
        muteButton.target = self
        muteButton.action = #selector(toggleMute)
        style(muteButton, symbol: "speaker.wave.2.fill", fallback: "♫", tooltip: "Mute audio", size: 32)
        volumeSlider.target = self
        volumeSlider.action = #selector(changeVolume)
        volumeSlider.trackFillColor = Theme.mint
        volumeSlider.translatesAutoresizingMaskIntoConstraints = false
        volumeSlider.widthAnchor.constraint(equalToConstant: 86).isActive = true
        speedButton.target = self
        speedButton.action = #selector(showSpeedMenu)
        styleText(speedButton, title: "1×", width: 55)
        subtitleButton.target = self
        subtitleButton.action = #selector(showSubtitleMenu)
        styleText(subtitleButton, title: "CC", width: 38)
        subtitleButton.toolTip = "Subtitle tracks"
        audioButton.target = self
        audioButton.action = #selector(showAudioMenu)
        style(audioButton, symbol: "waveform", fallback: "♪", tooltip: "Audio tracks", size: 34)
        let full = symbol("arrow.up.left.and.arrow.down.right", fallback: "⛶", tooltip: "Full screen",
                          action: #selector(fullScreen), size: 34)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = NSStackView(views: [previousButton, back, playButton, ahead, nextButton,
                                      spacer, muteButton, volumeSlider, speedButton, subtitleButton, audioButton, full])
        row.alignment = .centerY
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false
        controls.addSubview(row)
        NSLayoutConstraint.activate([
            timeline.leadingAnchor.constraint(equalTo: controls.leadingAnchor, constant: 25),
            timeline.trailingAnchor.constraint(equalTo: controls.trailingAnchor, constant: -25),
            timeline.topAnchor.constraint(equalTo: controls.topAnchor, constant: 12),
            row.leadingAnchor.constraint(equalTo: timeline.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: timeline.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: controls.bottomAnchor, constant: -17),
            spacer.widthAnchor.constraint(greaterThanOrEqualToConstant: 12)
        ])
        updatePlaylistControls()
    }
    private func styleText(_ button: NSButton, title: String, width: CGFloat) {
        button.title = title
        button.font = .systemFont(ofSize: 12, weight: .bold)
        button.isBordered = false
        button.wantsLayer = true
        button.layer?.cornerRadius = 11
        button.layer?.backgroundColor = Theme.surface.cgColor
        button.contentTintColor = Theme.text
        button.translatesAutoresizingMaskIntoConstraints = false
        button.widthAnchor.constraint(equalToConstant: width).isActive = true
        button.heightAnchor.constraint(equalToConstant: 34).isActive = true
    }

    func open(_ url: URL) { openPlaylist([url]) }
    private func openPlaylist(_ urls: [URL]) {
        guard let first = urls.first else { return }
        playlist = urls
        playlistIndex = 0
        load(first)
    }
    private func load(_ url: URL) {
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
        welcomeView?.isHidden = true
        fileLabel.stringValue = url.lastPathComponent
        window?.title = "\(url.lastPathComponent) — BlinkOtter"
        updatePlaylistControls()
    }
    private func updatePlaylistControls() {
        previousButton.isEnabled = playlistIndex > 0
        nextButton.isEnabled = playlistIndex + 1 < playlist.count
        queueLabel.stringValue = playlist.isEmpty ? "READY TO PLAY" :
            (playlist.count == 1 ? "NOW PLAYING" : "VIDEO \(playlistIndex + 1) OF \(playlist.count)")
    }
    @objc func openPanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = []
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK { openPlaylist(panel.urls) }
    }
    @objc func previousFile() {
        guard playlistIndex > 0 else { return }
        playlistIndex -= 1
        load(playlist[playlistIndex])
    }
    @objc func nextFile() {
        guard playlistIndex + 1 < playlist.count else { return }
        playlistIndex += 1
        load(playlist[playlistIndex])
    }
    @objc func togglePause() { mpv?.togglePause() }
    @objc func seek() {
        guard let mpv, mpv.duration() > 0 else { return }
        mpv.seek(to: seekSlider.doubleValue * mpv.duration())
    }
    @objc func rewindTen() { jump(-10) }
    @objc func forwardTen() { jump(10) }
    @objc func fullScreen() { window?.toggleFullScreen(nil) }
    func jump(_ seconds: Int) { mpv?.jump(by: Int32(seconds)) }
    @objc func changeVolume() { mpv?.setVolume(volumeSlider.doubleValue) }
    @objc func toggleMute() { mpv?.toggleMute() }

    @objc func showSpeedMenu() {
        guard let mpv else { return }
        let menu = NSMenu()
        for rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0] {
            let item = NSMenuItem(title: String(format: "%g×", rate), action: #selector(chooseSpeed(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: rate)
            item.state = abs(mpv.speed() - rate) < 0.01 ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: speedButton.bounds.height), in: speedButton)
    }
    @objc private func chooseSpeed(_ item: NSMenuItem) {
        guard let number = item.representedObject as? NSNumber else { return }
        mpv?.setSpeed(number.doubleValue)
        speedButton.title = String(format: "%g×", number.doubleValue)
    }
    @objc func showSubtitleMenu() {
        guard let mpv else { return }
        let menu = NSMenu()
        let off = NSMenuItem(title: "Subtitles off", action: #selector(chooseSubtitle(_:)), keyEquivalent: "")
        off.target = self
        off.representedObject = NSNumber(value: -1)
        off.state = mpv.selectedSubtitleTrack() < 0 ? .on : .off
        menu.addItem(off)
        let count = mpv.subtitleTrackCount()
        if count > 0 { menu.addItem(.separator()) }
        for index in 0..<count {
            let id = mpv.subtitleTrackID(at: index)
            let item = NSMenuItem(title: mpv.subtitleTrackLabel(at: index), action: #selector(chooseSubtitle(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: id)
            item.state = id == mpv.selectedSubtitleTrack() ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: subtitleButton.bounds.height), in: subtitleButton)
    }
    @objc private func chooseSubtitle(_ item: NSMenuItem) {
        guard let number = item.representedObject as? NSNumber else { return }
        mpv?.setSubtitleTrack(number.intValue)
    }
    @objc func showAudioMenu() {
        guard let mpv else { return }
        let menu = NSMenu()
        let count = mpv.audioTrackCount()
        if count == 0 { menu.addItem(withTitle: "No audio tracks", action: nil, keyEquivalent: "") }
        for index in 0..<count {
            let id = mpv.audioTrackID(at: index)
            let item = NSMenuItem(title: mpv.audioTrackLabel(at: index), action: #selector(chooseAudio(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: id)
            item.state = id == mpv.selectedAudioTrack() ? .on : .off
            menu.addItem(item)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: audioButton.bounds.height), in: audioButton)
    }
    @objc private func chooseAudio(_ item: NSMenuItem) {
        guard let number = item.representedObject as? NSNumber else { return }
        mpv?.setAudioTrack(number.intValue)
    }

    private func refresh() {
        guard let mpv else { return }
        let position = mpv.timePosition()
        let duration = mpv.duration()
        if duration > 0 { seekSlider.doubleValue = min(1, max(0, position / duration)) }
        timeLabel.stringValue = "\(clock(position)) / \(clock(duration))"
        let paused = mpv.isPaused()
        playButton.image = NSImage(systemSymbolName: paused ? "play.fill" : "pause.fill",
                                   accessibilityDescription: paused ? "Play" : "Pause")
        playButton.toolTip = paused ? "Play" : "Pause"
        let muted = mpv.isMuted()
        muteButton.image = NSImage(systemSymbolName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                                   accessibilityDescription: muted ? "Unmute" : "Mute")
        muteButton.toolTip = muted ? "Unmute audio" : "Mute audio"
        volumeSlider.doubleValue = mpv.volume()
        speedButton.title = String(format: "%g×", mpv.speed())
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
        if let path = Bundle.main.path(forResource: "BlinkOtter-1024", ofType: "png"),
           let image = NSImage(contentsOfFile: path) { NSApp.applicationIconImage = image }
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
        fileMenu.addItem(withTitle: "Open Videos…", action: #selector(PlayerWindow.openPanel), keyEquivalent: "o").target = player
        fileMenu.addItem(.separator())
        let previous = fileMenu.addItem(withTitle: "Previous Video", action: #selector(PlayerWindow.previousFile), keyEquivalent: "[")
        previous.target = player
        previous.keyEquivalentModifierMask = []
        let next = fileMenu.addItem(withTitle: "Next Video", action: #selector(PlayerWindow.nextFile), keyEquivalent: "]")
        next.target = player
        next.keyEquivalentModifierMask = []
        fileItem.submenu = fileMenu
        main.addItem(fileItem)
        let playbackItem = NSMenuItem()
        let playbackMenu = NSMenu(title: "Playback")
        for (name, selector, key) in [
            ("Play / Pause", #selector(PlayerWindow.togglePause), " "),
            ("Back 10 Seconds", #selector(PlayerWindow.rewindTen), "j"),
            ("Forward 10 Seconds", #selector(PlayerWindow.forwardTen), "l"),
            ("Mute / Unmute", #selector(PlayerWindow.toggleMute), "m"),
            ("Full Screen", #selector(PlayerWindow.fullScreen), "f")
        ] {
            let item = playbackMenu.addItem(withTitle: name, action: selector, keyEquivalent: key)
            item.target = player
            item.keyEquivalentModifierMask = []
        }
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
