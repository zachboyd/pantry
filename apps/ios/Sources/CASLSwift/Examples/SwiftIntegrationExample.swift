import SwiftUI
import Combine

// MARK: - Example Models

struct Article: Subject, IdentifiableSubject, Sendable {
    static let subjectType: SubjectType = "Article"
    
    let id: String
    let title: String
    let content: String
    let authorId: String
    let published: Bool
    
    var subjectType: SubjectType { Self.subjectType }
}

// MARK: - View Model with Property Wrappers

@MainActor
class ArticleViewModel: PermissionAwareObservableObject {
    // Protected properties using property wrappers
    @Permitted(wrappedValue: [], action: "read", subject: "article")
    var articles: [Article]
    
    @Permitted(wrappedValue: true, action: "create", subject: "article")
    var canCreateArticle: Bool
    
    @CanAccess(action: "delete", subject: "article", onDenied: {
        print("Delete access denied")
    })
    var deleteArticle: (String) -> Void = { _ in }
    
    // Combine publishers for reactive permissions
    @Published var showAdminPanel = false
    @Published var showCreateButton = false
    
    private var cancellables = Set<AnyCancellable>()
    
    override init(ability: ReactiveAbility? = nil) {
        super.init(ability: ability)
        
        // Set up delete function
        deleteArticle = { [weak self] articleId in
            self?.performDelete(articleId: articleId)
        }
        
        setupPermissionBindings()
    }
    
    private func setupPermissionBindings() {
        // Reactively update UI based on permissions
        permissionPublisher("manage", "article")
            .assign(to: &$showAdminPanel)
        
        permissionPublisher("create", "article")
            .assign(to: &$showCreateButton)
        
        // React to permission changes
        PermissionNotificationCenter.shared.publisher
            .filter { $0.subject == "article" }
            .sink { [weak self] change in
                print("Article permission changed: \(change.action) - \(change.newValue)")
                self?.refreshArticles()
            }
            .store(in: &cancellables)
    }
    
    func refreshArticles() {
        // Refresh only if we have read permission
        guard $articles.hasPermission else { return }
        
        // Simulate loading articles
        articles = [
            Article(id: "1", title: "Swift CASL", content: "...", authorId: "user1", published: true),
            Article(id: "2", title: "SwiftUI Tips", content: "...", authorId: "user1", published: false)
        ]
    }
    
    private func performDelete(articleId: String) {
        articles.removeAll { $0.id == articleId }
    }
}

// MARK: - SwiftUI Views with Permission Integration

struct ArticleListView: View {
    @StateObject private var viewModel = ArticleViewModel()
    @Environment(\.ability) private var ability
    
    var body: some View {
        NavigationView {
            List {
                // Articles section - only visible with read permission
                PermissionSection(action: "read", subject: "article") {
                    ForEach(viewModel.articles, id: \.id) { article in
                        ArticleRow(article: article)
                    }
                }
                
                // Admin section - only visible with manage permission
                Section {
                    Text("Admin Panel")
                        .font(.headline)
                    
                    Button("Manage Users") {
                        // Admin action
                    }
                    
                    Button("View Analytics") {
                        // Admin action
                    }
                }
                .canView("manage", "article")
            }
            .navigationTitle("Articles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    // Create button with permission check
                    PermissionButton("Create", action: "create", subject: "article") {
                        createNewArticle()
                    }
                }
            }
        }
        .onAppear {
            viewModel.refreshArticles()
        }
    }
    
    private func createNewArticle() {
        // Navigate to create view
    }
}

struct ArticleRow: View {
    let article: Article
    @Environment(\.ability) private var ability
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(article.title)
                    .font(.headline)
                
                Text(article.published ? "Published" : "Draft")
                    .font(.caption)
                    .foregroundColor(article.published ? .green : .gray)
            }
            
            Spacer()
            
            // Edit button - only shows if user can update
            PermissionButton("Edit", action: "update", subject: "article") {
                editArticle()
            }
            .buttonStyle(.bordered)
            
            // Delete button - shows different content based on permission
            Button("Delete") {
                deleteArticle()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .permissionBased("delete", "article") {
                // Show lock icon if no delete permission
                Image(systemName: "lock.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func editArticle() {
        // Edit implementation
    }
    
    private func deleteArticle() {
        // Delete implementation
    }
}

// MARK: - App with Ability Setup

struct ArticleApp: App {
    @StateObject private var ability = ReactiveAbility()
    
    var body: some Scene {
        WindowGroup {
            ArticleListView()
                .ability(ability)
                .onAppear {
                    setupUserPermissions()
                }
        }
    }
    
    private func setupUserPermissions() {
        Task {
            // Simulate loading user permissions
            let rules = [
                Rule(action: Action("read"), subject: SubjectType("article")),
                Rule(action: Action("create"), subject: SubjectType("article")),
                Rule(action: Action("update"), subject: SubjectType("article"), 
                     conditions: Conditions(["authorId": "currentUser"])),
                Rule(action: Action("delete"), subject: SubjectType("article"),
                     conditions: Conditions(["authorId": "currentUser"]))
            ]
            
            await ability.update(rules)
            
            // Also update global context for property wrappers
            await MainActor.run {
                PermissionContext.shared.setAbility(ability)
            }
        }
    }
}

// MARK: - Advanced Example with Combine

class ArticleService: ObservableObject {
    private let ability: ReactiveAbility
    private var cancellables = Set<AnyCancellable>()
    
    // Permission-gated publishers
    var articlesPublisher: AnyPublisher<[Article], Never> {
        ability.publisher(for: "read", "article")
            .whenPermitted()
            .flatMap { _ in
                self.loadArticles()
            }
            .eraseToAnyPublisher()
    }
    
    init(ability: ReactiveAbility) {
        self.ability = ability
    }
    
    private func loadArticles() -> AnyPublisher<[Article], Never> {
        // Simulate API call
        Just([
            Article(id: "1", title: "Article 1", content: "...", authorId: "user1", published: true),
            Article(id: "2", title: "Article 2", content: "...", authorId: "user2", published: true)
        ])
        .delay(for: .seconds(1), scheduler: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func createArticle(_ article: Article) -> AnyPublisher<Article, Error> {
        // Gate the operation with permission check
        Just(article)
            .setFailureType(to: Error.self)
            .requirePermission(ability, action: "create", subject: "article")
            .eraseToAnyPublisher()
    }
}

// MARK: - Usage with Permission-Required Protocol

struct AdminPanel: View, PermissionRequired {
    static let requiredPermissions = [
        (action: "manage", subject: "users"),
        (action: "manage", subject: "settings")
    ]
    
    var body: some View {
        VStack {
            Text("Admin Panel")
                .font(.largeTitle)
            
            // Admin controls
        }
    }
}