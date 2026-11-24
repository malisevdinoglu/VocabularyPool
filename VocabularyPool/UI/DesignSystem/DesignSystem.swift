//
//  DesignSystem.swift
//  VocabularyPool
//
//  Apple Crafted / Editorial Design System (Light-first, clean Dark Mode support).
//  All colors, surfaces, spacing, radii, typography, and haptics flow from here.
//

import SwiftUI
import UIKit

// MARK: - Design System Namespace

enum DS {

    // MARK: - Adaptive Color Helper
    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }

    // MARK: - Surfaces & Borders
    enum Surfaces {
        /// Primary screen canvas: soft pearl gray in Light, deep obsidian in Dark.
        static let canvas = adaptive(
            light: UIColor(red: 0.969, green: 0.973, blue: 0.980, alpha: 1), // #F7F8FA
            dark:  UIColor(red: 0.055, green: 0.063, blue: 0.082, alpha: 1)  // #0E1015
        )

        /// Elevated card surface: crisp pure white in Light, elevated slate in Dark.
        static let card = adaptive(
            light: UIColor.white,
            dark:  UIColor(red: 0.094, green: 0.106, blue: 0.133, alpha: 1)  // #181B22
        )

        /// Muted surface for text fields, inactive chips, inset tiles.
        static let muted = adaptive(
            light: UIColor(red: 0.941, green: 0.949, blue: 0.965, alpha: 1), // #F0F2F6
            dark:  UIColor(red: 0.133, green: 0.149, blue: 0.184, alpha: 1)  // #22262F
        )

        /// Crisp 1px hairline border for editorial cards.
        static let border = adaptive(
            light: UIColor(red: 0.898, green: 0.910, blue: 0.933, alpha: 1), // #E5E8EE
            dark:  UIColor(red: 0.165, green: 0.184, blue: 0.224, alpha: 1)  // #2A2F39
        )

        /// Soft ambient shadow color.
        static let shadow = adaptive(
            light: UIColor.black.withAlphaComponent(0.045),
            dark:  UIColor.black.withAlphaComponent(0.28)
        )
    }

    // MARK: - Colors (Calm, High-Contrast, Eye-Friendly)
    enum Colors {
        /// Deep Slate Indigo — primary brand accent
        static let primary = adaptive(
            light: UIColor(red: 0.231, green: 0.286, blue: 0.875, alpha: 1), // #3B49DF
            dark:  UIColor(red: 0.431, green: 0.482, blue: 0.965, alpha: 1)  // #6E7BF6
        )

        /// Refined Teal — secondary accent
        static let accent = adaptive(
            light: UIColor(red: 0.051, green: 0.580, blue: 0.533, alpha: 1), // #0D9488
            dark:  UIColor(red: 0.176, green: 0.831, blue: 0.749, alpha: 1)  // #2DD4BF
        )

        /// Emerald — mastery & correct feedback
        static let success = adaptive(
            light: UIColor(red: 0.082, green: 0.502, blue: 0.239, alpha: 1), // #15803D
            dark:  UIColor(red: 0.204, green: 0.827, blue: 0.600, alpha: 1)  // #34D399
        )

        /// Warm Amber — listening & attention
        static let warning = adaptive(
            light: UIColor(red: 0.706, green: 0.325, blue: 0.035, alpha: 1), // #B45309
            dark:  UIColor(red: 0.984, green: 0.749, blue: 0.141, alpha: 1)  // #FBBF24
        )

        /// Muted Crimson — wrong answers, weak flag, destructive actions
        static let danger = adaptive(
            light: UIColor(red: 0.863, green: 0.149, blue: 0.149, alpha: 1), // #DC2626
            dark:  UIColor(red: 0.973, green: 0.443, blue: 0.443, alpha: 1)  // #F87171
        )

        /// Editorial Violet — phrasal verbs & irregular verbs
        static let purple = adaptive(
            light: UIColor(red: 0.427, green: 0.157, blue: 0.851, alpha: 1), // #6D28D9
            dark:  UIColor(red: 0.655, green: 0.545, blue: 0.980, alpha: 1)  // #A78BFA
        )

        /// White text on saturated buttons/badges
        static let onColor = Color.white

        // Semantic aliases preserved for compatibility
        static var engToTr: Color { primary }
        static var trToEng: Color { accent }
        static var listening: Color { warning }
        static var total: Color { purple }
    }

    // MARK: - Spacing — 4pt grid
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 22
    }
}

// MARK: - Typography Scale

extension Font {
    /// 32pt bold rounded — quiz words, hero numbers
    static let dsDisplay  = Font.system(size: 32, weight: .bold, design: .rounded)
    /// 22pt bold rounded — section & card hero titles
    static let dsTitle    = Font.system(size: 22, weight: .bold, design: .rounded)
    /// 17pt semibold — card titles, primary buttons
    static let dsHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    /// 16pt regular — body content
    static let dsBody     = Font.system(size: 16, weight: .regular, design: .default)
    /// 14pt medium — secondary labels, compact meanings
    static let dsCallout  = Font.system(size: 14, weight: .medium, design: .default)
    /// 12pt medium — badges, metadata, timestamps
    static let dsCaption  = Font.system(size: 12, weight: .medium, design: .default)
}

// MARK: - Haptics

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
