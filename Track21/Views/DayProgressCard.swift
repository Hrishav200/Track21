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
    @State private var weekOffset: Int = 0

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

    /// Label showing the week range, e.g. "Jan 20 – Jan 26"
    private var weekRangeLabel: String {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        guard let startOfWeek = calendar.date(byAdding: .day, value: -(weekday - 1), to: today),
              let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: startOfWeek),
              let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return "\(formatter.string(from: weekStart)) – \(formatter.string(from: weekEnd))"
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
                    if !isToday || weekOffset != 0 {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDate = Calendar.current.startOfDay(for: Date())
                                weekOffset = 0
                            }
                        } label: {
                            Text("Back to Today")
                                .font(.caption2)
                                .foregroundColor(AppTheme.primary)
                        }
                    }
                }
            }

            // Week navigation row
            HStack {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        weekOffset -= 1
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppTheme.primary)
                        .frame(width: 28, height: 28)
                }

                Spacer()

                Text(weekRangeLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        weekOffset += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(weekOffset < 0 ? AppTheme.primary : Color.gray.opacity(0.3))
                        .frame(width: 28, height: 28)
                }
                .disabled(weekOffset >= 0)
            }

            WeeklyCalendarView(habit: habit, selectedDate: $selectedDate, weekOffset: weekOffset)
                .gesture(
                    DragGesture(minimumDistance: 30, coordinateSpace: .local)
                        .onEnded { value in
                            let horizontal = value.translation.width
                            let vertical = abs(value.translation.height)
                            guard abs(horizontal) > vertical else { return }
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if horizontal < 0 {
                                    // Swipe left → go to older week
                                    weekOffset -= 1
                                } else if horizontal > 0 && weekOffset < 0 {
                                    // Swipe right → go to newer week (only if not already current)
                                    weekOffset += 1
                                }
                            }
                        }
                )
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
