//
//  ContentView.swift
//  TinyTriviaAI Watch App
//
//  Created by Will Brandin on 3/15/23.
//

// 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

import OpenAISwift

struct Question: Codable {
    var question: String
    var answer: String
    var falseAnswers: [String]
}

class Requester: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var question: Question?
    @Published var error: String = ""
    @Published var isAnswerStatusPresented: Bool = false
    @Published var answerStatus = ""
    @Published var answerOptions: [String] = []
    @Published var topic: String = "Ancient History"

    @Published var difficulty: String = "Intermediate"

    var difficultyOptions: [String] {
        ["Easy", "Intermediate", "Hard"]
    }

    var difficultyPrompt: (String, String) -> String = { difficulty, topic in
        switch difficulty {
        case "Easy":
            return "generally easy"
        case "Intermediate":
            return "moderately difficule"
        case "Hard":
            return "extremly hard"
        default:
            return "Easy"
        }
    }

    var options: [String] {
        ["Ancient History", "The Solar System", "Famous Paintings", "World History", "Animal Kingdom", "Sports Records", "Famous Authors", "Musical Instruments", "Movie Quotes", "Geography", "Pop Culture"]
    }

    @MainActor
    func request() async throws {
        isLoading = true
        let openAI = OpenAISwift(authToken: "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")
        let req = try await openAI.sendChat(
            with: [
                .init(role: .user, content: "You are a trivia host asking questions about \(topic). Generate 1 \(difficultyPrompt(difficulty, topic)) trivia question about \(topic) with the question and answers as well as 3 false answers. The question should be very obscure and unknown. The questions and answers should be fairly short no more than 10 words. The response should be formatted as JSON. The json should be structured as such: {\"question\": \"\",\n  \"answer\": \"\",\n  \"false_answers\": [\"\"]}")
            ],
            model: .chat(.chatgpt),
            maxTokens: 600
        )

        isLoading = false
        let response = req.choices.first?.message.content ?? ""
        print(response)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let data = Data(response.utf8)
        do {
            let object = try decoder.decode(Question.self, from: data)
            self.question = object
            var answers = object.falseAnswers
            answers.append(object.answer)
            self.answerOptions = answers.shuffled()
            print(object)
        } catch {
            print(error)
        }
    }

    func submitAnswer(_ answer: String) {
        if answer != self.question?.answer {
            self.answerStatus = "Oh that's too bad, the answer is \(self.question?.answer ?? "").\nTry again?"
            self.isAnswerStatusPresented = true
        } else {
            self.answerStatus = "Correct!\nAnother?"
            self.isAnswerStatusPresented = true
        }
    }

    func resetState() {
        self.question = nil
        self.isAnswerStatusPresented = false
        self.answerStatus = ""
        self.error = ""
    }
}

import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: Requester = .init()

    var body: some View {
        VStack {
            if let question = viewModel.question {
                ScrollView {
                    Text(question.question)

                    ForEach(viewModel.answerOptions, id: \.self) { answer in
                        Button(action: { viewModel.submitAnswer(answer) }) {
                            Text(answer)
                        }
                    }
                    .alert(
                        viewModel.answerStatus,
                        isPresented: $viewModel.isAnswerStatusPresented,
                        actions: {
                            Button(action: self.viewModel.resetState) {
                                Text("Continue")
                            }
                        }
                    )
                }
            } else if viewModel.isLoading {
                Text("Loading...")
            } else {
                Text("💡")
                    .font(.largeTitle)
                Picker("Topic", selection: $viewModel.topic) {
                    ForEach(viewModel.options, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .pickerStyle(NavigationLinkPickerStyle())

                Picker("Difficulty", selection: $viewModel.difficulty) {
                    ForEach(viewModel.difficultyOptions, id: \.self) { option in
                        Text(option.capitalized).tag(option)
                    }
                }
                .pickerStyle(NavigationLinkPickerStyle())
                Spacer()

                Button(
                    action: {
                        Task {
                            try await viewModel.request()
                        }
                    }
                ) {
                    Text("🤖 Ask Me")
                }
                .disabled(viewModel.isLoading)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
