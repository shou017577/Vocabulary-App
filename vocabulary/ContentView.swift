import SwiftUI
import AVFoundation
import AudioToolbox
import UserNotifications

// MARK: - 1. 資料模型
struct TOEICWord: Identifiable, Codable, Equatable {
    var id = UUID()
    let english: String
    let chinese: String
    let partOfSpeech: String
    let example: String
    var isMastered: Bool = false
    var isReviewNeeded: Bool = false
    var category: String?
    
    enum CodingKeys: String, CodingKey {
        case english, chinese, partOfSpeech, example, category
    }
}

// MARK: - 2. 主視圖 (App Root - TabView 架構)
struct ContentView: View {
    @State private var wordList: [TOEICWord] = []
    
    // 控制目前選中的 Tab (0:首頁, 1:學習, 2:測驗, 3:複習, 4:設定)
    @State private var selectedTab: Int = 0
    
    // 資料持久化
    @AppStorage("dailyGoal") private var dailyGoal: Int = 20
    @AppStorage("todayCount") private var todayCount: Int = 0
    @AppStorage("lastLoginDate") private var lastLoginDate: String = ""
    
    // 通知設定
    @AppStorage("isNotificationEnabled") private var isNotificationEnabled: Bool = false
    @AppStorage("notificationTime") private var notificationTime: Double = Date().timeIntervalSince1970
    
    var body: some View {
        // 使用 TabView 實現「隨時切換功能」
        TabView(selection: $selectedTab) {
            
            // Tab 1: 首頁 (Dashboard)
            HomeView(wordList: wordList, todayCount: todayCount, dailyGoal: dailyGoal, selectedTab: $selectedTab)
                .tabItem {
                    Label("首頁", systemImage: "house.fill")
                }
                .tag(0)
            
            // Tab 2: 背單字 (Learn)
            FlashcardModeView(wordList: $wordList, isReviewMode: false, todayCount: $todayCount)
                .tabItem {
                    Label("背單字", systemImage: "rectangle.portrait.on.rectangle.portrait.fill")
                }
                .tag(1)
            
            // Tab 3: 測驗 (Quiz)
            QuizModeView(wordList: $wordList)
                .tabItem {
                    Label("測驗", systemImage: "checkmark.circle.fill")
                }
                .tag(2)
            
            // Tab 4: 錯題本 (Review)
            FlashcardModeView(wordList: $wordList, isReviewMode: true, todayCount: $todayCount)
                .tabItem {
                    Label("錯題", systemImage: "exclamationmark.triangle.fill")
                }
                .tag(3)
            
            // Tab 5: 設定 (Settings)
            SettingsView(wordList: $wordList, todayCount: $todayCount, dailyGoal: $dailyGoal, isNotificationEnabled: $isNotificationEnabled, notificationTime: $notificationTime)
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        // 設定 Tab Bar 的顏色，讓它更有質感
        .tint(.blue)
        .onAppear {
            loadDataAndProgress()
            checkNewDay()
        }
    }
    
    // --- 資料讀取與日期檢查邏輯 ---
    func checkNewDay() {
        let today = formatDate(Date())
        if lastLoginDate != today {
            todayCount = 0
            lastLoginDate = today
        }
    }
    
    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    func loadDataAndProgress() {
        if wordList.isEmpty {
            guard let url = Bundle.main.url(forResource: "word_data", withExtension: "json") else { return }
            do {
                let data = try Data(contentsOf: url)
                var loadedWords = try JSONDecoder().decode([TOEICWord].self, from: data)
                
                let masteredWords = UserDefaults.standard.stringArray(forKey: "SavedMasteredWords") ?? []
                let reviewWords = UserDefaults.standard.stringArray(forKey: "SavedReviewWords") ?? []
                
                for i in 0..<loadedWords.count {
                    if masteredWords.contains(loadedWords[i].english) {
                        loadedWords[i].isMastered = true
                    }
                    if reviewWords.contains(loadedWords[i].english) && !loadedWords[i].isMastered {
                        loadedWords[i].isReviewNeeded = true
                    }
                }
                self.wordList = loadedWords
            } catch {
                print("資料載入失敗: \(error)")
            }
        }
    }
}

// MARK: - 3. 首頁視圖 (Home View)
struct HomeView: View {
    var wordList: [TOEICWord]
    var todayCount: Int
    var dailyGoal: Int
    @Binding var selectedTab: Int // 用來控制跳轉
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemGray6).edgesIgnoringSafeArea(.all)
                
