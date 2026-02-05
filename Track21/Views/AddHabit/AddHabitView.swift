
//
//  AddhabitView.swift
//  Track21
//
//  Created by Hrishav Sunar on 28/1/2026.
//
import SwiftUI
internal import Auth

struct AddHabitView: View {
    var viewModel: HabitViewModel
    var authService: AuthService
    @Environment(\.dismiss) var dismiss
    
    @State private var habitName = ""
    @State private var goal = ""
    @State private var selectedFrequency = HabitFrequency.daily
    @State private var startDate = Date()
    @State private var reminderTime = Date()
    @State private var reminderEnabled = false
    @State private var selectedColor = "5DD167"
    @State private var showDatePicker = false
    
    let colors = ["FFB6A3", "6BB6FF", "FFD93D", "FF6B6B", "C77DFF", "5DD167"]
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "F5F5F5").edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 24) {
                        InputSection(title: "Name your Habit", text: $habitName, placeholder: "Enter a habit you want to track")
                        
                        InputSection(title: "Set Goal", text: $goal, placeholder: "Set the goal you want to achieve")
                        
                        FrequencySection(selectedFrequency: $selectedFrequency)
                        
                        DateSection(startDate: $startDate, showDatePicker: $showDatePicker)
                        
                        ReminderSection(reminderTime: $reminderTime, reminderEnabled: $reminderEnabled)
                        
                        ColorPickerSection(selectedColor: $selectedColor, colors: colors)
                        
                        Button(action: {
                            let habit = Habit(
                                id: UUID(),
                                userId: authService.currentUser?.id,
                                name: habitName,
                                goal: goal,
                                colorHex: selectedColor,
                                frequency: selectedFrequency,
                                startDate: startDate,
                                reminderTime: reminderEnabled ? reminderTime : nil,
                                reminderEnabled: reminderEnabled,
                                completedDates: [],
                                createdAt: Date(),
                                updatedAt: Date(),
                                deletedAt: nil,
                                syncStatus: .pending
                            )
                            viewModel.addHabit(habit)
                            
                            // Auto-sync after adding
                            Task {
                                if let userId = authService.currentUser?.id {
                                    await viewModel.syncWithCloud(userId: userId)
                                }
                            }
                            
                            dismiss()
                        }) {
                            Text("Create Habit")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "5DD167"))
                                .cornerRadius(12)
                        }
                        .disabled(habitName.isEmpty)
                        .opacity(habitName.isEmpty ? 0.5 : 1)
                    }
                    .padding()
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("Add Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }
}

// MARK: - Helper Components (Keep these from previous code)
struct InputSection: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
            
            HStack {
                TextField(placeholder, text: $text)
                    .font(.system(size: 14))
                
                Image(systemName: "pencil")
                    .foregroundColor(.gray)
                    .font(.system(size: 14))
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
        }
    }
}

struct FrequencySection: View {
    @Binding var selectedFrequency: HabitFrequency
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency")
                .font(.system(size: 14, weight: .medium))
            
            HStack(spacing: 12) {
                ForEach(HabitFrequency.allCases, id: \.self) { frequency in
                    FrequencyButton(
                        title: frequency.rawValue,
                        isSelected: selectedFrequency == frequency,
                        action: { selectedFrequency = frequency }
                    )
                }
            }
        }
    }
}

struct FrequencyButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "circle.inset.filled" : "circle")
                    .font(.system(size: 12))
                Text(title)
                    .font(.system(size: 12))
            }
            .foregroundColor(.black)
        }
    }
}

struct DateSection: View {
    @Binding var startDate: Date
    @Binding var showDatePicker: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Date")
                .font(.system(size: 14, weight: .medium))
            
            Button(action: { showDatePicker.toggle() }) {
                HStack {
                    Text(showDatePicker ? "Select date" : startDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Image(systemName: "calendar")
                        .foregroundColor(.gray)
                }
                .padding()
                .background(Color.white)
                .cornerRadius(8)
            }
            
            if showDatePicker {
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .background(Color.white)
                    .cornerRadius(8)
            }
        }
    }
}

struct ReminderSection: View {
    @Binding var reminderTime: Date
    @Binding var reminderEnabled: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remind me at these times")
                .font(.system(size: 14, weight: .medium))
            
            HStack {
                DatePicker("", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                
                Spacer()
                
                Toggle("", isOn: $reminderEnabled)
                    .labelsHidden()
            }
            .padding()
            .background(Color.white)
            .cornerRadius(8)
        }
    }
}

struct ColorPickerSection: View {
    @Binding var selectedColor: String
    let colors: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose a Color")
                .font(.system(size: 14, weight: .medium))
            
            HStack(spacing: 16) {
                ForEach(colors, id: \.self) { color in
                    Circle()
                        .fill(Color(hex: color))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: selectedColor == color ? 2 : 0)
                        )
                        .onTapGesture {
                            selectedColor = color
                        }
                }
            }
        }
    }
}
