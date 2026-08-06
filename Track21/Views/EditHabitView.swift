//
//  EditHabitView.swift
//  Track21
//
//  Created by Hrishav Sunar on 12/2/2026.
//

import SwiftUI
internal import Auth

struct EditHabitView: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService
    let habit: Habit
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var goal: String
    @State private var selectedColor: String
    @State private var customColor: Color
    @State private var reminderEnabled: Bool
    @State private var reminderMode: ReminderMode
    @State private var reminderTime: Date
    @State private var intervalHours: Int
    @State private var intervalMinutes: Int

    let colors = ["FFB6A3", "6BB6FF", "5DD167", "FFD700", "FF6B9D", "A78BFA"]
    let colorNames = ["Coral", "Blue", "Green", "Gold", "Pink", "Purple"]

    init(viewModel: HabitViewModel, authService: AuthService, habit: Habit) {
        self.viewModel = viewModel
        self.authService = authService
        self.habit = habit
        _name = State(initialValue: habit.name)
        _goal = State(initialValue: habit.goal)
        _selectedColor = State(initialValue: habit.color)
        _customColor = State(initialValue: Color(hex: habit.color))
        _reminderEnabled = State(initialValue: habit.reminderTime != nil || habit.reminderIntervalMinutes != nil)
        _reminderMode = State(initialValue: habit.reminderIntervalMinutes != nil ? .interval : .daily)
        _reminderTime = State(initialValue: habit.reminderTime ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
        _intervalHours = State(initialValue: (habit.reminderIntervalMinutes ?? 240) / 60)
        _intervalMinutes = State(initialValue: (habit.reminderIntervalMinutes ?? 240) % 60)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Habit Details") {
                    TextField("Habit name", text: $name)
                    TextField("Goal (e.g., 30min, 5km)", text: $goal)
                }

                Section("Background Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.primary : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                                .accessibilityLabel(colorNames[index])
                        }
                        customColorSwatch
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Start Date")
                            .font(.headline)
                        Text("Started on \(formattedDate(habit.startDate)) · Day \(habit.currentDay) of 21")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Reminder") {
                    Toggle("Remind me to log this habit", isOn: $reminderEnabled.animation(.easeInOut(duration: 0.15)))
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
            }
            .navigationTitle("Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(name.isEmpty || goal.isEmpty || !hasChanges || isIntervalReminderEmpty)
                }
            }
        }
    }

    /// The 6 presets are quick shortcuts — this opens the full system color
    /// picker for anything else, converting the pick to the same hex format
    /// habit.color already stores.
    private var customColorSwatch: some View {
        let isSelected = !colors.contains(selectedColor)
        return ColorPicker("Custom color", selection: $customColor, supportsOpacity: false)
            .labelsHidden()
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 3)
            )
            .onChange(of: customColor) { _, newValue in
                selectedColor = newValue.toHex()
            }
            .accessibilityLabel("Custom color")
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

            if intervalHours == 0 && intervalMinutes == 0 {
                Text("Pick at least 1 minute.")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }

    private var hasChanges: Bool {
        name != habit.name || goal != habit.goal || selectedColor != habit.color || reminderHasChanges
    }

    private var newReminderTime: Date? {
        (reminderEnabled && reminderMode == .daily) ? reminderTime : nil
    }

    private var newReminderIntervalMinutes: Int? {
        (reminderEnabled && reminderMode == .interval) ? intervalHours * 60 + intervalMinutes : nil
    }

    private var isIntervalReminderEmpty: Bool {
        reminderEnabled && reminderMode == .interval && intervalHours == 0 && intervalMinutes == 0
    }

    private var reminderHasChanges: Bool {
        if newReminderIntervalMinutes != habit.reminderIntervalMinutes {
            return true
        }
        switch (habit.reminderTime, newReminderTime) {
        case (nil, nil):
            return false
        case let (existing?, new?):
            return Calendar.current.dateComponents([.hour, .minute], from: existing) != Calendar.current.dateComponents([.hour, .minute], from: new)
        default:
            return true
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func saveChanges() {
        habit.name = name
        habit.goal = goal
        habit.color = selectedColor
        habit.reminderTime = newReminderTime
        habit.reminderIntervalMinutes = newReminderIntervalMinutes
        habit.updatedAt = Date()
        habit.syncStatus = .pending

        viewModel.updateHabit(habit)

        // Trigger sync after editing
        if let userId = authService.currentUser?.id {
            Task {
                await viewModel.syncWithCloud(userId: userId)
            }
        }

        dismiss()
    }
}
