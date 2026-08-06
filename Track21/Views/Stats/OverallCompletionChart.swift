//
//  OverallCompletionChart.swift
//  Track21
//
//  A donut breakdown of Completed/Frozen/Missed across every habit's
//  elapsed days — the "All" overview's headline graph. Deliberately a
//  different chart shape (SectorMark) from the per-habit BarMark weekly
//  chart and the manual journey grid, so switching to "All" reads as its
//  own view rather than a smaller copy of a single habit's stats.
//

import SwiftUI
import Charts

private struct StatusSlice: Identifiable {
    let id: String
    let label: String
    let count: Int
    let color: Color
}

struct OverallCompletionChart: View {
    let habits: [Habit]

    private var counts: StatsAggregation.DayStatusCounts {
        StatsAggregation.dayStatusCounts(for: habits)
    }

    private var slices: [StatusSlice] {
        [
            StatusSlice(id: "completed", label: "Done", count: counts.completed, color: AppTheme.primary),
            StatusSlice(id: "frozen", label: "Frozen", count: counts.frozen, color: AppTheme.frozen),
            StatusSlice(id: "missed", label: "Missed", count: counts.missed, color: AppTheme.missed)
        ].filter { $0.count > 0 }
    }

    private var onTrackPercent: Int {
        guard counts.total > 0 else { return 0 }
        return Int((Double(counts.completed + counts.frozen) / Double(counts.total) * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overall Consistency")
                .font(.headline)

            if counts.total == 0 {
                Text("Complete a day to see your breakdown here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 150, alignment: .center)
            } else {
                HStack(spacing: 24) {
                    donut
                    legend
                }
            }
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(16)
    }

    private var donut: some View {
        Chart(slices) { slice in
            SectorMark(
                angle: .value("Days", slice.count),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .foregroundStyle(slice.color)
            .cornerRadius(4)
        }
        .chartLegend(.hidden)
        .frame(width: 140, height: 140)
        .overlay {
            VStack(spacing: 0) {
                Text("\(onTrackPercent)%")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("on track")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(onTrackPercent) percent on track")
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(slices) { slice in
                HStack(spacing: 8) {
                    Circle()
                        .fill(slice.color)
                        .frame(width: 10, height: 10)
                    Text(slice.label)
                        .font(.subheadline)
                    Spacer(minLength: 12)
                    Text("\(slice.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(slices.map { "\($0.label) \($0.count) days" }.joined(separator: ", "))
    }
}

#Preview {
    let water = Habit(name: "Drink Water", goal: "8 glasses", color: "6BB6FF")
    water.completedDates = [Date(), Calendar.current.date(byAdding: .day, value: -1, to: Date())!]

    return OverallCompletionChart(habits: [water])
        .padding()
}
