import SwiftUI

extension Color {
    /// A soft note-paper yellow for to-dos, like the calendar's red weekday.
    static let todo = Color(red: 1.0, green: 0.84, blue: 0.26)
}

/// A minimal to-do list beside the calendar: what's left on the left, the list on the right.
struct TodoPageView: View {
    let viewModel: NotchViewModel

    @Environment(AppModel.self) private var app

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            TodoSummary()
                .frame(width: 104, alignment: .leading)
            TodoList(viewModel: viewModel)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 24)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
}

// MARK: Summary

private struct TodoSummary: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        let todos = app.todos
        let total = todos.items.count
        VStack(alignment: .leading, spacing: 0) {
            Text("To-dos")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.todo)
            Text("\(todos.remainingCount)")
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
                .padding(.bottom, 2)
            Text(caption(remaining: todos.remainingCount, done: todos.doneCount))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.45))
                .contentTransition(.opacity)
            if total > 0 {
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(Color.todo)
                            .frame(width: proxy.size.width * CGFloat(todos.doneCount) / CGFloat(total))
                    }
                }
                .frame(width: 72, height: 3)
                .padding(.top, 8)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: todos.remainingCount)
    }

    private func caption(remaining: Int, done: Int) -> String {
        if remaining == 0 { return done == 0 ? String(localized: "Nothing yet") : String(localized: "All done") }
        return done == 0 ? String(localized: "left") : String(localized: "\(done) done")
    }
}

// MARK: List

private struct TodoList: View {
    let viewModel: NotchViewModel

    @Environment(AppModel.self) private var app
    @State private var draft = ""
    @State private var isAdding = false
    @FocusState private var addFocused: Bool
    @State private var editingID: TodoItem.ID?
    @State private var editDraft = ""
    /// Per-row focus, so moving from one row's editor to another's never commits the wrong one.
    @FocusState private var editFocus: TodoItem.ID?
    @State private var settleTask: Task<Void, Never>?

