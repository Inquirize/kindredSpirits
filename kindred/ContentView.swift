//
//  ContentView.swift
//  kindred
//
//  Created by David Rötter on 10/17/25.
//

import SwiftUI

struct Question: Identifiable, Equatable {
    enum Scope: String, CaseIterable, Identifiable { // swiftlint:disable:this type_name
        case `public`
        case circle
        case `private`

        var id: String { rawValue }
        var label: String {
            switch self {
            case .public: "Public"
            case .circle: "Circle"
            case .private: "Private"
            }
        }
    }

    enum Template: String, CaseIterable, Identifiable {
        case clarify = "Clarify"
        case reframe = "Reframe"
        case commit = "Commit to a tiny next step"

        var id: String { rawValue }
    }

    struct QualitySignal: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let description: String
        let score: Double
    }

    let id: UUID
    var title: String
    var details: String
    var tags: [String]
    var scope: Scope
    var template: Template
    var qualityScore: Double
    var qualitySignals: [QualitySignal]
    var reflectionDue: Date?
    var reflectionsPosted: Int
    var kudosAllocated: Int
}

struct KudosEntry: Identifiable, Equatable {
    enum EntryKind: String {
        case received
        case passedForward
    }

    let id = UUID()
    let timestamp: Date
    let amount: Int
    let note: String
    let kind: EntryKind
}

struct CausePool: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let description: String
    var weeklyIntention: Int
}

struct CircleMember: Identifiable, Equatable {
    enum SupportState: String {
        case up = "Too Far Up"
        case down = "Too Far Down"
        case steady = "Steady"

        var color: Color {
            switch self {
            case .up: .orange
            case .down: .indigo
            case .steady: .green
            }
        }
    }

    let id = UUID()
    let name: String
    let pronouns: String
    var state: SupportState
    var responseTime: String
}

struct SupportCircle: Equatable {
    var name: String
    var agreements: [String]
    var quietHoursDescription: String
    var members: [CircleMember]
    var scheduledCheckIn: Date?
}

struct ContentView: View {
    @State private var questions = SampleData.questions
    @State private var kudosBudget = 20
    @State private var passForwardPercent: Double = 0.2
    @State private var ledger = SampleData.ledger
    @State private var causePools = SampleData.causePools
    @State private var circle = SampleData.circle

    var body: some View {
        TabView {
            NavigationStack {
                FeedView(questions: $questions)
                    .navigationTitle("Home")
            }
            .tabItem {
                Label("Home", systemImage: "house.fill")
            }

            NavigationStack {
                AskView(
                    kudosBudget: $kudosBudget,
                    defaultPassForward: $passForwardPercent,
                    onSubmit: { newQuestion in
                        questions.insert(newQuestion, at: 0)
                    }
                )
                .navigationTitle("Ask")
            }
            .tabItem {
                Label("Ask", systemImage: "questionmark.bubble")
            }

            NavigationStack {
                CirclesView(circle: $circle)
                    .navigationTitle("Circles")
            }
            .tabItem {
                Label("Circles", systemImage: "person.3.fill")
            }

            NavigationStack {
                PassForwardView(
                    kudosBudget: $kudosBudget,
                    passForwardPercent: $passForwardPercent,
                    ledger: $ledger,
                    causePools: $causePools
                )
                .navigationTitle("Pass-Forward")
            }
            .tabItem {
                Label("Pass", systemImage: "arrowshape.turn.up.right.fill")
            }

            NavigationStack {
                ProfileView(
                    kudosBudget: $kudosBudget,
                    passForwardPercent: $passForwardPercent,
                    reflectionsCompleted: questions.reduce(0) { $0 + $1.reflectionsPosted }
                )
                .navigationTitle("Profile")
            }
            .tabItem {
                Label("Profile", systemImage: "person.crop.circle")
            }
        }
        .tint(.indigo)
    }
}

private struct FeedView: View {
    @Binding var questions: [Question]
    @State private var selectedScope: Question.Scope? = nil
    @State private var showReflectionsOnly = false

