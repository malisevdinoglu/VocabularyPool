//
//  DesignSystem.swift
//  VocabularyPool
//
//  Design tokens, typography scale, spacing grid, reusable components.
//  Every visual decision in the app flows from here.
//

import SwiftUI

// MARK: - Design System Namespace

enum DS {

    // MARK: Colors
    enum Colors {
        /// Indigo 600 — primary actions, EN→TR mode
        static let primary   = Color(red: 0.310, green: 0.275, blue: 0.898)
        /// Teal 600 — TR→EN mode, secondary CTAs
        static let accent    = Color(red: 0.051, green: 0.580, blue: 0.533)
        /// Green 600 — correct answers, goals met
        static let success   = Color(red: 0.086, green: 0.639, blue: 0.290)
        /// Amber 600 — listening mode, partial progress, show-answer
        static let warning   = Color(red: 0.851, green: 0.471, blue: 0.024)
        /// Red 600 — wrong answers, delete
        static let danger    = Color(red: 0.863, green: 0.149, blue: 0.149)
        /// Purple 600 — total / summary accent
        static let purple    = Color(red: 0.545, green: 0.361, blue: 0.965)
        /// White text on any colored background
        static let onColor   = Color.white

        // Semantic aliases
        static var engToTr:  Color { primary }
        static var trToEng:  Color { accent  }
        static var listening: Color { warning }
        static var total:    Color { purple  }
    }

    // MARK: Spacing — 4pt grid
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    // MARK: Corner Radius
    enum Radius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

// MARK: - Typography Scale

extension Font {
    /// 34pt bold rounded — quiz question word, hero numbers
    static let dsDisplay  = Font.system(size: 34, weight: .bold,     design: .rounded)
    /// 22pt bold rounded — screen titles, section headers
    static let dsTitle    = Font.system(size: 22, weight: .bold,     design: .rounded)
    /// 17pt semibold — card titles, button labels
    static let dsHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    /// 16pt regular — body content
    static let dsBody     = Font.system(size: 16, weight: .regular,  design: .default)
    /// 15pt medium — secondary info, callouts
    static let dsCallout  = Font.system(size: 15, weight: .medium,   design: .default)
    /// 12pt regular — labels, timestamps, badges
    static let dsCaption  = Font.system(size: 12, weight: .regular,  design: .default)
}

// MARK: - Reusable Components

/// Colored square icon container — iOS Settings style
struct DSIconBadge: View {
    let systemImage: String
    let color: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm - 2))
    }
}

/// Full-width primary action button
struct DSPrimaryButton: View {
    let title: String
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.dsHeadline)
                .frame(maxWidth: .infinity)
                .padding(DS.Spacing.md)
                .background(isDisabled ? Color.secondary.opacity(0.25) : DS.Colors.primary)
                .foregroundStyle(DS.Colors.onColor)
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        }
        .disabled(isDisabled)
    }
}

/// Capsule pill chip — used in count selector, day picker, etc.
struct DSChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.dsCallout)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(isSelected ? DS.Colors.primary : Color(uiColor: .secondarySystemBackground))
                .foregroundStyle(isSelected ? DS.Colors.onColor : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}
