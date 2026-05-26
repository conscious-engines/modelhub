//
//  SourceToggleRowView.swift
//  modelhub
//

import AppKit

/// Row used in the Settings tab to toggle whether a model source
/// (e.g. LM Studio, HuggingFace) is surfaced in the Local tab.
final class SourceToggleRowView: NSView {
    static let rowHeight: CGFloat = 28

    let checkbox: NSButton
    var onToggle: ((Bool) -> Void)?

    init(width: CGFloat, title: String, isOn: Bool, iconName: String? = nil, isEnabled: Bool = true) {
        checkbox = NSButton(checkboxWithTitle: title, target: nil, action: nil)
        checkbox.state = isOn ? .on : .off
        checkbox.isEnabled = isEnabled
        checkbox.font = NSFont.systemFont(ofSize: 13)

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        var iconView: NSImageView?
        if let iconName, let image = NSImage(named: iconName) {
            let v = NSImageView(image: image)
            v.imageScaling = .scaleProportionallyUpOrDown
            addSubview(v)
            iconView = v
        }

        addSubview(checkbox)
        checkbox.target = self
        checkbox.action = #selector(toggled(_:))

        checkbox.translatesAutoresizingMaskIntoConstraints = false

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
            checkbox.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -16),
            checkbox.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    @objc private func toggled(_ sender: NSButton) {
        onToggle?(sender.state == .on)
    }
}