    var body: some View {
        let todos = app.todos
        VStack(alignment: .leading, spacing: 0) {
            addRow
            if todos.items.isEmpty && !isAdding {
                Text("Jot things down without leaving what you're doing.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.leading, 26)
                    .padding(.top, 2)
                    .transition(.opacity)
            }
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(todos.items) { item in
                        TodoRow(
                            item: item,
                            isEditing: editingID == item.id,
                            editDraft: $editDraft,
                            editFocus: $editFocus,
                            toggle: { toggle(item) },
                            beginEdit: { beginEdit(item) },
                            commitEdit: commitEdit,
                            delete: { withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { todos.delete(item.id) } },
                            clearCompleted: todos.doneCount > 0 ? {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { todos.clearCompleted() }
                            } : nil
                        )
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .top)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .leading))
                        ))
                    }
                }
                .padding(.bottom, 8)
            }
            .mask {
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.85),
                    .init(color: .clear, location: 1),
                ], startPoint: .top, endPoint: .bottom)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: todos.items)
        .onChange(of: addFocused) { _, focused in
            // Clicking elsewhere in the notch ends an empty draft.
            if !focused, isAdding, draft.trimmingCharacters(in: .whitespaces).isEmpty { finishAdding() }
        }
        .onChange(of: editFocus) { old, new in
            if let old, old == editingID, new != old { commitEdit() }
        }
        .onChange(of: viewModel.isEditingText) { _, editing in
            // The keyboard went elsewhere (Cmd-Tab, another app): wrap up without losing text.
            guard !editing else { return }
            if editingID != nil { commitEdit() }
            if isAdding {
                addFocused = false
                withAnimation(.smooth(duration: 0.2)) { isAdding = false }
            }
        }
        .onDisappear {
            // Closing the notch keeps whatever was typed.
            if !draft.trimmingCharacters(in: .whitespaces).isEmpty { app.todos.add(draft) }
            draft = ""
            isAdding = false
            if editingID != nil { commitEdit() }
            settleTask?.cancel()
            app.todos.settleOrder()
            viewModel.endTextInput()
        }
        #if DEBUG
        .onReceive(NotificationCenter.default.publisher(for: .pokoveDebugTodo)) { note in
            guard let text = note.object as? String else { beginAdding(); return }
            beginAdding()
            draft = text
        }
        #endif
    }

    // MARK: Adding

    @ViewBuilder private var addRow: some View {
        if isAdding {
            HStack(spacing: 10) {
                Circle()
                    .strokeBorder(Color.todo.opacity(0.6), style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 2.5]))
                    .frame(width: 15, height: 15)
                TextField("New To-do", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(Color.todo)
                    .focused($addFocused)
                    .onSubmit(submitDraft)
                    .onExitCommand(perform: finishAdding)
            }
            .frame(height: 28)
            .padding(.horizontal, 6)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .transition(.opacity)
        } else {
            Button(action: beginAdding) {
                HStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 15, height: 15)
                    Text("New To-do")
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer(minLength: 0)
                }
                .foregroundStyle(.white.opacity(0.45))
                .frame(height: 28)
                .padding(.horizontal, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(HoverHighlightButtonStyle(cornerRadius: 8))
            .transition(.opacity)
        }
    }

    private func beginAdding() {
        if editingID != nil { commitEdit() }
        viewModel.beginTextInput()
        // A draft kept from an interrupted entry comes back as it was.
        withAnimation(.smooth(duration: 0.2)) { isAdding = true }
        // Focus once the panel has become key.
        Task {
            try? await Task.sleep(for: .milliseconds(40))
            addFocused = true
        }
    }

    /// Return adds the item and keeps the field open for the next one.
    private func submitDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            finishAdding()
            return
        }
        app.todos.add(text)
        draft = ""
        haptic()
        Task {
            try? await Task.sleep(for: .milliseconds(20))
            addFocused = true
        }
    }

    private func finishAdding() {
        draft = ""
        addFocused = false
        withAnimation(.smooth(duration: 0.2)) { isAdding = false }
        if editingID == nil { viewModel.endTextInput() }
    }

    // MARK: Editing

    private func beginEdit(_ item: TodoItem) {
        guard editingID != item.id else { return }
        if isAdding {
            // Keep what was being typed as its own to-do.
            if !draft.trimmingCharacters(in: .whitespaces).isEmpty { app.todos.add(draft) }
            draft = ""
            addFocused = false
            isAdding = false
        }
        if let current = editingID {
            app.todos.rename(current, to: editDraft)
        }
        editDraft = item.title
        editingID = item.id
        viewModel.beginTextInput()
        Task {
            try? await Task.sleep(for: .milliseconds(40))
            editFocus = item.id
        }
    }

    private func commitEdit() {
        guard let id = editingID else { return }
        editingID = nil
        editFocus = nil
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { app.todos.rename(id, to: editDraft) }
        editDraft = ""
        if !isAdding { viewModel.endTextInput() }
    }

    // MARK: Checking off

    private func toggle(_ item: TodoItem) {
        app.todos.toggle(item.id)
        haptic()
        // Let the check land before the item slides into place.
        settleTask?.cancel()
        settleTask = Task {
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { app.todos.settleOrder() }
        }
    }

    private func haptic() {
        guard app.preferences.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let isEditing: Bool
    @Binding var editDraft: String
    var editFocus: FocusState<TodoItem.ID?>.Binding
    let toggle: () -> Void
    let beginEdit: () -> Void
    let commitEdit: () -> Void
    let delete: () -> Void
    let clearCompleted: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: toggle) {
                CheckCircle(isDone: item.isDone)
                    .frame(width: 15, height: 15)
                    .padding(4)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, -4)
            .accessibilityLabel(item.isDone ? Text("Mark as not done") : Text("Mark as done"))

            if isEditing {
                TextField("", text: $editDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.white)
                    .tint(Color.todo)
                    .focused(editFocus, equals: item.id)
                    .onSubmit(commitEdit)
                    .onExitCommand(perform: commitEdit)
            } else {
                Text(item.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(item.isDone ? .white.opacity(0.32) : .white.opacity(0.92))
                    .strikethrough(item.isDone, color: .white.opacity(0.4))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2, perform: beginEdit)
            }

            if isHovering && !isEditing {
                Button(action: delete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.45))
                        .frame(width: 18, height: 18)
                        .contentShape(Rectangle())
                }
                .buttonStyle(HoverHighlightButtonStyle(cornerRadius: 5))
                .help("Delete")
                .transition(.opacity)
            }
        }
        .frame(height: 28)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(isHovering && !isEditing ? 0.05 : 0))
        )
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: item.isDone)
        .onHover { isHovering = $0 }
        .contextMenu {
            Button("Edit", action: beginEdit)
            Button(item.isDone ? "Mark as Not Done" : "Mark as Done", action: toggle)
            Divider()
            Button("Delete", role: .destructive, action: delete)
            if let clearCompleted {
                Button("Clear Completed", action: clearCompleted)
            }
        }
    }
}

/// An empty ring that fills with a check, with a little overshoot.
private struct CheckCircle: View {
    let isDone: Bool

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(isDone ? Color.todo : .white.opacity(0.35), lineWidth: 1.5)
            Circle()
                .fill(Color.todo)
                .scaleEffect(isDone ? 1 : 0.3)
                .opacity(isDone ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 7.5, weight: .black))
                .foregroundStyle(.black)
                .scaleEffect(isDone ? 1 : 0.3)
                .opacity(isDone ? 1 : 0)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.55), value: isDone)
    }
}

#if DEBUG
extension Notification.Name {
    static let pokoveDebugTodo = Notification.Name("pokoveDebugTodo")
}
#endif
