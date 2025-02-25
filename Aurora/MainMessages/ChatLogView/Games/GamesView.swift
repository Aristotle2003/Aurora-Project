import SwiftUI
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth

// MARK: - Game Type

enum GameType: String, CaseIterable, Codable, Identifiable {
    case ticTacToe = "Tic Tac Toe"
    case rockPaperScissors = "Rock Paper Scissors"
    case memoryMatch = "Memory Match"
    case guessNumber = "Guess the Number"
    
    var id: String { rawValue }
}

// MARK: - Game Selection View

struct GameSelectionView: View {
    @State private var selectedGame: GameType?
    @State private var isNavigatingToGame = false
    
    // Pass in your two players (current user and opponent)
    var currentUser: ChatUser
    var opponentUser: ChatUser
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Select a Game")
                    .font(.largeTitle)
                    .padding()
                List(GameType.allCases) { game in
                    Button(action: {
                        selectedGame = game
                        isNavigatingToGame = true
                    }) {
                        Text(game.rawValue)
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Game Selection")
            .background(
                NavigationLink(destination:
                    GameContainerView(gameType: selectedGame ?? .ticTacToe,
                                      currentUser: currentUser,
                                      opponentUser: opponentUser),
                               isActive: $isNavigatingToGame) {
                    EmptyView()
                }
                .hidden()
            )
        }
    }
}

// MARK: - Tic Tac Toe Session

// This class encapsulates all Tic Tac Toe logic and Firestore updates.
class TicTacToeSession: ObservableObject {
    // Session properties
    @Published var sessionId: String = ""
    @Published var lastUpdated: Timestamp = Timestamp()
    
    // Tic Tac Toe state
    @Published var board: [String] = Array(repeating: "", count: 9)
    @Published var currentTurn: String = "X"
    @Published var gameStatus: String = "ongoing" // "ongoing", "won", "draw"
    @Published var winner: String? = nil
    
    // Players
    private(set) var currentUser: ChatUser!
    private(set) var opponentUser: ChatUser!
    
    private var sessionListener: ListenerRegistration?
    private let db = FirebaseManager.shared.firestore
    
    func joinSession(currentUser: ChatUser, opponentUser: ChatUser) {
        self.currentUser = currentUser
        self.opponentUser = opponentUser
        
        let uids = [currentUser.uid, opponentUser.uid].sorted()
        sessionId = "\(GameType.ticTacToe.rawValue)_\(uids[0])_\(uids[1])"
        let sessionRef = db.collection("game_sessions").document(sessionId)
        
        sessionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let data = snapshot?.data(), snapshot!.exists {
                self.board = data["board"] as? [String] ?? self.board
                self.currentTurn = data["currentTurn"] as? String ?? self.currentTurn
                self.gameStatus = data["gameStatus"] as? String ?? self.gameStatus
                self.winner = data["winner"] as? String
            } else {
                let firstTurn = Bool.random() ? "X" : "O"
                let newSession: [String: Any] = [
                    "gameType": GameType.ticTacToe.rawValue,
                    "board": self.board,
                    "currentTurn": firstTurn,
                    "gameStatus": self.gameStatus,
                    "winner": NSNull(),
                    "lastUpdated": Timestamp(),
                    "player1": currentUser.uid,
                    "player2": opponentUser.uid
                ]
                sessionRef.setData(newSession)
            }
            self.listenToSession()
        }
    }
    
    private func listenToSession() {
        let sessionRef = db.collection("game_sessions").document(sessionId)
        sessionListener = sessionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                self.lastUpdated = data["lastUpdated"] as? Timestamp ?? self.lastUpdated
                self.board = data["board"] as? [String] ?? self.board
                self.currentTurn = data["currentTurn"] as? String ?? self.currentTurn
                self.gameStatus = data["gameStatus"] as? String ?? self.gameStatus
                self.winner = data["winner"] as? String
            }
        }
    }
    
    // MARK: - Game Logic
    
    func makeMove(at index: Int) {
        guard gameStatus == "ongoing", board[index] == "" else { return }
        
        let uids = [currentUser.uid, opponentUser.uid].sorted()
        let mySymbol = currentUser.uid == uids[0] ? "X" : "O"
        guard currentTurn == mySymbol else { return }
        
        board[index] = mySymbol
        
        if checkWin(for: mySymbol) {
            gameStatus = "won"
            winner = mySymbol
        } else if !board.contains("") {
            gameStatus = "draw"
        } else {
            currentTurn = (mySymbol == "X" ? "O" : "X")
        }
        updateSession()
    }
    
    private func checkWin(for symbol: String) -> Bool {
        let combos = [
            [0,1,2], [3,4,5], [6,7,8],
            [0,3,6], [1,4,7], [2,5,8],
            [0,4,8], [2,4,6]
        ]
        return combos.contains { $0.allSatisfy { board[$0] == symbol } }
    }
    
    private func updateSession() {
        let sessionRef = db.collection("game_sessions").document(sessionId)
        let data: [String: Any] = [
            "board": board,
            "currentTurn": currentTurn,
            "gameStatus": gameStatus,
            "winner": winner as Any,
            "lastUpdated": Timestamp()
        ]
        sessionRef.setData(data, merge: true)
    }
    
    func resetGame() {
        board = Array(repeating: "", count: 9)
        currentTurn = Bool.random() ? "X" : "O"
        gameStatus = "ongoing"
        winner = nil
        updateSession()
    }
    
    deinit {
        sessionListener?.remove()
    }
}

