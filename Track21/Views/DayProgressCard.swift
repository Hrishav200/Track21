//
//  DayProgressCard.swift
//  Track21
//
//  Created by Hrishav Sunar on 22/12/2025.
//

import SwiftUI

struct DayProgressCard: View {
    let habit: Habit?
    @Binding var selectedDate: Date

    private var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter
    }

    private var selectedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, yyyy"
        return formatter
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    if let habit = habit {
                        Text("Day \(habit.currentDay) of 21")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Start: \(dateFormatter.string(from: habit.startDate)) | End: \(dateFormatter.string(from: habit.endDate))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Select a habit")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Tap a habit below to see its progress")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(selectedDateFormatter.string(from: selectedDate))
                        .font(.subheadline)
                    if !isToday {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = Calendar.current.startOfDay(for: Date())
                            }
                        } label: {
                            Text("Back to Today")
                                .font(.caption2)
                                .foregroundColor(AppTheme.primary)
                        }
                    }
                }
            }

            WeeklyCalendarView(habit: habit, selectedDate: $selectedDate)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .offset(y: -50)
    }
}

#Preview {
    DayProgressCard(habit: nil, selectedDate: .constant(Date()))
}