    var filteredQuestions: [Question] {
        questions.filter { question in
            guard let selectedScope else {
                return !showReflectionsOnly || question.reflectionsPosted > 0
            }

            let matchesScope = question.scope == selectedScope
            let matchesReflection = !showReflectionsOnly || question.reflectionsPosted > 0
            return matchesScope && matchesReflection
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    Button {
                        withAnimation { selectedScope = nil }
                    } label: {
                        FilterChip(label: "All", isSelected: selectedScope == nil)
                    }

                    ForEach(Question.Scope.allCases) { scope in
                        Button {
                            withAnimation { selectedScope = scope }
                        } label: {
                            FilterChip(label: scope.label, isSelected: selectedScope == scope)
                        }
                    }

                    Toggle(isOn: $showReflectionsOnly) {
                        Text("Reflections")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .toggleStyle(.button)
                    .tint(.indigo.opacity(0.2))
                }
                .padding(.horizontal)
            }

            List {
                Section(header: Text("Quality-ranked Questions")) {
                    ForEach(filteredQuestions) { question in
                        QuestionCard(question: question)
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

private struct QuestionCard: View {
    let question: Question

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(question.title)
                    .font(.headline)
                Spacer()
                Label(question.scope.label, systemImage: "lock.open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !question.details.isEmpty {
                Text(question.details)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if !question.tags.isEmpty {
                WrapLayout(tags: question.tags)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Quality Score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ProgressView(value: question.qualityScore)
                    .tint(.indigo)
                HStack {
                    ForEach(question.qualitySignals) { signal in
                        VStack(alignment: .leading) {
                            Text(signal.title)
                                .font(.caption2)
                                .fontWeight(.bold)
                            Text(signal.description)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ProgressView(value: signal.score)
                                .progressViewStyle(.linear)
                                .tint(.green)
                        }
                    }
                }
            }

            HStack {
                Label("Reflections: \(question.reflectionsPosted)", systemImage: "sparkles")
                Spacer()
                Label("Kudos Offered: \(question.kudosAllocated)", systemImage: "hands.clap.fill")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.indigo.opacity(0.2))
        )
    }
}

private struct AskView: View {
    @Binding var kudosBudget: Int
    @Binding var defaultPassForward: Double

    @State private var title: String = ""
    @State private var details: String = ""
    @State private var template: Question.Template = .clarify
    @State private var scope: Question.Scope = .public
    @State private var tags: String = ""
    @State private var kudosAllocated: Int = 3
    @State private var showSuccess = false

    var onSubmit: (Question) -> Void

    var passForwardPercentageText: String {
        NumberFormatter.percent.string(from: NSNumber(value: defaultPassForward)) ?? "20%"
    }

    var body: some View {
        Form {
            Section(header: Text("Craft your question")) {
                TextField("Title", text: $title, prompt: Text("What do you want to explore?"))
                    .textInputAutocapitalization(.sentences)
                TextEditor(text: $details)
                    .frame(minHeight: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.indigo.opacity(0.2))
                    )
                    .padding(.vertical, 4)
                Picker("Template", selection: $template) {
                    ForEach(Question.Template.allCases) { template in
                        Text(template.rawValue).tag(template)
                    }
                }
                Picker("Scope", selection: $scope) {
                    ForEach(Question.Scope.allCases) { scope in
                        Text(scope.label).tag(scope)
                    }
                }
                TextField("Tags", text: $tags, prompt: Text("friendship, grounding"))
            }

            Section(header: Text("Reciprocity"), footer: Text("Kudos have no monetary value. Passing a portion forward keeps appreciation moving.")) {
                Stepper(value: $kudosAllocated, in: 1...min(5, max(1, kudosBudget))) {
                    Label("Kudos to offer: \(kudosAllocated)", systemImage: "hands.clap.fill")
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Pass-forward ratio")
                        Spacer()
                        Text(passForwardPercentageText)
                            .bold()
                    }
                    Slider(value: $defaultPassForward, in: 0.1...0.5, step: 0.05)
                }
                Text("Daily Kudos budget remaining: \(kudosBudget)")
                    .font(.caption)
            }

            Section(header: Text("Wellbeing")) {
                Toggle("Invite Circle grounding if I mark as Up/Down", isOn: .constant(true))
                    .disabled(true)
                Toggle("Anonymize within Circle", isOn: .constant(false))
                    .disabled(true)
                    .tint(.indigo)
            }

            Button {
                let newQuestion = Question(
                    id: UUID(),
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    details: details.trimmingCharacters(in: .whitespacesAndNewlines),
                    tags: tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty },
                    scope: scope,
                    template: template,
                    qualityScore: calculateQualityScore(),
                    qualitySignals: qualitySignals(),
                    reflectionDue: Calendar.current.date(byAdding: .day, value: 3, to: .now),
                    reflectionsPosted: 0,
                    kudosAllocated: kudosAllocated
                )
                onSubmit(newQuestion)
                kudosBudget = max(0, kudosBudget - kudosAllocated)
                title = ""
                details = ""
                tags = ""
                template = .clarify
                scope = .public
                kudosAllocated = 3
                showSuccess = true
            } label: {
                Label("Publish Question", systemImage: "paperplane.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .alert("Question shared", isPresented: $showSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Your question is now part of the curiosity feed. We'll nudge you to reflect soon.")
            }
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private func calculateQualityScore() -> Double {
        let specificity = min(1, Double(title.count) / 80)
        let kindness = details.lowercased().contains("thank") ? 0.9 : 0.7
        let novelty = Double.random(in: 0.4...0.9)
        let reflection = 0.5
        let diversity = Double.random(in: 0.4...0.6)
        return (specificity + kindness + novelty + reflection + diversity) / 5
    }

    private func qualitySignals() -> [Question.QualitySignal] {
        [
            .init(title: "Specificity", description: "Template fit & clarity", score: min(1, Double(title.count) / 80)),
            .init(title: "Kindness", description: "Tone & phrasing", score: details.lowercased().contains("thank") ? 0.9 : 0.7),
            .init(title: "Novelty", description: "Distinct in last week", score: Double.random(in: 0.4...0.9))
        ]
    }
}

private struct CirclesView: View {
    @Binding var circle: SupportCircle
    @State private var selectedMember: CircleMember.ID?
    @State private var sendGroundingPrompt = false

    var body: some View {
        Form {
            Section(header: Text(circle.name)) {
                Picker("Scheduled micro-call", selection: Binding(
                    get: { circle.scheduledCheckIn ?? .now },
                    set: { circle.scheduledCheckIn = $0 }
                )) {
                    ForEach(0..<4) { offset in
                        if let proposed = Calendar.current.date(byAdding: .day, value: offset, to: .now) {
                            Text(proposed.formatted(date: .abbreviated, time: .shortened))
                                .tag(proposed)
                        }
                    }
                }
                Toggle("Send 2-minute grounding prompt", isOn: $sendGroundingPrompt)
                    .tint(.indigo)
            }

            Section(header: Text("Members")) {
                ForEach(circle.members) { member in
                    HStack(alignment: .center, spacing: 12) {
                        Circle()
                            .fill(member.state.color.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(member.name.prefix(1))
                                    .font(.headline)
                                    .foregroundStyle(member.state.color)
                            )
                        VStack(alignment: .leading, spacing: 4) {
                            Text(member.name)
                                .font(.body)
                            Text(member.pronouns)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(member.state.rawValue)
                                .font(.caption2)
                                .foregroundStyle(member.state.color)
                        }
                        Spacer()
                        Menu {
                            Button("Steady") { update(member, with: .steady) }
                            Button("Too Far Up") { update(member, with: .up) }
                            Button("Too Far Down") { update(member, with: .down) }
                        } label: {
                            Label("Adjust", systemImage: "waveform")
                                .labelStyle(.iconOnly)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { selectedMember = member.id }
                }
            }

            Section(header: Text("Agreements")) {
                ForEach(circle.agreements, id: \.self) { agreement in
                    Label(agreement, systemImage: "hand.raised")
                        .font(.body)
                }
                Text("Quiet hours: \(circle.quietHoursDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .sheet(item: Binding(
            get: { selectedMember.flatMap { id in circle.members.first { $0.id == id } } },
            set: { newValue in selectedMember = newValue?.id }
        )) { member in
            VStack(spacing: 16) {
                Text(member.name)
                    .font(.title2)
                Text("Recent response time: \(member.responseTime)")
                Button("Request check-in") {
                    selectedMember = nil
                }
                .buttonStyle(.borderedProminent)
                Button("Close", role: .cancel) {
                    selectedMember = nil
                }
            }
            .padding()
            .presentationDetents([.medium])
        }
    }

    private func update(_ member: CircleMember, with newState: CircleMember.SupportState) {
        if let index = circle.members.firstIndex(of: member) {
            circle.members[index].state = newState
        }
    }
}

private struct PassForwardView: View {
    @Binding var kudosBudget: Int
    @Binding var passForwardPercent: Double
    @Binding var ledger: [KudosEntry]
    @Binding var causePools: [CausePool]

    @State private var selectedCause: CausePool.ID?
    @State private var note: String = ""
    @State private var amount: Int = 2

    var body: some View {
        Form {
            Section(header: Text("Ledger"), footer: Text("These entries track appreciation, never money.")) {
                ForEach(ledger.sorted(by: { $0.timestamp > $1.timestamp })) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label(entry.kind == .received ? "Received" : "Passed forward", systemImage: entry.kind == .received ? "hands.clap" : "arrow.forward")
                                .foregroundStyle(entry.kind == .received ? .green : .blue)
                            Spacer()
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text("Amount: \(entry.amount) Kudos")
                        if !entry.note.isEmpty {
                            Text(entry.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Section(header: Text("Pass-forward")) {
                Picker("Cause or peer", selection: $selectedCause) {
                    Text("Select a cause").tag(Optional<CausePool.ID>.none)
                    ForEach(causePools) { pool in
                        Text(pool.name).tag(Optional(pool.id))
                    }
                }
                Stepper(value: $amount, in: 1...5) {
                    Text("Amount: \(amount) Kudos")
                }
                TextField("Optional note", text: $note)
                Button("Log pass-forward") {
                    let entry = KudosEntry(
                        timestamp: .now,
                        amount: amount,
                        note: note,
                        kind: .passedForward
                    )
                    ledger.append(entry)
                    note = ""
                    amount = 2
                }
                .buttonStyle(.borderedProminent)
            }

            Section(header: Text("Pass-forward defaults")) {
                Slider(value: $passForwardPercent, in: 0.1...0.5, step: 0.05)
                Text("Currently passing forward \(NumberFormatter.percent.string(from: NSNumber(value: passForwardPercent)) ?? "20%") of received Kudos.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Daily Kudos budget: \(kudosBudget)")
                    .font(.caption)
            }

            Section(header: Text("Cause pools")) {
                ForEach(causePools.indices, id: \.self) { index in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(causePools[index].name)
                            .font(.headline)
                        Text(causePools[index].description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Stepper(value: $causePools[index].weeklyIntention, in: 0...20) {
                            Text("Weekly intention: \(causePools[index].weeklyIntention) Kudos")
                        }
                    }
                }
            }
        }
    }
}

private struct ProfileView: View {
    @Binding var kudosBudget: Int
    @Binding var passForwardPercent: Double
    let reflectionsCompleted: Int

    @State private var locale: Locale = .current
    @State private var exportRequested = false
    @State private var deleteRequested = false

    var body: some View {
        Form {
            Section(header: Text("Identity")) {
                TextField("Display name", text: .constant("River"))
                    .disabled(true)
                TextField("Handle", text: .constant("@river"))
                    .disabled(true)
                Picker("Preferred language", selection: $locale) {
                    Text("English").tag(Locale(identifier: "en"))
                    Text("Deutsch").tag(Locale(identifier: "de"))
                }
            }

            Section(header: Text("Reputation radiants"), footer: Text("These decay 2% daily to encourage fresh contributions.")) {
                ProgressView("Inquiry", value: 0.72)
                ProgressView("Reciprocity", value: passForwardPercent)
                ProgressView("Reflection", value: min(1, Double(reflectionsCompleted) / 10))
            }

            Section(header: Text("Controls")) {
                Toggle("Two-factor authentication", isOn: .constant(true))
                    .disabled(true)
                Toggle("Opt out of telemetry", isOn: .constant(false))
                    .tint(.indigo)
                Stepper(value: $kudosBudget, in: 10...40) {
                    Text("Daily Kudos budget: \(kudosBudget)")
                }
                Toggle("Auto-remind me to reflect", isOn: .constant(true))
                    .disabled(true)
            }

            Section(header: Text("Data rights")) {
                Button("Export data (JSON)") {
                    exportRequested = true
                }
                .buttonStyle(.bordered)
                Button("Delete account") {
                    deleteRequested = true
                }
                .buttonStyle(.bordered)
                .foregroundColor(.red)
            }
        }
        .alert("Export requested", isPresented: $exportRequested) {
            Button("Close", role: .cancel) { }
        } message: {
            Text("We'll prepare an encrypted JSON download within 24 hours.")
        }
        .alert("Delete account", isPresented: $deleteRequested) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm", role: .destructive) { }
        } message: {
            Text("Account deletion completes within 30 days with a 7-day grace period to reverse.")
        }
    }
}

private struct WrapLayout: View {
    let tags: [String]

    var body: some View {
        TagCloud(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.indigo.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
    }
}

private struct FilterChip: View {
    let label: String
    let isSelected: Bool

    var body: some View {
        Text(label)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.indigo.opacity(0.2) : Color.gray.opacity(0.15))
            .clipShape(Capsule())
    }
}

private struct TagCloud: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        var size = CGSize.zero
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        let maxWidth = proposal.width ?? 320

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if rowWidth + subviewSize.width + (rowWidth > 0 ? spacing : 0) > maxWidth {
                size.width = max(size.width, rowWidth)
                size.height += rowHeight + spacing
                rowWidth = subviewSize.width
                rowHeight = subviewSize.height
            } else {
                rowWidth += (rowWidth > 0 ? spacing : 0) + subviewSize.width
                rowHeight = max(rowHeight, subviewSize.height)
            }
        }

        size.width = max(size.width, rowWidth)
        size.height += rowHeight
        return size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let subviewSize = subview.sizeThatFits(.unspecified)
            if origin.x + subviewSize.width > bounds.maxX + 0.1 { // wrap to next line
                origin.x = bounds.minX
                origin.y += rowHeight + spacing
                rowHeight = 0
            }

            subview.place(at: CGPoint(x: origin.x, y: origin.y), proposal: ProposedViewSize(width: subviewSize.width, height: subviewSize.height))
            origin.x += subviewSize.width + spacing
            rowHeight = max(rowHeight, subviewSize.height)
        }
    }
}

private enum SampleData {
    static let questions: [Question] = [
        Question(
            id: UUID(),
            title: "What would a 10-minute repair step look like?",
            details: "I want to reconnect with a friend after a misunderstanding. Looking for one tiny, kind action I can take this week.",
            tags: ["friendship", "repair", "accountability"],
            scope: .public,
            template: .reframe,
            qualityScore: 0.86,
            qualitySignals: [
                .init(title: "Specificity", description: "Template fit & clarity", score: 0.9),
                .init(title: "Kindness", description: "Tone & phrasing", score: 0.95),
                .init(title: "Novelty", description: "Distinct in last week", score: 0.73)
            ],
            reflectionDue: Calendar.current.date(byAdding: .day, value: 3, to: .now),
            reflectionsPosted: 1,
            kudosAllocated: 4
        ),
        Question(
            id: UUID(),
            title: "How do I steady after a surprise win?",
            details: "My project received unexpected praise and I'm feeling amped. What small ritual helps you stay grounded?",
            tags: ["grounding", "rituals"],
            scope: .circle,
            template: .clarify,
            qualityScore: 0.74,
            qualitySignals: [
                .init(title: "Specificity", description: "Template fit & clarity", score: 0.7),
                .init(title: "Kindness", description: "Tone & phrasing", score: 0.78),
                .init(title: "Novelty", description: "Distinct in last week", score: 0.68)
            ],
            reflectionDue: Calendar.current.date(byAdding: .day, value: 1, to: .now),
            reflectionsPosted: 0,
            kudosAllocated: 3
        )
    ]

    static let ledger: [KudosEntry] = [
        KudosEntry(timestamp: Calendar.current.date(byAdding: .day, value: -1, to: .now) ?? .now, amount: 4, note: "From Mira — thanks for the grounding question", kind: .received),
        KudosEntry(timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: .now) ?? .now, amount: 2, note: "Passed to Local library fund", kind: .passedForward)
    ]

    static let causePools: [CausePool] = [
        CausePool(name: "Local library fund", description: "Support neighbors' curiosity with new books.", weeklyIntention: 4),
        CausePool(name: "Plant-a-tree", description: "Intent log for a community tree planting day.", weeklyIntention: 3)
    ]

    static let circle: SupportCircle = SupportCircle(
        name: "Support Circle — Dawn Patrol",
        agreements: [
            "Respond within 12 hours when someone flags Up/Down",
            "Lead with curiosity, never fixes",
            "Respect quiet hours"
        ],
        quietHoursDescription: "22:00–07:00 mindful replies",
        members: [
            CircleMember(name: "River", pronouns: "they/them", state: .steady, responseTime: "45 min"),
            CircleMember(name: "Amina", pronouns: "she/her", state: .up, responseTime: "20 min"),
            CircleMember(name: "Jo", pronouns: "he/him", state: .down, responseTime: "2 hrs"),
            CircleMember(name: "Sage", pronouns: "they/she", state: .steady, responseTime: "90 min")
        ],
        scheduledCheckIn: Calendar.current.date(byAdding: .day, value: 1, to: .now)
    )
}

private extension NumberFormatter {
    static let percent: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 0
        return formatter
    }()
}

#Preview {
    ContentView()
}
