//
//  DSComponents.swift
//  VocabularyPool
//
//  Reusable Apple Crafted / Editorial UI components.
//

import SwiftUI

// MARK: - Editorial Card Modifier

struct DSCardModifier: ViewModifier {
    var padding: CGFloat = DS.Spacing.md
    var cornerRadius: CGFloat = DS.Radius.lg

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(DS.Surfaces.card)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(DS.Surfaces.border, lineWidth: 1)
            )
            .shadow(color: DS.Surfaces.shadow, radius: 10, x: 0, y: 3)
    }
}

extension View {
    func dsCard(padding: CGFloat = DS.Spacing.md, cornerRadius: CGFloat = DS.Radius.lg) -> some View {
        modifier(DSCardModifier(padding: padding, cornerRadius: cornerRadius))
    }
}

// MARK: - Tactile Spring Button Style

struct DSSpringButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

// MARK: - Primary & Secondary Buttons

struct DSPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var color: Color = DS.Colors.primary
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.dsHeadline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isDisabled ? DS.Surfaces.muted : color)
            .foregroundStyle(isDisabled ? Color.secondary : DS.Colors.onColor)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
        }
        .buttonStyle(DSSpringButtonStyle())
        .disabled(isDisabled)
    }
}

struct DSSecondaryButton: View {
    let title: String
    var systemImage: String? = nil
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                }
                Text(title)
                    .font(.dsHeadline)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(DS.Surfaces.muted)
            .foregroundStyle(tint)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .strokeBorder(DS.Surfaces.border, lineWidth: 1)
            )
        }
        .buttonStyle(DSSpringButtonStyle())
    }
}

// MARK: - Editorial Icon Badge

struct DSIconBadge: View {
    let systemImage: String
    let color: Color
    var size: CGFloat = 34

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(color)
            .frame(width: size, height: size)
            .background(color.opacity(0.11))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
    }
}

// MARK: - Capsule Filter Chip

struct DSChip: View {
    let label: String
    var count: Int? = nil
    var isSelected: Bool
    var accentColor: Color = DS.Colors.primary
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.selection()
            action()
        } label: {
            HStack(spacing: 5) {
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(isSelected ? Color.white.opacity(0.22) : DS.Surfaces.muted)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(isSelected ? accentColor : DS.Surfaces.card)
            .foregroundStyle(isSelected ? DS.Colors.onColor : .primary)
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isSelected ? Color.clear : DS.Surfaces.border, lineWidth: 1)
            )
        }
        .buttonStyle(DSSpringButtonStyle())
    }
}

// MARK: - Section Header

struct DSSectionHeader: View {
    let title: String
    var trailingText: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            if let trailingText {
                Text(trailingText)
                    .font(.dsCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 2)
    }
}

// MARK: - Circular Progress Ring

struct DSProgressRing: View {
    let progress: Double // 0.0 ... 1.0
    var lineWidth: CGFloat = 8
    var size: CGFloat = 68
    var tint: Color = DS.Colors.primary

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.14), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: clamped)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.55, dampingFraction: 0.8), value: clamped)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 5-Dot Mastery Indicator (●●●○○)

struct DSMasteryDots: View {
    let level: Int // 0 ... 5
    var isWeak: Bool = false

    private var filledColor: Color {
        if isWeak { return DS.Colors.danger }
        if level >= 4 { return DS.Colors.success }
        if level >= 2 { return DS.Colors.primary }
        return DS.Colors.warning
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { index in
                Circle()
                    .fill(index <= level ? filledColor : DS.Surfaces.border)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel("Mastery level \(level) of 5")
    }
}

// MARK: - Small Tinted Badge

struct DSBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.11))
            .clipShape(Capsule())
    }
}
