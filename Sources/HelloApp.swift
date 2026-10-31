import AppKit
import SwiftUI

/// The person being greeted.
private let name = "Károly"

@main
struct HelloApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("Hello", id: "main") {
            GreetingView()
                .frame(minWidth: 420, minHeight: 300)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 640, height: 380)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Behave like a single-window utility: closing the window quits the app.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

// MARK: - Greeting

struct GreetingView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Re-evaluated every minute so the greeting, colours and date roll over
        // while the window stays open (e.g. at 17:00 or at midnight).
        TimelineView(.everyMinute) { context in
            let theme = Theme(for: context.date)

            ZStack {
                theme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Always a single line: in narrow windows the text shrinks instead of wrapping.
                    Text("\(theme.greeting), \(name)")
                        .font(.greeting(size: 50))
                        .kerning(-0.5)
                        .foregroundStyle(theme.foreground)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)

                    Capsule()
                        .fill(theme.accent.opacity(0.75))
                        .frame(width: 36, height: 2)
                        .padding(.vertical, 14)

                    Text(Self.dateFormatter.string(from: context.date))
                        .font(.system(size: 16, weight: .medium))
                        .kerning(0.16)
                        .foregroundStyle(theme.accent)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: theme)
            .preferredColorScheme(theme.isDark ? .dark : .light)
        }
    }

    /// Hungarian date order with English month and day names, e.g. "2026. October 30., Friday".
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "y. MMMM d., EEEE"
        return formatter
    }()
}

// MARK: - Time-of-day theme

struct Theme: Equatable {
    let greeting: String
    let background: Color
    let foreground: Color
    let accent: Color
    let isDark: Bool

    static let night = Theme(greeting: "Good Night", background: Color(hex: 0x0B1026),
                             foreground: Color(hex: 0xE4E0F5), accent: Color(hex: 0xF4D35E), isDark: true)
    static let morning = Theme(greeting: "Good Morning", background: Color(hex: 0xFFE8D6),
                               foreground: Color(hex: 0x3A2E39), accent: Color(hex: 0xA6480B), isDark: false)
    static let afternoon = Theme(greeting: "Good Afternoon", background: Color(hex: 0xEAF4FB),
                                 foreground: Color(hex: 0x16324F), accent: Color(hex: 0xB8790A), isDark: false)
    static let evening = Theme(greeting: "Good Evening", background: Color(hex: 0x3B2350),
                               foreground: Color(hex: 0xF3E6D8), accent: Color(hex: 0xF2874B), isDark: true)

    init(greeting: String, background: Color, foreground: Color, accent: Color, isDark: Bool) {
        self.greeting = greeting
        self.background = background
        self.foreground = foreground
        self.accent = accent
        self.isDark = isDark
    }

    init(for date: Date) {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<11: self = .morning
        case 11..<17: self = .afternoon
        case 17..<21: self = .evening
        default: self = .night
        }
    }
}

// MARK: - Helpers

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255)
    }
}

extension Font {
    /// Iowan Old Style (bundled with macOS), falling back to the system serif (New York).
    static func greeting(size: CGFloat) -> Font {
        let postScriptName = "IowanOldStyle-Bold"
        if NSFont(name: postScriptName, size: size) != nil {
            return .custom(postScriptName, size: size)
        }
        return .system(size: size, weight: .semibold, design: .serif)
    }
}
