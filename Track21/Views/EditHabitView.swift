//
//  EditHabitView.swift
//  Track21
//
//  Created by Hrishav Sunar on 12/2/2026.
//

import SwiftUI

struct EditHabitView: View {
    @Bindable var viewModel: HabitViewModel
    var authService: AuthService
    let habit: Habit
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var goal: String
    @State private var selectedColor: String

    let colors = ["FFB6A3", "6BB6FF", "5DD167", "FFD700", "FF6B9D", "A78BFA"]
    let colorNames = ["Coral", "Blue", "Green", "Gold", "Pink", "Purple"]

    init(viewModel: HabitViewModel, authService: AuthService, habit: Habit) {
        self.viewModel = viewModel
        self.authService = authService
        self.habit = habit
        _name = State(initialValue: habit.name)
        _goal = State(initialValue: habit.goal)
        _selectedColor = State(initialValue: habit.color)
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
        name != habit.name || goal != habit.goal || selectedColor != habit.color
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