// MARK: - Game Container View

struct GameContainerView: View {
    var gameType: GameType
    var currentUser: ChatUser
    var opponentUser: ChatUser
    
    var body: some View {
        switch gameType {
        case .ticTacToe:
            TicTacToeContainer(currentUser: currentUser, opponentUser: opponentUser)
        case .memoryMatch:
            MemoryMatchContainer(currentUser: currentUser, opponentUser: opponentUser)
        default:
            Text("Game not implemented yet.")
        }
    }
}
// MARK: - Memory Match Container & View

struct MemoryMatchContainer: View {
    var currentUser: ChatUser
    var opponentUser: ChatUser
    
    @StateObject private var session = MemoryMatchSession()
    
    var body: some View {
        VStack {
            MemoryMatchView(session: session)
            Button("Back to Game Selection") {
                // Handle dismissing the view as needed.
            }
            .padding()
        }
        .onAppear {
            session.joinSession(currentUser: currentUser, opponentUser: opponentUser)
        }
    }
}


// MARK: - Tic Tac Toe Container & View

struct TicTacToeContainer: View {
    var currentUser: ChatUser
    var opponentUser: ChatUser
    
    @StateObject private var session = TicTacToeSession()
    
    var body: some View {
        VStack {
            TicTacToeView(session: session)
            Button("Back to Game Selection") {
                // Handle dismissing the view as needed.
            }
            .padding()
        }
        .onAppear {
            session.joinSession(currentUser: currentUser, opponentUser: opponentUser)
        }
    }
}

struct TicTacToeView: View {
    @ObservedObject var session: TicTacToeSession
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Tic Tac Toe")
                .font(.largeTitle).bold()
            Text(statusText)
                .font(.title2).padding()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(0..<9, id: \.self) { index in
                    CellView(symbol: session.board[index])
                        .onTapGesture {
                            if session.board[index] == "" && session.gameStatus == "ongoing" {
                                session.makeMove(at: index)
                            }
                        }
                        .disabled(session.board[index] != "" || session.gameStatus != "ongoing")
                }
            }
            .padding()
            if session.gameStatus != "ongoing" {
                Button("Reset Game") {
                    session.resetGame()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.horizontal)
            }
        }
        .padding()
    }
    
    var statusText: String {
        guard let currentUser = session.currentUser,
              let opponentUser = session.opponentUser else {
            return "Loading..."
        }
        let uids = [currentUser.uid, opponentUser.uid].sorted()
        let mySymbol = currentUser.uid == uids[0] ? "X" : "O"
        
        if session.gameStatus == "ongoing" {
            return session.currentTurn == mySymbol ? "Your turn (\(mySymbol))" : "Opponent's turn"
        } else if session.gameStatus == "draw" {
            return "It's a draw!"
        } else if let winner = session.winner {
            return winner == mySymbol ? "You won!" : "You lost!"
        }
        return "Game Over"
    }

}

// MARK: - Cell View

struct CellView: View {
    let symbol: String
    
    var body: some View {
        ZStack {
            Rectangle()
                .foregroundColor(.blue.opacity(0.3))
                .cornerRadius(8)
                .frame(width: 100, height: 100)
                .shadow(radius: 5)
            Text(symbol)
                .font(.system(size: 48, weight: .bold))
                .foregroundColor(.black)
        }
    }
}

// MARK: - Memory Match Session