                ScrollView {
                    VStack(spacing: 25) {
                        
                        // 1. 頂部歡迎區
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("早安！") // 這裡可以根據時間改成晚安，先簡單做
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("TOEIC 單字大師")
                                    .font(.largeTitle)
                                    .fontWeight(.heavy)
                                    .foregroundColor(.primary)
                            }
                            Spacer()
                            Image(systemName: "book.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                                .shadow(radius: 5)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        // 2. 儀表板卡片
                        DailyGoalCard(current: todayCount, goal: dailyGoal)
                            .padding(.horizontal, 20)
                        
                        // 3. 快速入口 (Grid Layout)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                            
                            // 學習卡片
                            DashboardButton(
                                title: "開始背單字",
                                icon: "rectangle.portrait.on.rectangle.portrait.fill",
                                color: .blue,
                                count: "\(wordList.count) 字"
                            ) {
                                selectedTab = 1 // 切換到 Tab 1
                            }
                            
                            // 測驗卡片
                            DashboardButton(
                                title: "隨堂測驗",
                                icon: "checkmark.circle.fill",
                                color: .purple,
                                count: "實力檢測"
                            ) {
                                selectedTab = 2 // 切換到 Tab 2
                            }
                            
                            // 錯題卡片
                            DashboardButton(
                                title: "錯題特訓",
                                icon: "exclamationmark.triangle.fill",
                                color: .orange,
                                count: "\(wordList.filter{$0.isReviewNeeded}.count) 需複習"
                            ) {
                                selectedTab = 3 // 切換到 Tab 3
                            }
                            
                            // 設定卡片
                            DashboardButton(
                                title: "系統設定",
                                icon: "gearshape.fill",
                                color: .gray,
                                count: "目標調整"
                            ) {
                                selectedTab = 4 // 切換到 Tab 4
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 50)
                }
            }
        }
    }
}

// 儀表板上的大按鈕組件
struct DashboardButton: View {
    let title: String
    let icon: String
    let color: Color
    let count: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding(10)
                        .background(color)
                        .clipShape(Circle())
                    Spacer()
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(count)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 5)
        }
    }
}

// 每日目標卡片 (保持不變)
struct DailyGoalCard: View {
    let current: Int
    let goal: Int
    var progress: Double { return min(Double(current) / Double(goal), 1.0) }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text("今日目標").font(.headline).foregroundColor(.gray)
                HStack(alignment: .lastTextBaseline) {
                    Text("\(current)").font(.system(size: 36, weight: .bold)).foregroundColor(current >= goal ? .green : .primary)
                    Text("/ \(goal) 字").font(.subheadline).foregroundColor(.gray)
                }
                if current >= goal {
                    Text("🎉 目標達成！").font(.caption).fontWeight(.bold).foregroundColor(.green)
                } else {
                    Text("加油，還差 \(goal - current) 個字").font(.caption).foregroundColor(.blue)
                }
            }
            Spacer()
            ZStack {
                Circle().stroke(Color.gray.opacity(0.2), lineWidth: 10)
                Circle().trim(from: 0, to: progress).stroke(current >= goal ? Color.green : Color.blue, style: StrokeStyle(lineWidth: 10, lineCap: .round)).rotationEffect(.degrees(-90)).animation(.easeOut, value: progress)
                Text("\(Int(progress * 100))%").font(.caption).fontWeight(.bold)
            }
            .frame(width: 70, height: 70)
        }
        .padding(20).background(Color.white).cornerRadius(20).shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 5)
    }
}

// MARK: - 4. 背單字模式 (含搜尋)
struct FlashcardModeView: View {
    @Binding var wordList: [TOEICWord]
    var isReviewMode: Bool
    @Binding var todayCount: Int
    
    @AppStorage("LastSelectedCategory") private var savedCategory: String = "全部"
    @AppStorage("LastViewedWordID") private var savedWordID: String = ""
    @State private var searchText = ""
    
