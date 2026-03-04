import SwiftUI

/// A wrapper that adds swipe-to-delete (right-to-left) to any row content.
/// Reveals a red delete button behind the content when swiped.
struct SwipeToDeleteWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showingDelete = false

    private let deleteButtonWidth: CGFloat = 70

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete button revealed behind
            if showingDelete || offset < 0 {
                HStack(spacing: 0) {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            offset = 0
                            showingDelete = false
                        }
                        onDelete()
                    } label: {
                        VStack(spacing: RQSpacing.xxs) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Delete")
                                .font(.system(size: 10, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(width: deleteButtonWidth)
                        .frame(maxHeight: .infinity)
                        .background(RQColors.error)
                        .cornerRadius(RQRadius.small)
                    }
                }
            }

            // Main content
            content()
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            let translation = value.translation.width
                            // Only allow left swipe (negative), and limit right swipe to origin
                            if showingDelete {
                                // Already showing delete — allow dragging back
                                let newOffset = -deleteButtonWidth + translation
                                offset = min(0, max(-deleteButtonWidth, newOffset))
                            } else {
                                offset = min(0, translation)
                            }
                        }
                        .onEnded { value in
                            let threshold = deleteButtonWidth * 0.4
                            withAnimation(.easeOut(duration: 0.2)) {
                                if showingDelete {
                                    // If swiped back past halfway, close
                                    if offset > -threshold {
                                        offset = 0
                                        showingDelete = false
                                    } else {
                                        offset = -deleteButtonWidth
                                    }
                                } else {
                                    // Reveal delete if swiped far enough
                                    if -offset > threshold {
                                        offset = -deleteButtonWidth
                                        showingDelete = true
                                    } else {
                                        offset = 0
                                    }
                                }
                            }
                        }
                )
        }
        .clipped()
    }
}
