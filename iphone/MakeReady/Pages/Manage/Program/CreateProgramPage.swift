//
//  CreateProgramPage.swift
//  MakeReady
//
//  Created by Claude on 2025-11-22.
//

import SwiftUI

struct CreateProgramPage: View {
    let overlayManager: OverlayManager

    // Form state
    @State private var programName = ""
    @State private var description = ""
    @State private var selectedTemplateId: String? = nil
    @State private var selectedTemplateName: String = "Select a template"
    @State private var programDays = "30"
    @State private var isPublished = false
    @State private var tags: [String] = []
    @State private var coverImage: UIImage?

    // Program state (after creation)
    @State private var currentProgram: StudyProgram?

    // Navigation state
    @State private var showProgramHome = false
    @State private var selectedTab = 0
    @State private var editingLesson: Lesson? = nil
    @State private var showEditDay = false

    // Delete confirmation
    @State private var lessonToDelete: Lesson? = nil
    @State private var showDeleteConfirmation = false

    // Loading state
    @State private var isCreating = false

    // Validation state
    @State private var showValidationErrors = false
    @State private var scrollProxy: ScrollViewProxy?

    // Focus management
    @FocusState private var focusedField: FormField?

    enum FormField {
        case programName
        case description
    }

    private var isNameEmpty: Bool {
        programName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var isTemplateEmpty: Bool {
        selectedTemplateId == nil
    }

    // Computed: Convert Lesson array to CardLessonData for UI
    // Uses same .lesson mode as ProgramHomePage for consistent appearance
    private var lessonCards: [CardLessonData] {
        guard let lessons = currentProgram?.lessons else { return [] }
        return lessons.sorted(by: { $0.dayNumber < $1.dayNumber }).map { lesson in
            let activityDataList = lesson.activities.sorted(by: { $0.orderNumber < $1.orderNumber }).map { activity -> LessonActivityData in
                let icon: String
                let title: String

                icon = ActivityStyle.icon(for: activity.type)
                switch activity.type {
                case .soap, .oia, .dbs, .hear:
                    title = activity.title ?? activity.passageReference ?? activity.type.displayName
                default:
                    title = activity.title ?? activity.type.displayName
                }

                return LessonActivityData(
                    icon: icon,
                    type: activity.type.rawValue,
                    title: title,
                    isConfigured: activity.isConfigured,
                    status: activity.isConfigured ? .complete : .incomplete
                )
            }

            return CardLessonData(
                id: lesson.id,
                day: lesson.dayNumber,
                mode: .lesson,
                activities: activityDataList,
                title: lesson.title ?? currentProgram?.templateName,
                estimatedMinutes: lesson.totalEstimatedMinutes,
                onTap: nil
            )
        }
    }

    // Computed properties
    private var isFormValid: Bool {
        !programName.trimmingCharacters(in: .whitespaces).isEmpty && selectedTemplateId != nil
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Create program form
                    createProgramView
                        .frame(width: geometry.size.width)

                    // Program home (after creation)
                    programHomeView
                        .frame(width: geometry.size.width)

                    // Edit day (when editing a specific day)
                    if let lesson = editingLesson, let program = currentProgram {
                        EditDay(
                            isPresented: $showEditDay,
                            programId: program.id,
                            lesson: lesson,
                            onLessonUpdated: { updatedLesson in
                                // Update the lesson in our local program state
                                if var program = currentProgram,
                                   var lessons = program.lessons,
                                   let index = lessons.firstIndex(where: { $0.id == updatedLesson.id }) {
                                    lessons[index] = updatedLesson
                                    program.lessons = lessons
                                    currentProgram = program
                                }
                            },
                            onShowAddActivityMenu: { existingTypes, callback in
                                overlayManager.present(id: OverlayID.addActivityMenu, priority: .topLevel) {
                                    AddActivityMenu(
                                        overlayManager: overlayManager,
                                        existingActivityTypes: existingTypes,
                                        onActivitySelected: { activityType in
                                            callback(activityType)
                                        }
                                    )
                                }
                            }
                        )
                        .id(lesson.id)  // Force view recreation when lesson changes
                        .frame(width: geometry.size.width)
                    }
                }
                .offset(x: currentOffset(for: geometry.size.width))
                .animation(Motion.standard, value: showProgramHome)
                .animation(Motion.standard, value: showEditDay)
            }