    init(wordList: Binding<[TOEICWord]>, isReviewMode: Bool, todayCount: Binding<Int> = .constant(0)) {
        self._wordList = wordList
        self.isReviewMode = isReviewMode
        self._todayCount = todayCount
    }
    
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset = CGSize.zero
    @State private var selectedCategory: String = "全部"
    
    let synthesizer = AVSpeechSynthesizer()
    
    var categories: [String] {
        let allCats = Set(wordList.compactMap { $0.category })
        return ["全部"] + allCats.sorted()
    }
    
    var filteredWords: [TOEICWord] {
        var words = wordList
        if isReviewMode {
            words = words.filter { $0.isReviewNeeded }
        } else {
            if selectedCategory != "全部" {
                words = words.filter { $0.category == selectedCategory }
            }
        }
        if !searchText.isEmpty {
            words = words.filter { word in
                word.english.lowercased().contains(searchText.lowercased()) ||
                word.chinese.contains(searchText)
            }
        }
        return words
    }
    
    var body: some View {
        NavigationStack { // 為了 Searchable 正常運作，這裡包一層 Stack
            ZStack {
                Color(UIColor.systemGray6).edgesIgnoringSafeArea(.all)
                
                if wordList.isEmpty {
                    ProgressView("資料載入中...")
                } else if filteredWords.isEmpty {
                    VStack(spacing: 20) {
                        if !searchText.isEmpty {
                            Image(systemName: "magnifyingglass").font(.system(size: 60)).foregroundColor(.gray)
                            Text("找不到符合的單字").foregroundColor(.gray)
                        } else if isReviewMode {
                            Image(systemName: "checkmark.seal.fill").font(.system(size: 80)).foregroundColor(.green)
                            Text("太棒了！").font(.largeTitle).fontWeight(.bold)
                            Text("目前沒有需要複習的錯題").foregroundColor(.gray)
                        } else {
                            Text("此分類暫無單字").foregroundColor(.gray)
                        }
                    }
                } else {
                    mainCardUI
                }
            }
            .onAppear { restoreState() }
            .searchable(text: $searchText, prompt: "搜尋單字 (英文或中文)")
            .onChange(of: selectedCategory) { currentIndex = 0; isFlipped = false }
            .onChange(of: searchText) { currentIndex = 0; isFlipped = false }
        }
    }
    
