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
    @State private var reminderEnabled: Bool
    @State private var reminderTime: Date

    let colors = ["FFB6A3", "6BB6FF", "5DD167", "FFD700", "FF6B9D", "A78BFA"]
    let colorNames = ["Coral", "Blue", "Green", "Gold", "Pink", "Purple"]

    init(viewModel: HabitViewModel, authService: AuthService, habit: Habit) {
        self.viewModel = viewModel
        self.authService = authService
        self.habit = habit
        _name = State(initialValue: habit.name)
        _goal = State(initialValue: habit.goal)
        _selectedColor = State(initialValue: habit.color)
        _reminderEnabled = State(initialValue: habit.reminderTime != nil)
        _reminderTime = State(initialValue: habit.reminderTime ?? Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date())
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Habit Details") {
                    TextField("Habit name", text: $name)
                    TextField("Goal (e.g., 30min, 5km)", text: $goal)
                }

                Section("Color") {
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

                Section("Daily Reminder") {
                    Toggle("Remind me to log this habit", isOn: $reminderEnabled.animation(.easeInOut(duration: 0.15)))
                        .tint(AppTheme.primary)

                    if reminderEnabled {
                        DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
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
                    .disabled(name.isEmpty || goal.isEmpty || !hasChanges)
                }
            }
        }
    }

    private var hasChanges: Bool {
        name != habit.name || goal != habit.goal || selectedColor != habit.color || reminderHasChanges
    }

    private var reminderHasChanges: Bool {
        let newReminderTime = reminderEnabled ? reminderTime : nil
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
        habit.reminderTime = reminderEnabled ? reminderTime : nil
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
