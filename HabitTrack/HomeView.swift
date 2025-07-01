//
//  HomeView.swift
//  HabitTrack
//
//  Created by Yusufege Eren on 1.07.2025.
//

import SwiftUI
import UserNotifications

// Görev modeli
struct Task: Identifiable, Equatable, Codable {
    let id = UUID()
    var name: String
    var description: String
    var status: String // "Yapılacak" veya "Tamamlandı"
    var priority: Priority // Yüksek, Orta, Düşük
    var category: Category // İş, Kişisel, Diğer
    var creationDate: Date // Eklenme tarihi
    var dueDate: Date? // Son tarih (isteğe bağlı)
    
    enum Priority: String, CaseIterable, Codable {
        case high = "Yüksek"
        case medium = "Orta"
        case low = "Düşük"
    }
    
    enum Category: String, CaseIterable, Codable {
        case work = "İş"
        case personal = "Kişisel"
        case other = "Diğer"
    }
}

// Tema modeli
enum AppTheme: String, CaseIterable {
    case light = "Açık"
    case dark = "Koyu"
    case blue = "Mavi"
}

// Ana uygulama ekranı
struct HomeView: View {
    @State private var tasks: [Task] = []
    @State private var showAddTaskView = false
    @State private var showEditTaskView: Task? = nil
    @State private var completionPercentage: Double = 0.0
    @State private var searchText: String = ""
    @State private var selectedPriority: Task.Priority? = nil
    @State private var selectedCategory: Task.Category? = nil
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    @State private var selectedTheme: AppTheme = AppTheme(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "Açık") ?? .light
    @State private var selectedTab: Int = 0 // 0: Görevler, 1: İstatistikler

    // Görevleri filtreleme ve sıralama (modüler)
    private var filteredTasks: [Task] {
        applyFiltersAndSort()
    }
    
    private var pendingTasks: [Task] { filteredTasks.filter { $0.status == "Yapılacak" } }
    private var completedTasks: [Task] { filteredTasks.filter { $0.status == "Tamamlandı" } }

    private func applyFiltersAndSort() -> [Task] {
        var result = tasks
        if !searchText.isEmpty { result = result.filter { $0.name.lowercased().contains(searchText.lowercased()) } }
        if let priority = selectedPriority { result = result.filter { $0.priority == priority } }
        if let category = selectedCategory { result = result.filter { $0.category == category } }
        return result.sorted { $0.priority.rawValue < $1.priority.rawValue }
    }

