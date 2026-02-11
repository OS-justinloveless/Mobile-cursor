import SwiftUI

/// Displays an AskUserQuestion prompt with multiple questions and options
struct QuestionBlockView: View {
    let block: ChatContentBlock
    let hasResponded: Bool
    let onSubmit: ([String: [String]]) -> Void

    @State private var selectedAnswers: [String: Set<String>] = [:]
    @State private var hasSubmitted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Question\(pluralSuffix)")
                        .font(.headline)
                    Text("\(questionCount) question\(pluralSuffix) from Claude")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Questions list
            if let questions = block.questions {
                ForEach(questions) { question in
                    QuestionRow(
                        question: question,
                        selectedAnswers: Binding(
                            get: { selectedAnswers[question.id] ?? [] },
                            set: { selectedAnswers[question.id] = $0 }
                        ),
                        hasSubmitted: hasSubmitted
                    )
                }
            }

            Divider()

            // Submit button or response indicator
            if hasResponded || hasSubmitted {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Answers submitted")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            } else {
                Button {
                    submitAnswers()
                } label: {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Submit Answers")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(isValid ? Color.blue : Color.gray)
                    .cornerRadius(8)
                }
                .disabled(!isValid)
            }
        }
        .padding(16)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 2)
        )
    }

    private var questionCount: Int {
        block.questions?.count ?? 0
    }

    private var pluralSuffix: String {
        questionCount == 1 ? "" : "s"
    }

    private var isValid: Bool {
        guard let questions = block.questions else { return false }
        // All questions must have at least one answer selected
        return questions.allSatisfy { question in
            if let selected = selectedAnswers[question.id], !selected.isEmpty {
                return true
            }
            return false
        }
    }

    private func submitAnswers() {
        hasSubmitted = true

        // Convert Set<String> to [String] for each answer
        let answersArray = selectedAnswers.mapValues { Array($0) }
        onSubmit(answersArray)
    }
}

/// Individual question row with options
struct QuestionRow: View {
    let question: QuestionData
    @Binding var selectedAnswers: Set<String>
    let hasSubmitted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Question header chip
            Text(question.header)
                .font(.caption2.weight(.medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.2))
                .cornerRadius(4)

            // Question text
            Text(question.question)
                .font(.subheadline.weight(.medium))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Options
            VStack(alignment: .leading, spacing: 6) {
                ForEach(question.options) { option in
                    OptionButton(
                        option: option,
                        isSelected: selectedAnswers.contains(option.label),
                        isDisabled: hasSubmitted,
                        multiSelect: question.multiSelect
                    ) {
                        toggleOption(option.label)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    private func toggleOption(_ optionLabel: String) {
        if question.multiSelect {
            // Multi-select: toggle the option
            if selectedAnswers.contains(optionLabel) {
                selectedAnswers.remove(optionLabel)
            } else {
                selectedAnswers.insert(optionLabel)
            }
        } else {
            // Single-select: replace with this option
            selectedAnswers = [optionLabel]
        }
    }
}

/// Individual option button
struct OptionButton: View {
    let option: QuestionOption
    let isSelected: Bool
    let isDisabled: Bool
    let multiSelect: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // Selection indicator
                Image(systemName: selectionIcon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? .blue : .gray)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(option.label)
                        .font(.subheadline.weight(isSelected ? .medium : .regular))
                        .foregroundColor(.primary)

                    Text(option.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(10)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }

    private var selectionIcon: String {
        if multiSelect {
            return isSelected ? "checkmark.square.fill" : "square"
        } else {
            return isSelected ? "circle.fill" : "circle"
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleQuestions = [
        QuestionData(
            question: "Which library should we use for date formatting?",
            header: "Library",
            options: [
                QuestionOption(
                    label: "date-fns",
                    description: "Modern JavaScript date utility library"
                ),
                QuestionOption(
                    label: "moment.js",
                    description: "Popular but larger library with extensive features"
                ),
                QuestionOption(
                    label: "dayjs",
                    description: "Lightweight alternative to moment.js"
                ),
            ],
            multiSelect: false
        ),
        QuestionData(
            question: "Which features do you want to enable?",
            header: "Features",
            options: [
                QuestionOption(
                    label: "Dark mode",
                    description: "Add dark mode theme support"
                ),
                QuestionOption(
                    label: "Notifications",
                    description: "Enable push notifications"
                ),
            ],
            multiSelect: true
        ),
    ]

    let sampleBlock = ChatContentBlock(
        id: "question-1",
        type: .questionPrompt,
        timestamp: Date().timeIntervalSince1970,
        toolId: "tool-123",
        questions: sampleQuestions
    )

    return VStack(spacing: 20) {
        QuestionBlockView(
            block: sampleBlock,
            hasResponded: false,
            onSubmit: { answers in
                print("Submitted answers: \(answers)")
            }
        )

        QuestionBlockView(
            block: sampleBlock,
            hasResponded: true,
            onSubmit: { _ in }
        )
    }
    .padding()
}