    var mainCardUI: some View {
        VStack(spacing: 20) {
            HStack {
                if isReviewMode {
                    Text("錯題特訓").font(.title2).fontWeight(.bold).foregroundColor(.orange)
                } else {
                    Menu {
                        ForEach(categories, id: \.self) { category in
                            Button(category) { changeCategory(to: category) }
                        }
                    } label: {
                        HStack {
                            Text(selectedCategory).fontWeight(.bold).lineLimit(1)
                            Image(systemName: "chevron.down")
                        }
                        .padding(.vertical, 8).padding(.horizontal, 16).background(Color.blue.opacity(0.1)).cornerRadius(20)
                    }
                }
                Spacer()
                if filteredWords.indices.contains(currentIndex) {
                    Text("\(currentIndex + 1) / \(filteredWords.count)").font(.headline).foregroundColor(.gray)
                }
            }
            .padding(.horizontal, 30).padding(.top, 20)
            
            Spacer()
            
            ZStack {
                if filteredWords.indices.contains(currentIndex) {
                    if isFlipped {
                        if let realIndex = wordList.firstIndex(where: { $0.id == filteredWords[currentIndex].id }) {
                            BackCardView(word: $wordList[realIndex]).rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                        }
                    } else {
                        FrontCardView(word: filteredWords[currentIndex])
                    }
                }
            }
            .frame(width: 320, height: 450).background(Color.white).cornerRadius(20).shadow(radius: 10)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
            .offset(x: dragOffset.width, y: 0)
            .rotationEffect(.degrees(Double(dragOffset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in dragOffset = gesture.translation }
                    .onEnded { gesture in
                        let threshold: CGFloat = 100
                        if gesture.translation.width < -threshold { moveCard(isNext: true) }
                        else if gesture.translation.width > threshold { moveCard(isNext: false) }
                        else { withAnimation(.spring()) { dragOffset = .zero } }
                    }
            )
            .onTapGesture { withAnimation { isFlipped.toggle() } }
            .animation(.default, value: isFlipped)
            
            Spacer()
            
            if filteredWords.indices.contains(currentIndex) {
                HStack(spacing: 50) {
                    Button(action: { speak(word: filteredWords[currentIndex].english) }) {
                        VStack {
                            Image(systemName: "speaker.wave.2.fill").font(.title).padding(10).background(Color.white).clipShape(Circle()).shadow(radius: 5)
                            Text("發音").font(.caption).foregroundColor(.gray)
                        }
                    }
                    Button(action: { toggleMastered() }) {
                        VStack {
                            Image(systemName: filteredWords[currentIndex].isMastered ? "star.fill" : "star").font(.title).foregroundColor(filteredWords[currentIndex].isMastered ? .yellow : .gray).padding(10).background(Color.white).clipShape(Circle()).shadow(radius: 5)
                            Text(filteredWords[currentIndex].isMastered ? "已熟記" : "標記").font(.caption).foregroundColor(.gray)
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
    }
    
    // (邏輯函式保持不變)
    func restoreState() {
        if !isReviewMode {
            selectedCategory = savedCategory
            if let savedIndex = filteredWords.firstIndex(where: { $0.id.uuidString == savedWordID }) {
                currentIndex = savedIndex
            } else { currentIndex = 0 }
        }
        validateIndex()
    }
    func saveCurrentState() {
        if !isReviewMode && filteredWords.indices.contains(currentIndex) {
            savedWordID = filteredWords[currentIndex].id.uuidString
        }
    }
    func changeCategory(to category: String) {
        selectedCategory = category
        currentIndex = 0
        isFlipped = false
        if !isReviewMode { savedCategory = category; saveCurrentState() }
    }
    func validateIndex() {
        if filteredWords.isEmpty { currentIndex = 0 }
        else if currentIndex >= filteredWords.count { currentIndex = filteredWords.count - 1 }
    }
    func moveCard(isNext: Bool) {
        let endPosition: CGFloat = isNext ? -500 : 500
        withAnimation(.easeIn(duration: 0.2)) { dragOffset = CGSize(width: endPosition, height: 0) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            if filteredWords.isEmpty { return }
            if isNext { currentIndex = (currentIndex + 1) % filteredWords.count }
            else { currentIndex = (currentIndex - 1 + filteredWords.count) % filteredWords.count }
            isFlipped = false; dragOffset = .zero; saveCurrentState()
        }
    }
    func toggleMastered() {
        guard filteredWords.indices.contains(currentIndex) else { return }
        let currentID = filteredWords[currentIndex].id
        if let index = wordList.firstIndex(where: { $0.id == currentID }) {
            wordList[index].isMastered.toggle()
            if wordList[index].isMastered {
                todayCount += 1
                wordList[index].isReviewNeeded = false
            } else {
                if todayCount > 0 { todayCount -= 1 }
            }
            saveProgress()
            if isReviewMode { DispatchQueue.main.async { validateIndex() } }
        }
    }
    func saveProgress() {
        let masteredWords = wordList.filter { $0.isMastered }.map { $0.english }
        UserDefaults.standard.set(masteredWords, forKey: "SavedMasteredWords")
        let reviewWords = wordList.filter { $0.isReviewNeeded }.map { $0.english }
        UserDefaults.standard.set(reviewWords, forKey: "SavedReviewWords")
    }
    func speak(word: String) {
        let utterance = AVSpeechUtterance(string: word)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}

// MARK: - 5. 測驗模式 (含音效)
struct QuizModeView: View {
    @Binding var wordList: [TOEICWord]
    @State private var currentQuestionWord: TOEICWord?
    @State private var options: [TOEICWord] = []
    @State private var showResult = false
    @State private var isCorrect = false
    @State private var score = 0
    @State private var selectedOptionId: UUID? = nil
    
    var body: some View {
        NavigationStack { // 這裡也要包一層，確保標題顯示
            ZStack {
                Color(UIColor.systemGray6).edgesIgnoringSafeArea(.all)
                
                if wordList.count < 4 {
                    Text("單字量不足，無法開始測驗").foregroundColor(.gray)
                } else {
                    ScrollView {
                        VStack(spacing: 30) {
                            Text("單字小測驗").font(.title).fontWeight(.bold).padding(.top, 20)
                            Text("Score: \(score)").font(.headline).foregroundColor(.blue)
                            
                            if let question = currentQuestionWord {
                                VStack {
                                    Text(question.english).font(.system(size: 40, weight: .heavy)).multilineTextAlignment(.center).padding()
                                    Text(question.partOfSpeech).font(.headline).foregroundColor(.gray)
                                }
                                .frame(width: 300, height: 200).background(Color.white).cornerRadius(20).shadow(radius: 5).padding(.vertical, 20)
                            }
                            
                            VStack(spacing: 15) {
                                ForEach(options) { option in
                                    Button(action: { checkAnswer(option) }) {
                                        Text(option.chinese).font(.title3).bold().frame(maxWidth: .infinity).padding().background(getButtonColor(option: option)).foregroundColor(.white).cornerRadius(15)
                                    }
                                    .disabled(showResult)
                                }
                            }
                            .padding(.horizontal, 30)
                            
                            if showResult && !isCorrect {
                                Button(action: { newQuestion() }) {
                                    Text("下一題").font(.headline).frame(width: 200).padding().background(Color.blue).foregroundColor(.white).cornerRadius(25).shadow(radius: 5)
                                }
                                .padding(.top, 10)
                            }
                        }
                        .padding(.bottom, 50)
                    }
                }
            }
            .onAppear {
                if currentQuestionWord == nil { newQuestion() }
            }
        }
    }
    
    func newQuestion() {
        showResult = false
        selectedOptionId = nil
        if wordList.isEmpty { return }
        guard let question = wordList.randomElement() else { return }
        currentQuestionWord = question
        var distractors: [TOEICWord] = []
        var safetyCounter = 0
        while distractors.count < 3 && safetyCounter < 100 {
            safetyCounter += 1
            if let randomWord = wordList.randomElement(), randomWord.id != question.id, !distractors.contains(where: { $0.id == randomWord.id }) {
                distractors.append(randomWord)
            }
        }
        options = (distractors + [question]).shuffled()
    }
    
    func checkAnswer(_ selected: TOEICWord) {
        selectedOptionId = selected.id
        showResult = true
        if selected.id == currentQuestionWord?.id {
            isCorrect = true
            score += 10
            AudioServicesPlaySystemSound(1407)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { newQuestion() }
        } else {
            isCorrect = false
            AudioServicesPlaySystemSound(1053)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            if let question = currentQuestionWord { markAsReviewNeeded(word: question) }
        }
    }
    func markAsReviewNeeded(word: TOEICWord) {
        if let index = wordList.firstIndex(where: { $0.id == word.id }) {
            wordList[index].isReviewNeeded = true
            let reviewWords = wordList.filter { $0.isReviewNeeded }.map { $0.english }
            UserDefaults.standard.set(reviewWords, forKey: "SavedReviewWords")
        }
    }
    func getButtonColor(option: TOEICWord) -> Color {
        if showResult {
            if option.id == currentQuestionWord?.id { return Color.green }
            else if option.id == selectedOptionId { return Color.red }
            else { return Color.gray.opacity(0.3) }
        }
        return Color.blue
    }
}

// MARK: - 6. 設定頁面
struct SettingsView: View {
    @Binding var wordList: [TOEICWord]
    @Binding var todayCount: Int
    @Binding var dailyGoal: Int
    @Binding var isNotificationEnabled: Bool
    @Binding var notificationTime: Double
    
    @State private var showingResetAlert = false
    @State private var reminderDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("學習目標")) {
                    Stepper(value: $dailyGoal, in: 5...100, step: 5) {
                        HStack {
                            Text("每日單字量")
                            Spacer()
                            Text("\(dailyGoal) 個").foregroundColor(.blue)
                        }
                    }
                }
                
                Section(header: Text("每日提醒")) {
                    Toggle("啟用每日提醒", isOn: $isNotificationEnabled)
                        .onChange(of: isNotificationEnabled) {
                            if isNotificationEnabled {
                                NotificationManager.shared.requestPermission()
                                NotificationManager.shared.scheduleNotification(at: reminderDate)
                            } else {
                                NotificationManager.shared.cancelNotification()
                            }
                        }
                    
                    if isNotificationEnabled {
                        DatePicker("提醒時間", selection: $reminderDate, displayedComponents: .hourAndMinute)
                            .onChange(of: reminderDate) {
                                NotificationManager.shared.scheduleNotification(at: reminderDate)
                                notificationTime = reminderDate.timeIntervalSince1970
                            }
                    }
                }
                
                Section(header: Text("資料管理")) {
                    Button(role: .destructive) { showingResetAlert = true } label: {
                        HStack { Image(systemName: "trash"); Text("重置所有學習進度") }
                    }
                }
                Section(footer: Text("重置進度將清除所有已熟記單字與錯題紀錄，且無法復原。")) { EmptyView() }
            }
            .navigationTitle("設定")
            .alert("確定要重置嗎？", isPresented: $showingResetAlert) {
                Button("取消", role: .cancel) { }
                Button("確認重置", role: .destructive) { resetAllProgress() }
            } message: { Text("這將會清除您所有的熟記與錯題紀錄。") }
            .onAppear {
                if notificationTime > 0 {
                    reminderDate = Date(timeIntervalSince1970: notificationTime)
                }
            }
        }
    }
    
    func resetAllProgress() {
        UserDefaults.standard.removeObject(forKey: "SavedMasteredWords")
        UserDefaults.standard.removeObject(forKey: "SavedReviewWords")
        UserDefaults.standard.removeObject(forKey: "LastSelectedCategory")
        UserDefaults.standard.removeObject(forKey: "LastViewedWordID")
        for i in 0..<wordList.count {
            wordList[i].isMastered = false
            wordList[i].isReviewNeeded = false
        }
        todayCount = 0
    }
}

// MARK: - 7. 通知管理器
class NotificationManager {
    static let shared = NotificationManager()
    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted { print("通知權限已獲取") }
        }
    }
    func scheduleNotification(at date: Date) {
        cancelNotification()
        let content = UNMutableNotificationContent()
        content.title = "該背單字囉！📝"
        content.body = "今天的目標完成了嗎？花 15 分鐘來充實自己吧！"
        content.sound = .default
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "DailyReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
        print("已設定每日通知：\(components.hour!):\(components.minute!)")
    }
    func cancelNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["DailyReminder"])
        print("已取消通知")
    }
}

