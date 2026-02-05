//
//  AddHabitView.swift
//  Track21
//
//  Created by GOLU on 5/2/2026.
//

import SwiftUI
import SwiftData

struct AddHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var goal = ""
    @State private var selectedColor = "FFB6A3"
    @State private var startDate = Date()
    
    let colors = ["FFB6A3", "6BB6FF", "5DD167", "FFD700", "FF6B9D", "A78BFA"]
    let colorNames = ["Coral", "Blue", "Green", "Gold", "Pink", "Purple"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Habit Details") {
                    TextField("Habit name", text: $name)
                    TextField("Goal (e.g., 30min, 5km)", text: $goal)
                }
                
                Section("Start Date") {
                    DatePicker("Start tracking from", selection: $startDate, displayedComponents: .date)
                }
                
                Section("Color") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                        ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                            Circle()
                                .fill(Color(hex: color))
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(selectedColor == color ? Color.black : Color.clear, lineWidth: 3)
                                )
                                .onTapGesture {
                                    selectedColor = color
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("21-Day Challenge")
                            .font(.headline)
                        Text("Your habit will be tracked for 21 days starting from \(formattedDate(startDate)). Stay consistent to build a lasting habit!")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
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
                    .disabled(name.isEmpty || goal.isEmpty)
                }
            }
        }
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
            startDate: startDate
        )
        modelContext.insert(habit)
        dismiss()
    }
}

#Preview {
    AddHabitView()
}