class MemoryMatchSession: ObservableObject {
    @Published var sessionId: String = ""
    @Published var lastUpdated: Timestamp = Timestamp()
    
    @Published var boardValues: [String] = []
    @Published var boardRevealed: [Bool] = []
    @Published var flippedIndices: [Int] = []
    @Published var scorePlayer1: Int = 0
    @Published var scorePlayer2: Int = 0
    @Published var currentTurn: String = ""  // "player1" or "player2"
    @Published var gameStatus: String = "ongoing" // "ongoing", "finished"
    
    private(set) var currentUser: ChatUser!
    private(set) var opponentUser: ChatUser!
    
    private var sessionListener: ListenerRegistration?
    private let db = FirebaseManager.shared.firestore
    
    func joinSession(currentUser: ChatUser, opponentUser: ChatUser) {
        self.currentUser = currentUser
        self.opponentUser = opponentUser
        
        let uids = [currentUser.uid, opponentUser.uid].sorted()
        sessionId = "Memory Match_\(uids[0])_\(uids[1])"
        let sessionRef = db.collection("game_sessions").document(sessionId)
        
        sessionRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            if let data = snapshot?.data(), snapshot!.exists {
                self.boardValues = data["boardValues"] as? [String] ?? self.boardValues
                self.boardRevealed = data["boardRevealed"] as? [Bool] ?? self.boardRevealed
                self.flippedIndices = data["flippedIndices"] as? [Int] ?? self.flippedIndices
                self.scorePlayer1 = data["scorePlayer1"] as? Int ?? self.scorePlayer1
                self.scorePlayer2 = data["scorePlayer2"] as? Int ?? self.scorePlayer2
                self.currentTurn = data["currentTurn"] as? String ?? self.currentTurn
                self.gameStatus = data["gameStatus"] as? String ?? self.gameStatus
            } else {
                // Initialize a deck with 8 pairs (16 cards)
                let pairs = ["A", "B", "C", "D", "E", "F", "G", "H"]
                var deck = pairs + pairs
                deck.shuffle()
                self.boardValues = deck
                self.boardRevealed = Array(repeating: false, count: deck.count)
                self.flippedIndices = []
                self.scorePlayer1 = 0
                self.scorePlayer2 = 0
                self.currentTurn = Bool.random() ? "player1" : "player2"
                self.gameStatus = "ongoing"
                
                let newSession: [String: Any] = [
                    "gameType": GameType.memoryMatch.rawValue,
                    "boardValues": self.boardValues,
                    "boardRevealed": self.boardRevealed,
                    "flippedIndices": self.flippedIndices,
                    "scorePlayer1": self.scorePlayer1,
                    "scorePlayer2": self.scorePlayer2,
                    "currentTurn": self.currentTurn,
                    "gameStatus": self.gameStatus,
                    "lastUpdated": Timestamp(),
                    "player1": currentUser.uid,
                    "player2": opponentUser.uid
                ]
                sessionRef.setData(newSession)
            }
            self.listenToSession()
        }
    }
    
    private func listenToSession() {
        let sessionRef = db.collection("game_sessions").document(sessionId)
        sessionListener = sessionRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self, let data = snapshot?.data() else { return }
            DispatchQueue.main.async {
                self.lastUpdated = data["lastUpdated"] as? Timestamp ?? self.lastUpdated
                self.boardValues = data["boardValues"] as? [String] ?? self.boardValues
                self.boardRevealed = data["boardRevealed"] as? [Bool] ?? self.boardRevealed
                self.flippedIndices = data["flippedIndices"] as? [Int] ?? self.flippedIndices
                self.scorePlayer1 = data["scorePlayer1"] as? Int ?? self.scorePlayer1
                self.scorePlayer2 = data["scorePlayer2"] as? Int ?? self.scorePlayer2
                self.currentTurn = data["currentTurn"] as? String ?? self.currentTurn
                self.gameStatus = data["gameStatus"] as? String ?? self.gameStatus
            }
        }
    }
    
    func flipCard(at index: Int) {
        guard gameStatus == "ongoing", !boardRevealed[index], !flippedIndices.contains(index) else { return }
        if flippedIndices.count < 2 {
            boardRevealed[index] = true
            flippedIndices.append(index)
            updateSession()
            if flippedIndices.count == 2 {
                checkForMatch()
            }
        }
    }
    
    private func checkForMatch() {
        guard flippedIndices.count == 2 else { return }
        let first = flippedIndices[0]
        let second = flippedIndices[1]
        
        if boardValues[first] == boardValues[second] {
            // Match found: award point to current player.
            if currentTurn == "player1" {
                scorePlayer1 += 1
            } else {
                scorePlayer2 += 1
            }
            flippedIndices = []
            updateSession()
            if boardRevealed.allSatisfy({ $0 }) {
                gameStatus = "finished"
                updateSession()
            }
        } else {
            // No match: flip cards back after a short delay and change turn.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.boardRevealed[first] = false
                self.boardRevealed[second] = false
                self.flippedIndices = []
                self.currentTurn = (self.currentTurn == "player1") ? "player2" : "player1"
                self.updateSession()
            }
        }
    }
    
    private func updateSession() {
        let sessionRef = db.collection("game_sessions").document(sessionId)
        let data: [String: Any] = [
            "boardValues": boardValues,
            "boardRevealed": boardRevealed,
            "flippedIndices": flippedIndices,
            "scorePlayer1": scorePlayer1,
            "scorePlayer2": scorePlayer2,
            "currentTurn": currentTurn,
            "gameStatus": gameStatus,
            "lastUpdated": Timestamp()
        ]
        sessionRef.setData(data, merge: true)
    }
    
    func resetGame() {
        let pairs = ["A", "B", "C", "D", "E", "F", "G", "H"]
        var deck = pairs + pairs
        deck.shuffle()
        boardValues = deck
        boardRevealed = Array(repeating: false, count: deck.count)
        flippedIndices = []
        scorePlayer1 = 0
        scorePlayer2 = 0
        currentTurn = Bool.random() ? "player1" : "player2"
        gameStatus = "ongoing"
        updateSession()
    }
    
    deinit {
        sessionListener?.remove()
    }
}