    // UserDefaults için görevleri ve temayı kaydetme/yükleme
    private func saveTasks() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            let sharedDefaults = UserDefaults(suiteName: "group.com.yusufegeeren.HabitTrack") // Kendi ID'nizi kullanın
            sharedDefaults?.set(encoded, forKey: "tasks")
            sharedDefaults?.set(tasks.count, forKey: "taskCount") // Görev sayısını ekle
            UserDefaults.standard.set(encoded, forKey: "tasks")
        }
    }
    
    private func loadTasks() {
        if let data = UserDefaults.standard.data(forKey: "tasks"),
           let decoded = try? JSONDecoder().decode([Task].self, from: data) {
            tasks = decoded
        }
    }
    
    private func saveTheme() {
        UserDefaults.standard.set(selectedTheme.rawValue, forKey: "appTheme")
    }

    // Bildirim izni isteme ve planlama
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted { print("Bildirim izni alındı") }
            else if let error = error { print("Bildirim izni hatası: \(error)") }
        }
    }
    
    private func scheduleNotification(for task: Task) {
        guard let dueDate = task.dueDate else { return }
        let notificationDate = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) ?? Date()
        if notificationDate > Date() {
            let content = UNMutableNotificationContent()
            content.title = "Görev Hatırlatma"
            content.body = "\(task.name) görevinin son tarihi yaklaşıyor! (\(task.dueDate!.formatted(date: .abbreviated, time: .omitted)))"
            content.sound = .default
            let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: notificationDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: task.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error { print("Bildirim planlama hatası: \(error)") }
            }
        }
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                mainTab().tabItem { Label("Görevler", systemImage: "list.bullet") }.tag(0)
                statsTab().tabItem { Label("İstatistikler", systemImage: "chart.bar") }.tag(1)
            }
            .accentColor(themeColor())
            .onAppear { loadTasks(); setupNotifications(); scheduleAllNotifications() }
            .onChange(of: tasks) { _ in updateCompletionPercentage(); saveTasks(); scheduleAllNotifications() }
            if showOnboarding { OnboardingView(showOnboarding: $showOnboarding) }
        }
        .preferredColorScheme(themeColorScheme())
    }

    private func mainTab() -> some View {
        NavigationView {
            VStack(spacing: 20) {
                headerView()
                searchAndFilterView()
                TaskProgressBar(value: $completionPercentage).frame(height: 20).padding().animation(.easeInOut, value: completionPercentage)
                taskListView()
            }
            .navigationBarTitle("Görevler", displayMode: .inline)
            .navigationBarItems(
                leading: Menu {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button(theme.rawValue) { selectedTheme = theme; saveTheme() }
                    }
                } label: { Image(systemName: "paintpalette").foregroundColor(.blue) },
                trailing: Button(action: { showAddTaskView.toggle() }) {
                    Image(systemName: "plus").font(.system(size: 24)).foregroundColor(.blue)
                }
            )
            .sheet(isPresented: $showAddTaskView) { TaskAddView(tasks: $tasks) }
            .sheet(item: $showEditTaskView) { task in TaskEditView(tasks: $tasks, task: task) }
        }
    }

    private func statsTab() -> some View {
        NavigationView { StatisticsView(tasks: tasks).navigationBarTitle("İstatistikler", displayMode: .inline) }
    }

    private func headerView() -> some View {
        HStack {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 32)).foregroundColor(themeColor())
            Text("Yapılacaklar Listesi").font(.largeTitle).fontWeight(.bold).foregroundColor(.primary)
        }
        .padding()
    }

    private func searchAndFilterView() -> some View {
        VStack(spacing: 10) {
            TextField("Görev ara...", text: $searchText)
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
                .padding(.horizontal)
            HStack {
                Picker("Öncelik", selection: $selectedPriority) {
                    Text("Tümü").tag(Task.Priority?.none)
                    ForEach(Task.Priority.allCases, id: \.self) { priority in
                        Text(priority.rawValue).tag(Task.Priority?.some(priority))
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                Picker("Kategori", selection: $selectedCategory) {
                    Text("Tümü").tag(Task.Category?.none)
                    ForEach(Task.Category.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(Task.Category?.some(category))
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }
            .padding(.horizontal)
        }
    }

    private func taskListView() -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if pendingTasks.isEmpty {
                    Text("Henüz yapılacak görev yok.")
                        .foregroundColor(.primary)
                        .padding(.leading)
                } else {
                    ForEach(pendingTasks, id: \.id) { task in
                        TaskCard(task: task, tasks: $tasks, onEdit: { showEditTaskView = task })
                            .transition(.opacity)
                    }
                    .padding(.horizontal)
                }
                Divider().padding(.vertical)
                if completedTasks.isEmpty {
                    Text("Henüz tamamlanan görev yok.")
                        .foregroundColor(.primary)
                        .padding(.leading)
                } else {
                    ForEach(completedTasks, id: \.id) { task in
                        TaskCard(task: task, tasks: $tasks, onEdit: { showEditTaskView = task })
                            .transition(.opacity)
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func updateCompletionPercentage() {
        completionPercentage = tasks.isEmpty ? 0.0 : Double(completedTasks.count) / Double(tasks.count)
    }

    private func scheduleAllNotifications() {
        tasks.forEach { scheduleNotification(for: $0) }
    }

    private func themeColor() -> Color {
        switch selectedTheme {
        case .light: return .black
        case .dark: return .white
        case .blue: return .white
        }
    }
    
    private func themeColorScheme() -> ColorScheme? {
        switch selectedTheme {
        case .light: return .light
        case .dark: return .dark
        case .blue: return .dark
        }
    }
}

// Görev kartı (hep canlı, opacity kaldırıldı)
struct TaskCard: View {
    let task: Task
    @Binding var tasks: [Task]
    let onEdit: () -> Void
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack {
            Circle()
                .fill(priorityColor(for: task.priority))
                .frame(width: 10, height: 10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(task.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(task.description.isEmpty ? "Açıklama yok" : task.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text("Kategori: \(task.category.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Eklenme: \(dateFormatter.string(from: task.creationDate))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                if let dueDate = task.dueDate {
                    Text("Son Tarih: \(dateFormatter.string(from: dueDate))")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            Spacer()
            Button(action: {
                if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                    let newStatus = tasks[index].status == "Yapılacak" ? "Tamamlandı" : "Yapılacak"
                    withAnimation {
                        tasks[index].status = newStatus
                        tasks = tasks // State’i güncelle
                        print("Status güncellendi: \(tasks[index].status)") // Debug
                    }
                }
            }) {
                Image(systemName: task.status == "Yapılacak" ? "square" : "checkmark.square.fill")
                    .foregroundColor(task.status == "Yapılacak" ? .blue : .green)
            }
            Button(action: {
                withAnimation {
                    tasks.removeAll { $0.id == task.id }
                    UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [task.id.uuidString])
                }
            }) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
                    .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
        .onTapGesture {
            onEdit()
        }
    }
    
    private func priorityColor(for priority: Task.Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// İlerleme çubuğu
struct TaskProgressBar: View {
    @Binding var value: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 12)
            
            Capsule()
                .fill(LinearGradient(gradient: Gradient(colors: [.green, .blue]), startPoint: .leading, endPoint: .trailing))
                .frame(width: min(CGFloat(value) * 300, 300), height: 12)
        }
        .cornerRadius(6)
        .padding(.horizontal)
        .shadow(radius: 1)
    }
}

// Görev ekleme ekranı
struct TaskAddView: View {
    @Binding var tasks: [Task]
    @State private var taskName: String = ""
    @State private var taskDescription: String = ""
    @State private var taskPriority: Task.Priority = .medium
    @State private var taskCategory: Task.Category = .personal
    @State private var dueDate: Date? = nil
    @State private var showDatePicker = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Görev Bilgileri")) {
                    TextField("Görev Adı", text: $taskName)
                    TextField("Açıklama (isteğe bağlı)", text: $taskDescription)
                }
                
                Section(header: Text("Öncelik")) {
                    Picker("Öncelik", selection: $taskPriority) {
                        ForEach(Task.Priority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Kategori")) {
                    Picker("Kategori", selection: $taskCategory) {
                        ForEach(Task.Category.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Son Tarih (isteğe bağlı)")) {
                    Toggle("Son Tarih Ekle", isOn: $showDatePicker)
                    if showDatePicker {
                        DatePicker("Son Tarih", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Yeni Görev Ekle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ekle") {
                        if !taskName.isEmpty {
                            let newTask = Task(
                                name: taskName,
                                description: taskDescription,
                                status: "Yapılacak",
                                priority: taskPriority,
                                category: taskCategory,
                                creationDate: Date(),
                                dueDate: dueDate
                            )
                            tasks.append(newTask)
                            taskName = ""
                            taskDescription = ""
                            taskPriority = .medium
                            taskCategory = .personal
                            dueDate = nil
                            showDatePicker = false
                            dismiss()
                        }
                    }
                    .disabled(taskName.isEmpty)
                }
            }
        }
    }
}

// Görev düzenleme ekranı
struct TaskEditView: View {
    @Binding var tasks: [Task]
    let task: Task
    @State private var taskName: String
    @State private var taskDescription: String
    @State private var taskPriority: Task.Priority
    @State private var taskCategory: Task.Category
    @State private var dueDate: Date?
    @State private var showDatePicker: Bool
    @Environment(\.dismiss) var dismiss

    init(tasks: Binding<[Task]>, task: Task) {
        self._tasks = tasks
        self.task = task
        self._taskName = State(initialValue: task.name)
        self._taskDescription = State(initialValue: task.description)
        self._taskPriority = State(initialValue: task.priority)
        self._taskCategory = State(initialValue: task.category)
        self._dueDate = State(initialValue: task.dueDate)
        self._showDatePicker = State(initialValue: task.dueDate != nil)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Görev Bilgileri")) {
                    TextField("Görev Adı", text: $taskName)
                    TextField("Açıklama (isteğe bağlı)", text: $taskDescription)
                }
                
                Section(header: Text("Öncelik")) {
                    Picker("Öncelik", selection: $taskPriority) {
                        ForEach(Task.Priority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Kategori")) {
                    Picker("Kategori", selection: $taskCategory) {
                        ForEach(Task.Category.allCases, id: \.self) { category in
                            Text(category.rawValue).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section(header: Text("Son Tarih (isteğe bağlı)")) {
                    Toggle("Son Tarih Ekle", isOn: $showDatePicker)
                    if showDatePicker {
                        DatePicker("Son Tarih", selection: Binding(
                            get: { dueDate ?? Date() },
                            set: { dueDate = $0 }
                        ), displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Görevi Düzenle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        if !taskName.isEmpty {
                            if let index = tasks.firstIndex(where: { $0.id == task.id }) {
                                tasks[index] = Task(
                                    name: taskName,
                                    description: taskDescription,
                                    status: tasks[index].status,
                                    priority: taskPriority,
                                    category: taskCategory,
                                    creationDate: tasks[index].creationDate,
                                    dueDate: dueDate
                                )
                            }
                            dismiss()
                        }
                    }
                    .disabled(taskName.isEmpty)
                }
            }
        }
    }
}

// İstatistikler ekranı
struct StatisticsView: View {
    let tasks: [Task]
    
    private var totalTasks: Int { tasks.count }
    private var completedTasks: Int { tasks.filter { $0.status == "Tamamlandı" }.count }
    private var completionRate: Double { totalTasks == 0 ? 0.0 : Double(completedTasks) / Double(totalTasks) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("İstatistikler")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Toplam Görev: \(totalTasks)")
                    .font(.headline)
                Text("Tamamlanan Görev: \(completedTasks)")
                    .font(.headline)
                Text("Tamamlama Oranı: \(String(format: "%.0f%%", completionRate * 100))")
                    .font(.headline)
            }
            .padding(.horizontal)
            
            TaskProgressBar(value: .constant(completionRate))
                .frame(height: 20)
                .padding()
            
            Text("Kategori Dağılımı")
                .font(.headline)
                .padding(.leading)
            
            ForEach(Task.Category.allCases, id: \.self) { category in
                let count = tasks.filter { $0.category == category }.count
                HStack {
                    Text(category.rawValue)
                        .font(.subheadline)
                    Spacer()
                    Text("\(count) görev")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

// Onboarding ekranı
struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    private let pages: [(title: String, description: String, image: String)] = [
        ("Hoş Geldiniz!", "Yapılacaklar listenizi kolayca yönetin.", "list.bullet"),
        ("Görev Ekleme", "Yeni görevler ekleyin, öncelik ve kategori belirleyin.", "plus.circle"),
        ("Bildirimler", "Son tarihler için hatırlatıcılar alın.", "bell"),
        ("İstatistikler", "İlerlemenizi takip edin.", "chart.bar")
    ]

    var body: some View {
        VStack {
            TabView(selection: $currentPage) {
                ForEach(0..<pages.count, id: \.self) { index in
                    VStack(spacing: 20) {
                        Image(systemName: pages[index].image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.blue)
                        Text(pages[index].title)
                            .font(.title)
                            .fontWeight(.bold)
                        Text(pages[index].description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())
            
            HStack {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom)
            
            Button(action: {
                if currentPage < pages.count - 1 {
                    currentPage += 1
                } else {
                    showOnboarding = false
                    UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                }
            }) {
                Text(currentPage == pages.count - 1 ? "Başla" : "İleri")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .background(Color(UIColor.systemBackground))
    }
}

// Önizleme
struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
