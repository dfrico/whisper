import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let toggleRecording = Self(
        "toggleRecording",
        default: .init(.space, modifiers: .option)
    )
    static let commitTranscript = Self(
        "commitTranscript",
        default: .init(.return, modifiers: .option)
    )
}
