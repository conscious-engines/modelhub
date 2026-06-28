//
//  SourceToggleRowView.swift
//  modelhub
//

import AppKit

/// A button that changes its cursor to pointingHand and tints on hover.
final class HoverIconButton: NSButton {
    private var trackingArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let options: NSTrackingArea.Options = [.mouseEnteredAndExited, .activeAlways]
        let area = NSTrackingArea(rect: bounds, options: options, owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        contentTintColor = .labelColor
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        contentTintColor = .secondaryLabelColor
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}

/// Row used in the Settings tab to toggle whether a model source
/// (e.g. LM Studio, HuggingFace) is surfaced in the Local tab.
final class SourceToggleRowView: NSView {
    static let rowHeight: CGFloat = 28

    let checkbox: NSButton
    let globeButton: NSButton
    let folderButton: NSButton
    var onToggle: ((Bool) -> Void)?
    private let source: ParsedModel.Source

    init(width: CGFloat, source: ParsedModel.Source, isOn: Bool) {
        self.source = source
        
        checkbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
        checkbox.state = isOn ? .on : .off
        checkbox.isEnabled = true
        
        let titleFont = NSFont.systemFont(ofSize: 13)
        let attrTitle = NSMutableAttributedString(string: source.displayName, attributes: [
            .font: titleFont,
            .foregroundColor: NSColor.labelColor
        ])
        
        if !source.isInstalled {
            let notInstalledAttr = NSAttributedString(string: " (not installed)", attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor
            ])
            attrTitle.append(notInstalledAttr)
        }
        checkbox.attributedTitle = attrTitle

        globeButton = HoverIconButton()
        globeButton.isBordered = false
        globeButton.bezelStyle = .shadowlessSquare
        let globeImg = NSImage(systemSymbolName: "globe", accessibilityDescription: "Open source website")
        globeImg?.isTemplate = true
        globeButton.image = globeImg
        globeButton.imagePosition = .imageOnly
        globeButton.toolTip = "Open \(source.displayName) website"
        globeButton.contentTintColor = .secondaryLabelColor

        folderButton = HoverIconButton()
        folderButton.isBordered = false
        folderButton.bezelStyle = .shadowlessSquare
        let folderImg = NSImage(systemSymbolName: "folder", accessibilityDescription: "Open local models folder")
        folderImg?.isTemplate = true
        folderButton.image = folderImg
        folderButton.imagePosition = .imageOnly
        folderButton.toolTip = "Open local models folder in Finder"
        folderButton.contentTintColor = .secondaryLabelColor

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        var iconView: NSImageView?
        if let image = NSImage(named: source.iconName) {
            let v = NSImageView(image: image)
            v.imageScaling = .scaleProportionallyUpOrDown
            addSubview(v)
            iconView = v
        }

        addSubview(checkbox)
        addSubview(globeButton)
        addSubview(folderButton)
        
        checkbox.target = self
        checkbox.action = #selector(toggled(_:))
        checkbox.translatesAutoresizingMaskIntoConstraints = false

        globeButton.target = self
        globeButton.action = #selector(globeTapped(_:))
        globeButton.translatesAutoresizingMaskIntoConstraints = false

        folderButton.target = self
        folderButton.action = #selector(folderTapped(_:))
        folderButton.translatesAutoresizingMaskIntoConstraints = false

        if let iconView {
            iconView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 16),
                iconView.heightAnchor.constraint(equalToConstant: 16),
                checkbox.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            ])
        } else {
            checkbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16).isActive = true
        }

        NSLayoutConstraint.activate([
            globeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            globeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            globeButton.widthAnchor.constraint(equalToConstant: 16),
            globeButton.heightAnchor.constraint(equalToConstant: 16),

            folderButton.trailingAnchor.constraint(equalTo: globeButton.leadingAnchor, constant: -8),
            folderButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            folderButton.widthAnchor.constraint(equalToConstant: 16),
            folderButton.heightAnchor.constraint(equalToConstant: 16),
            
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: folderButton.leadingAnchor, constant: -8),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    @objc private func toggled(_ sender: NSButton) {
        onToggle?(sender.state == .on)
    }

    @objc private func globeTapped(_ sender: NSButton) {
        NSWorkspace.shared.open(source.homepageURL)
    }

    @objc private func folderTapped(_ sender: NSButton) {
        let path = ModelPaths.rootPath(for: source)
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            try? fm.createDirectory(atPath: path, withIntermediateDirectories: true, attributes: nil)
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
}