// MARK: - 8. 卡片 UI (不變)
struct FrontCardView: View {
    let word: TOEICWord
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 12) {
                Text(word.english).font(.system(size: 40, weight: .heavy)).foregroundColor(.black).multilineTextAlignment(.center)
                Text(word.partOfSpeech).font(.headline).foregroundColor(.blue).padding(.vertical, 5).padding(.horizontal, 15).background(Color.blue.opacity(0.1)).cornerRadius(10)
            }
            Spacer()
            Text("點擊翻面 / 左右滑動切換").font(.footnote).foregroundColor(.gray.opacity(0.5)).padding(.bottom, 20)
        }
    }
}

struct BackCardView: View {
    @Binding var word: TOEICWord
    let synthesizer = AVSpeechSynthesizer()
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                Text(word.chinese).font(.largeTitle).fontWeight(.bold).foregroundColor(.black).multilineTextAlignment(.center)
                Divider().padding(.horizontal, 30)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Example:").font(.headline).fontWeight(.bold).foregroundColor(.blue.opacity(0.7)).textCase(.uppercase)
                        Spacer()
                        Button(action: { speak(text: word.example) }) {
                            HStack(spacing: 5) {
                                Image(systemName: "play.circle.fill").font(.title3)
                                Text("Play").font(.caption).fontWeight(.bold)
                            }
                            .foregroundColor(.blue).padding(.vertical, 4).padding(.horizontal, 10).background(Color.blue.opacity(0.1)).cornerRadius(15)
                        }
                    }
                    Text(word.example).font(.title3).fontWeight(.medium).foregroundColor(.gray).italic().multilineTextAlignment(.leading).fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 25)
            }
            Spacer()
            ZStack {
                if word.isMastered {
                    HStack { Image(systemName: "star.fill").foregroundColor(.yellow); Text("已熟記").font(.headline).foregroundColor(.gray) }
                }
            }
            .frame(height: 40).padding(.bottom, 10)
        }
    }
    func speak(text: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