            // Loading overlay
            if isCreating {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)

                    Text("Creating Program")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }

    private func currentOffset(for width: CGFloat) -> CGFloat {
        if showEditDay {
            return -width * 2  // Show EditDay (third screen)
        } else if showProgramHome {
            return -width      // Show programHomeView (second screen)
        } else {
            return 0           // Show createProgramView (first screen)
        }
    }
    
    // MARK: - Create Program View
    
    private var createProgramView: some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                PageTitle.iconTitleLink(
                    title: "New Study Program",
                    leftIcon: "xmark",
                    rightLink: "Create",
                    onLeftIconTap: {
                        overlayManager.dismiss(id: OverlayID.createProgram)
                    },
                    onRightLinkTap: {
                        if isFormValid {
                            createProgram()
                        } else {
                            withAnimation(Motion.standardBrisk) {
                                showValidationErrors = true
                            }
                            // Scroll to first invalid field
                            if isNameEmpty {
                                scrollProxy?.scrollTo("field_programName", anchor: .center)
                                focusedField = .programName
                            } else if isTemplateEmpty {
                                scrollProxy?.scrollTo("field_template", anchor: .center)
                            }
                        }
                    }
                )

                // Scrollable content
                ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 20) {
                        // Cover image (hero component)
                        CoverImagePicker(
                            selectedImage: $coverImage,
                            programName: programName,
                            programDescription: description
                        )
                        .padding(.top, 0)

                        // Program name
                        FieldGroup {
                            TextInput(
                                floatingLabel: "Program name",
                                autocorrect: true,
                                text: $programName
                            )
                            .focused($focusedField, equals: .programName)
                            .submitLabel(.next)
                            .onSubmit {
                                focusedField = .description
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.red.opacity(showValidationErrors && isNameEmpty ? 0.8 : 0), lineWidth: 1.5)
                        )
                        .overlay(alignment: .topLeading) {
                            if showValidationErrors && isNameEmpty {
                                Text("Required")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(4)
                                    .padding(.leading, 12)
                                    .offset(y: -14)
                                    .transition(.opacity)
                            }
                        }
                        .id("field_programName")
                        .padding(.horizontal, 16)

                        // Description
                        FieldGroup {
                            MultilineTextInput(
                                placeholder: "Describe the purpose of this program",
                                text: $description,
                                minHeight: 130,
                                autocorrect: true
                            )
                            .focused($focusedField, equals: .description)
                        }
                        .padding(.horizontal, 16)

                        // Lesson template
                        FieldGroup {
                            MenuInput(
                                label: "Lesson template",
                                options: AppState.shared.orderedTemplates.map {
                                    MenuInputOption($0.name, description: $0.description)
                                },
                                selectedOption: $selectedTemplateName
                            )
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(Color.red.opacity(showValidationErrors && isTemplateEmpty ? 0.8 : 0), lineWidth: 1.5)
                        )
                        .overlay(alignment: .topLeading) {
                            if showValidationErrors && isTemplateEmpty {
                                Text("Required")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.red.opacity(0.9))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(4)
                                    .padding(.leading, 12)
                                    .offset(y: -14)
                                    .transition(.opacity)
                            }
                        }
                        .id("field_template")
                        .padding(.horizontal, 16)

                        // Days with description in single FieldGroup
                        FieldGroup {
                            // Days input
                            MenuInput(
                                label: "Days",
                                options: (1...360).map { "\($0)" },
                                selectedOption: $programDays,
                                style: .wheel
                            )

                            // Divider and description
                            FieldGroupDivider()
                            FieldGroupDescription(text: "Select the total number of days you want in your study. This number can be updated at any time.")
                        }
                        .padding(.horizontal, 16)

                        // Publish toggle
                        ToggleGroup {
                            ToggleControl(
                                title: "Publish program",
                                description: "Published programs can be enrolled by groups. Draft programs are only visible to you.",
                                isOn: $isPublished
                            )
                        }
                        .padding(.horizontal, 16)

                        // Tags
                        TagInput(
                            tags: $tags,
                            placeholder: "Add tag..."
                        )
                        .padding(.horizontal, 16)

                        // Bottom padding (extra space so keyboard doesn't cover tags input)
                        Spacer()
                            .frame(height: KeyboardState.shared.isVisible ? KeyboardState.shared.height + 40 : 40)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .onAppear { scrollProxy = proxy }
                }
            }
        }
        .keyboardManaged()
        .onChange(of: selectedTemplateName) { _, newValue in
            // Find the matching template and set the ID
            selectedTemplateId = AppState.shared.orderedTemplates
                .first(where: { $0.name == newValue })?.id
        }
        .onChange(of: programName) { _, _ in
            if showValidationErrors && !isNameEmpty && !isTemplateEmpty {
                withAnimation(Motion.micro) { showValidationErrors = false }
            }
        }
        .onChange(of: selectedTemplateId) { _, _ in
            if showValidationErrors && !isNameEmpty && !isTemplateEmpty {
                withAnimation(Motion.micro) { showValidationErrors = false }
            }
        }
    }
    
    // MARK: - Program Home View
    
    private var programHomeView: some View {
        ZStack(alignment: .top) {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header with close button
                PageTitle.iconIcon(
                    leftIcon: "xmark",
                    rightIcon: "gearshape",
                    onLeftIconTap: {
                        overlayManager.dismiss(id: OverlayID.createProgram)
                    },
                    onRightIconTap: {
                        print("Settings tapped")
                    }
                )

                // Scrollable content
                ScrollView {
                    VStack(spacing: 20) {
                        // Cover image picker
                        CoverImagePicker(
                            selectedImage: $coverImage,
                            programName: programName,
                            programDescription: description,
                            mode: .display
                        )

                        // Tab slider
                        TabSlider(
                            tabs: ["Lessons", "Enrollments", "Analytics"],
                            selectedIndex: $selectedTab
                        )
                        .padding(.horizontal, 16)

                        // Tab content
                        Group {
                            switch selectedTab {
                            case 0:
                                studiesContent
                            case 1:
                                enrollmentsContent
                            case 2:
                                analyticsContent
                            default:
                                EmptyView()
                            }
                        }

                        Spacer()
                            .frame(height: 40)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Tab Content Views

    @ViewBuilder
    private var studiesContent: some View {
        VStack(spacing: 4) {
            ForEach(lessonCards, id: \.id) { lessonData in
                SwipeableCard(
                    slideButtons: [
                        SlideButton(icon: "trash", style: .delete) {
                            // Find the actual Lesson object to delete
                            if let lesson = currentProgram?.lessons?.first(where: { $0.id == lessonData.id }) {
                                lessonToDelete = lesson
                                showDeleteConfirmation = true
                            }
                        }
                    ],
                    onTap: {
                        // Find the actual Lesson object to edit
                        if let lesson = currentProgram?.lessons?.first(where: { $0.id == lessonData.id }) {
                            editingLesson = lesson
                            showEditDay = true
                        }
                    }
                ) {
                    CardLesson(data: lessonData)
                }
            }
        }
        .padding(.horizontal, 16)
        .alert("Delete Day \(lessonToDelete?.dayNumber ?? 0)?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                lessonToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let lesson = lessonToDelete {
                    deleteLesson(lesson)
                }
                lessonToDelete = nil
            }
        } message: {
            Text("This will remove this day and all its activities from the program.")
        }
    }

    private func deleteLesson(_ lesson: Lesson) {
        guard let programId = currentProgram?.id else { return }

        Task {
            do {
                try await ProgramActions().deleteLesson(programId: programId, lessonId: lesson.id)

                // Update local state
                await MainActor.run {
                    if var program = currentProgram,
                       var lessons = program.lessons {
                        // Remove the lesson
                        lessons.removeAll { $0.id == lesson.id }

                        // Renumber remaining lessons
                        for i in lessons.indices {
                            if lessons[i].dayNumber > lesson.dayNumber {
                                lessons[i].dayNumber -= 1
                            }
                        }

                        program.lessons = lessons
                        program.days -= 1
                        currentProgram = program
                    }
                }
            } catch {
                NSLog("Failed to delete lesson: \(error)")
            }
        }
    }
    
    @ViewBuilder
    private var enrollmentsContent: some View {
        VStack(spacing: 12) {
            Spacer()
                .frame(height: 40)

            Image(systemName: "person.3")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.3))

            Text("No enrollments yet")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.white.opacity(0.5))

            Text("Groups enrolled in this program will appear here")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.3))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
    }
    
    @ViewBuilder
    private var analyticsContent: some View {
        VStack {
            Spacer()
                .frame(height: 80)

            Text("Coming soon")
                .font(.system(size: 17))
                .foregroundColor(.white.opacity(0.5))

            Spacer()
        }
    }

    // MARK: - Actions

    private func createProgram() {
        guard !isCreating else { return }
        isCreating = true

        guard let templateId = selectedTemplateId else { return }

        NSLog("📝 Creating program:")
        NSLog("  Name: \(programName)")
        NSLog("  Description: \(description)")
        NSLog("  Template: \(selectedTemplateName) (\(templateId))")
        NSLog("  Days: \(programDays)")
        NSLog("  Has cover image: \(coverImage != nil)")

        Task {
            do {
                let days = Int(programDays) ?? 30

                // First, create the program without cover image to get the ID
                let program = try await ProgramActions().createProgram(
                    name: programName,
                    description: description.isEmpty ? nil : description,
                    templateId: templateId,
                    days: days,
                    coverImageUrl: nil,
                    isPublished: isPublished
                )

                // If we have a cover image, upload it via server endpoint
                var finalProgram = program
                if let image = coverImage {
                    do {
                        // Upload cover image via server
                        let coverImageUrl = try await ProgramActions().uploadCoverImage(
                            programId: program.id,
                            image: image
                        )
                        // Refresh program to get updated data with cover image URL
                        let result = try await ProgramActions().getProgram(id: program.id)
                        finalProgram = result.program
                        NSLog("📸 Cover image uploaded: \(coverImageUrl)")
                    } catch {
                        NSLog("⚠️ Failed to upload cover image (continuing anyway): \(error)")
                        // Continue without cover image - program was still created successfully
                    }
                }

                // Save tags if any
                if !tags.isEmpty {
                    try? await ProgramActions().addTags(programId: finalProgram.id, tags: tags)
                    finalProgram.tags = tags
                }

                await MainActor.run {
                    currentProgram = finalProgram
                    isCreating = false
                    showProgramHome = true
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                }
                NSLog("Failed to create program: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let now = Date()
    let state = AppState.shared
    state.templates.replaceAll([
        LessonTemplate(id: "t1", name: "SOAP", description: "Read Scripture, make Observations, note Application, and close with Prayer.", createdAt: now, updatedAt: now),
        LessonTemplate(id: "t2", name: "OIA", description: "Observe the text, Interpret its meaning, then Apply it to life.", createdAt: now, updatedAt: now),
        LessonTemplate(id: "t3", name: "Custom", description: "Create your own activity structure for each lesson.", createdAt: now, updatedAt: now)
    ])
    return CreateProgramPage(overlayManager: OverlayManager())
}
