//
//  AddHabitView.swift
//  Track21
//
//  Created by GOLU on 5/2/2026.
//

import SwiftUI
internal import Auth

struct AddHabitView: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var goal = ""
    @State private var selectedColor = "FFB6A3"
    @State private var customColor = Color(hex: "A78BFA")
    @State private var startDate = Date()
    @State private var reminderEnabled = false
    @State private var reminderMode: ReminderMode = .daily
    @State private var reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var intervalHours = 4
    @State private var intervalMinutes = 0
    @State private var showHabitSuggestions = false
    @State private var showGoalSuggestions = false
    @FocusState private var focusedField: InputField?

    private enum InputField: Hashable {
        case name
        case goal
    }

    private static let habitSuggestions = [
        "Walk", "Exercise", "Drink Water", "Read", "Meditate",
        "Stretch", "Sleep 8 Hours", "No Sugar", "Journal",
        "Take Vitamins", "Practice Gratitude", "Eat Vegetables",
        "Learn Something", "Digital Detox", "Deep Work"
    ]

    private static let goalPresets = [
        "Stay healthy", "Move my body", "Build consistency",
        "Improve my focus", "Reduce stress", "Feel more energized",
        "Sleep better", "Make time for myself", "Learn something new",
        "Support my wellbeing"
    ]

    let colors = ["FFB6A3", "6BB6FF", "5DD167", "FFD700", "FF6B9D", "A78BFA"]
    let colorNames = ["Coral", "Blue", "Green", "Gold", "Pink", "Purple"]

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        introCard
                        detailsCard
                        colorCard
                        startDateCard
                        reminderCard
                        challengeInfoCard
                    }
                    .padding(20)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addHabit()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canAdd || isIntervalReminderEmpty)
                }
            }
            .sheet(isPresented: $showHabitSuggestions) {
                SuggestionPickerSheet(
                    title: "Habit suggestions",
                    subtitle: "Pick one to start — you can still edit it after.",
                    items: Self.habitSuggestions,
                    selected: name,
                    icon: "sparkles"
                ) { picked in
                    name = picked
                    showHabitSuggestions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        focusedField = .goal
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
            .sheet(isPresented: $showGoalSuggestions) {
                SuggestionPickerSheet(
                    title: "Goal suggestions",
                    subtitle: "What does success look like for you?",
                    items: Self.goalPresets,
                    selected: goal,
                    icon: "flag.fill"
                ) { picked in
                    goal = picked
                    showGoalSuggestions = false
                    focusedField = nil
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
            }
        }
    }

    // MARK: - Name and goal

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(AppTheme.primary)
                    .frame(width: 38, height: 38)
                    .background(AppTheme.primary.opacity(0.14))
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Build your next 21 days")
                        .font(.headline)
                    Text("Type your own, or tap View Suggestions for ideas.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(AppTheme.primary.opacity(0.10))
        .cornerRadius(16)
    }

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("YOUR HABIT")
                textFieldRow(
                    icon: "target",
                    prompt: "What do you want to practice?",
                    text: $name,
                    field: .name,
                    submitLabel: .next
                )
                suggestionsButton {
                    focusedField = nil
                    showHabitSuggestions = true
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("YOUR GOAL")
                textFieldRow(
                    icon: "flag",
                    prompt: "What does success look like?",
                    text: $goal,
                    field: .goal,
                    submitLabel: .done
                )
                suggestionsButton {
                    focusedField = nil
                    showGoalSuggestions = true
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private func suggestionsButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.subheadline.weight(.semibold))
                Text("View Suggestions")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 10)
            .foregroundColor(.white)
            .background(AppTheme.primary)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("View Suggestions")
    }

    private func textFieldRow(
        icon: String,
        prompt: String,
        text: Binding<String>,
        field: InputField,
        submitLabel: SubmitLabel
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(AppTheme.primary)
                .frame(width: 22)
            TextField(prompt, text: text)
                .focused($focusedField, equals: field)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .submitLabel(submitLabel)
                .onSubmit {
                    focusedField = field == .name ? .goal : nil
                }
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.65))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .padding(.horizontal, 13)
        .frame(minHeight: 50)
        .background(AppTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focusedField == field ? AppTheme.primary : Color.primary.opacity(0.08), lineWidth: focusedField == field ? 2 : 1)
        )
    }

    private var canAdd: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Color

    private var colorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("BACKGROUND COLOR")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    colorSwatch(color: color, name: colorNames[index])
                }
                customColorSwatch
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    /// The 6 presets are quick shortcuts — this opens the full system color
    /// picker (spectrum, sliders, eyedropper, saved colors) for anything
    /// else, converting the pick to the same hex format habit.color stores.
    private var customColorSwatch: some View {
        let isSelected = !colors.contains(selectedColor)
        return ColorPicker("Custom color", selection: $customColor, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary.opacity(0.55) : Color.clear, lineWidth: 2)
                    .padding(-3)
            )
            .onChange(of: customColor) { _, newValue in
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedColor = newValue.toHex()
                }
            }
            .accessibilityLabel("Custom color")
    }

    private func colorSwatch(color: String, name: String) -> some View {
        let isSelected = selectedColor == color
        return Circle()
            .fill(Color(hex: color))
            .frame(width: 40, height: 40)
            .overlay {
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.bold))
                        .foregroundColor(.white)
                }
            }
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary.opacity(0.55) : Color.clear, lineWidth: 2)
                    .padding(-3)
            )
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.15)) {
                    selectedColor = color
                }
            }
            .accessibilityLabel(name)
    }

    // MARK: - Start date

    private var startDateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("START DATE")
            DatePicker("Start tracking from", selection: $startDate, displayedComponents: .date)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    // MARK: - Reminder

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle(isOn: $reminderEnabled.animation(.easeInOut(duration: 0.15))) {
                VStack(alignment: .leading, spacing: 2) {
                    sectionLabel("REMINDER")
                    Text("Get a notification to log this habit")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .tint(AppTheme.primary)

            if reminderEnabled {
                Picker("Reminder type", selection: $reminderMode) {
                    ForEach(ReminderMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if reminderMode == .daily {
                    DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                } else {
                    intervalPicker
                }
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private var intervalPicker: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remind me every")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 0) {
                Picker("Hours", selection: $intervalHours) {
                    ForEach(0..<24) { hour in
                        Text("\(hour) hr").tag(hour)
                    }
                }
                .pickerStyle(.wheel)

                Picker("Minutes", selection: $intervalMinutes) {
                    ForEach(0..<60) { minute in
                        Text("\(minute) min").tag(minute)
                    }
                }
                .pickerStyle(.wheel)
            }
            .frame(height: 120)

            if isIntervalReminderEmpty {
                Text("Pick at least 1 minute.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var isIntervalReminderEmpty: Bool {
        reminderEnabled && reminderMode == .interval && intervalHours == 0 && intervalMinutes == 0
    }

    // MARK: - Challenge info

    private var challengeInfoCard: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.primary.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(AppTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("21-Day Challenge")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Your habit will be tracked for 21 days starting from \(formattedDate(startDate)). Stay consistent to build a lasting habit!")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .tracking(0.5)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func addHabit() {
        let habit = Habit(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: goal.trimmingCharacters(in: .whitespacesAndNewlines),
            color: selectedColor,
            startDate: startDate,
            userId: authService.currentUser?.id,
            syncStatus: .pending,
            reminderTime: (reminderEnabled && reminderMode == .daily) ? reminderTime : nil,
            reminderIntervalMinutes: (reminderEnabled && reminderMode == .interval)
                ? intervalHours * 60 + intervalMinutes
                : nil
        )
        viewModel.addHabit(habit)

        // Trigger sync after adding
        if let userId = authService.currentUser?.id {
            Task {
                await viewModel.syncWithCloud(userId: userId)
            }
        }

        dismiss()
    }
}

// MARK: - Suggestion picker sheet

private struct SuggestionPickerSheet: View {
    let title: String
    let subtitle: String
    let items: [String]
    let selected: String
    let icon: String
    let onPick: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            Image(systemName: icon)
                                .font(.title3.weight(.semibold))
                                .foregroundColor(.white)
                                .frame(width: 42, height: 42)
                                .background(AppTheme.primary)
                                .clipShape(Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title)
                                    .font(.title3.weight(.bold))
                                Text(subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal, 4)

                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 140), spacing: 10)],
                            spacing: 10
                        ) {
                            ForEach(items, id: \.self) { item in
                                suggestionRow(item)
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func suggestionRow(_ item: String) -> some View {
        let isSelected = selected == item
        return Button {
            onPick(item)
        } label: {
            HStack(spacing: 8) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                Text(item)
                    .font(.subheadline.weight(isSelected ? .semibold : .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundColor(isSelected ? .white : .primary)
            .background(isSelected ? AppTheme.primary : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.clear : AppTheme.primary.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.04), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    AddHabitView(viewModel: HabitViewModel(), authService: AuthService())
}
