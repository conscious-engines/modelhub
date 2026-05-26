//
//  ExploreFilterToggleView.swift
//  modelhub
//

import AppKit

/// Explore-only toggle that keeps the default landing feed focused on
/// models that are likely to be practical on the current Mac.
final class ExploreFilterToggleView: NSView {
    static let rowHeight: CGFloat = 28

    private let toggleButton: NSButton
    private let detailField: NSTextField

    var onToggle: ((Bool) -> Void)?

    init(width: CGFloat, isOn: Bool, machineProfile: MachineProfile) {
        toggleButton = NSButton(checkboxWithTitle: "Runs on this Mac", target: nil, action: nil)
        toggleButton.state = isOn ? .on : .off

        detailField = NSTextField(labelWithString: "\(machineProfile.chipName) · \(machineProfile.memoryGB) GB")
        detailField.font = NSFont.systemFont(ofSize: 11)
        detailField.textColor = .secondaryLabelColor
        detailField.alignment = .right
        detailField.isBezeled = false
        detailField.isEditable = false
        detailField.drawsBackground = false

        super.init(frame: NSRect(x: 0, y: 0, width: width, height: Self.rowHeight))

        addSubview(toggleButton)
        addSubview(detailField)

        toggleButton.target = self
        toggleButton.action = #selector(toggleChanged(_:))
        toggleButton.font = NSFont.systemFont(ofSize: 12)
        toggleButton.setButtonType(.switch)

        toggleButton.translatesAutoresizingMaskIntoConstraints = false
        detailField.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toggleButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            toggleButton.centerYAnchor.constraint(equalTo: centerYAnchor),

            detailField.leadingAnchor.constraint(greaterThanOrEqualTo: toggleButton.trailingAnchor, constant: 8),
            detailField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            detailField.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) not supported") }

    @objc private func toggleChanged(_ sender: NSButton) {
        onToggle?(sender.state == .on)
    }
}