struct MemoryMatchView: View {
    @ObservedObject var session: MemoryMatchSession
    
    let columns: [GridItem] = Array(repeating: .init(.flexible(), spacing: 10), count: 4)
    
    // Compute local role and corresponding scores.
    var myRole: String? {
        guard let currentUser = session.currentUser, let opponentUser = session.opponentUser else {
            return nil
        }
        let sortedUIDs = [currentUser.uid, opponentUser.uid].sorted()
        return currentUser.uid == sortedUIDs[0] ? "player1" : "player2"
    }
    
    var myScore: Int {
        guard let role = myRole else { return 0 }
        return role == "player1" ? session.scorePlayer1 : session.scorePlayer2
    }
    
    var opponentScore: Int {
        guard let role = myRole else { return 0 }
        return role == "player1" ? session.scorePlayer2 : session.scorePlayer1
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Memory Match")
                .font(.largeTitle).bold()
            Text(statusText)
                .font(.title2)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(session.boardValues.indices, id: \.self) { index in
                    if let currentUser = session.currentUser,
                       let opponentUser = session.opponentUser,
                       let role = myRole {
                        let isMyTurn = (session.currentTurn == role)
                        MemoryCardView(cardValue: session.boardValues[index],
                                       isRevealed: session.boardRevealed[index])
                            .onTapGesture {
                                session.flipCard(at: index)
                            }
                            .disabled(session.boardRevealed[index] ||
                                      session.flippedIndices.count == 2 ||
                                      !isMyTurn)
                    } else {
                        MemoryCardView(cardValue: session.boardValues[index],
                                       isRevealed: session.boardRevealed[index])
                    }
                }
            }
            .padding()
            HStack {
                Text("You: \(myScore)")
                Text("Opponent: \(opponentScore)")
            }
            if session.gameStatus == "finished" {
                Button("Reset Game") {
                    session.resetGame()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
        .padding()
    }
    
    var statusText: String {
        guard let role = myRole else {
            return "Loading..."
        }
        if session.gameStatus == "ongoing" {
            return session.currentTurn == role ? "Your turn" : "Opponent's turn"
        } else {
            if myScore > opponentScore {
                return "You win!"
            } else if opponentScore > myScore {
                return "Opponent wins!"
            } else {
                return "It's a tie!"
            }
        }
    }
}



struct MemoryCardView: View {
    var cardValue: String
    var isRevealed: Bool
    
    var body: some View {
        ZStack {
            if isRevealed {
                Rectangle()
                    .fill(Color.green.opacity(0.7))
                    .cornerRadius(8)
                Text(cardValue)
                    .font(.largeTitle)
                    .foregroundColor(.black)
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .cornerRadius(8)
            }
        }
        .frame(width: 70, height: 100)
    }
}
