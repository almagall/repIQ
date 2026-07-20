import SwiftUI

struct NotificationSettingsView: View {
    @State private var notificationsEnabled = false
    @State private var workoutRemindersEnabled = false
    @AppStorage("monthlyWrappedRemindersEnabled") private var monthlyWrappedRemindersEnabled = true
    @State private var reminderHour = 9
    @State private var reminderMinute = 0
    @State private var selectedDays: Set<Int> = [2, 3, 4, 5, 6] // Mon-Fri

    private let notificationService = NotificationService.shared
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        ScrollView {
            VStack(spacing: RQSpacing.lg) {
                // Master Toggle
                RQCard {
                    VStack(alignment: .leading, spacing: RQSpacing.md) {
                        Toggle(isOn: $notificationsEnabled) {
                            HStack {
                                Image(systemName: "bell.fill")
                                    .foregroundColor(RQColors.accent)
                                Text("Enable Notifications")
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                            }
                        }
                        .tint(RQColors.accent)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                Task {
                                    notificationsEnabled = await notificationService.requestPermission()
                                    // Auto-schedule the monthly wrapped reminder if the
                                    // user hasn't explicitly turned it off — this is the
                                    // only way most users will discover the feature.
                                    if notificationsEnabled, monthlyWrappedRemindersEnabled {
                                        notificationService.scheduleRepSheetReminder()
                                    }
                                }
                            } else {
                                notificationService.cancelAll()
                                workoutRemindersEnabled = false
                            }
                        }
                    }
                }

                if notificationsEnabled {
                    // Workout Reminders
                    RQCard {
                        VStack(alignment: .leading, spacing: RQSpacing.md) {
                            Toggle(isOn: $workoutRemindersEnabled) {
                                VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                    Text("Workout Reminders")
                                        .font(RQTypography.headline)
                                        .foregroundColor(RQColors.textPrimary)
                                    Text("Get reminded on your training days")
                                        .font(RQTypography.caption)
                                        .foregroundColor(RQColors.textTertiary)
                                }
                            }
                            .tint(RQColors.accent)

                            if workoutRemindersEnabled {
                                Divider().background(RQColors.surfaceTertiary)

                                // Time picker
                                DatePicker("Reminder Time", selection: Binding(
                                    get: {
                                        Calendar.current.date(from: DateComponents(hour: reminderHour, minute: reminderMinute)) ?? Date()
                                    },
                                    set: { date in
                                        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                                        reminderHour = components.hour ?? 9
                                        reminderMinute = components.minute ?? 0
                                        scheduleWorkoutReminders()
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .font(RQTypography.body)
                                .foregroundColor(RQColors.textPrimary)
                                .tint(RQColors.accent)

                                Divider().background(RQColors.surfaceTertiary)

                                // Day selector
                                Text("Training Days")
                                    .font(RQTypography.label)
                                    .foregroundColor(RQColors.textSecondary)

                                HStack(spacing: RQSpacing.xs) {
                                    ForEach(0..<7, id: \.self) { index in
                                        let dayNum = index + 1  // 1=Sun, 2=Mon, etc.
                                        Button {
                                            if selectedDays.contains(dayNum) {
                                                selectedDays.remove(dayNum)
                                            } else {
                                                selectedDays.insert(dayNum)
                                            }
                                            scheduleWorkoutReminders()
                                        } label: {
                                            Text(dayNames[index])
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundColor(selectedDays.contains(dayNum) ? RQColors.background : RQColors.textTertiary)
                                                .frame(width: 38, height: 38)
                                                .background(selectedDays.contains(dayNum) ? RQColors.accent : RQColors.surfaceTertiary)
                                                .clipShape(Circle())
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: workoutRemindersEnabled) { _, enabled in
                        if enabled {
                            scheduleWorkoutReminders()
                        } else {
                            notificationService.cancelWorkoutReminders()
                        }
                    }


                    // Monthly Rep Sheet Reminders
                    RQCard {
                        Toggle(isOn: $monthlyWrappedRemindersEnabled) {
                            VStack(alignment: .leading, spacing: RQSpacing.xxs) {
                                Text("Monthly Rep Sheet")
                                    .font(RQTypography.headline)
                                    .foregroundColor(RQColors.textPrimary)
                                Text("Get notified on the 1st of each month when your Rep Sheet is ready")
                                    .font(RQTypography.caption)
                                    .foregroundColor(RQColors.textTertiary)
                            }
                        }
                        .tint(RQColors.accent)
                        .onChange(of: monthlyWrappedRemindersEnabled) { _, enabled in
                            if enabled {
                                notificationService.scheduleRepSheetReminder()
                            } else {
                                notificationService.cancelRepSheetReminder()
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, RQSpacing.screenHorizontal)
            .padding(.top, RQSpacing.lg)
            .padding(.bottom, RQSpacing.xxxl)
        }
        .background(RQColors.background)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await notificationService.checkAuthorizationStatus()
            notificationsEnabled = notificationService.isAuthorized
        }
    }

    private func scheduleWorkoutReminders() {
        notificationService.scheduleWorkoutReminder(
            hour: reminderHour,
            minute: reminderMinute,
            weekdays: Array(selectedDays)
        )
    }
}
