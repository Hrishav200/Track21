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

    let colors = ["FFB6A3", "6BB6FF", "5DD167", "FFD700", "FF6B9D", "A78BFA"]
    let colorNames = ["Coral", "Blue", "Green", "Gold", "Pink", "Purple"]

    var body: some View {
        NavigationView {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        previewCard
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
                    .disabled(name.isEmpty || goal.isEmpty || isIntervalReminderEmpty)
                }
            }
        }
    }

    // MARK: - Live preview

    /// Shows the habit card exactly as it'll appear on Home, updating live
    /// as the user types and picks a color — makes the form feel like it's
    /// building something real rather than filling out a spreadsheet.
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("PREVIEW")
            HabitCardView(
                habit: Habit(name: name.isEmpty ? "Habit name" : name, goal: goal.isEmpty ? "Your goal" : goal, color: selectedColor),
                isCompleted: false
            )
            .opacity(name.isEmpty ? 0.6 : 1)
            .animation(.easeInOut(duration: 0.15), value: selectedColor)
            .animation(.easeInOut(duration: 0.15), value: name.isEmpty)
        }
    }

    // MARK: - Details

    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("HABIT DETAILS")
            TextField("Habit name", text: $name)
                .textFieldStyle(.roundedBorder)
            TextField("Goal (e.g., 30min, 5km)", text: $goal)
                .textFieldStyle(.roundedBorder)
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
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
            name: name,
            goal: goal,
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

#Preview {
    AddHabitView(viewModel: HabitViewModel(), authService: AuthService())
}
