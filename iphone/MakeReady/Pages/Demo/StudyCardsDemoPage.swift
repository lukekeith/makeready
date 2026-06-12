// DEBUG-ONLY (Phase 5.5): demo pages ship in no release binary.
#if DEBUG
//
//  StudyCardsDemoPage.swift
//  MakeReady
//
//  Performance test demo for SearchableList with 100+ study cards
//

import SwiftUI

struct StudyCardsDemoPage: View {
    let overlayManager: OverlayManager

    // Generate 120 study cards for performance testing
    private let studyCards: [CardStudyData] = {
        let topics = ["Biology", "Chemistry", "Physics", "Mathematics", "History", "Literature", "Geography", "Computer Science"]
        let difficulties = ["Beginner", "Intermediate", "Advanced"]

        let cardTitles = [
            "A Cell Structure and Function", "A DNA Replication Process", "A Photosynthesis Mechanics",
            "B Atomic Theory Basics", "B Chemical Bonding Types", "B Periodic Table Trends",
            "C Newton's Laws of Motion", "C Quantum Mechanics Intro", "C Thermodynamics Principles",
            "D Calculus Fundamentals", "D Linear Algebra Concepts", "D Probability Theory",
            "E World War II Overview", "E Ancient Civilizations", "E Renaissance Period",
            "F Shakespeare Analysis", "F Modern Poetry Themes", "F Classical Literature",
            "G Continental Drift Theory", "G Climate Zones", "G Geological Time Scale",
            "H Data Structures Basics", "H Algorithms Analysis", "H Object-Oriented Programming",
            "I Cell Division Process", "I Genetic Inheritance", "I Evolution Theory",
            "J Acid-Base Reactions", "J Organic Chemistry Intro", "J Electrochemistry Basics",
            "K Wave Mechanics", "K Optics and Light", "K Electromagnetism Fundamentals",
            "L Trigonometry Functions", "L Statistics Methods", "L Number Theory",
            "M Cold War Era", "M Industrial Revolution", "M French Revolution",
            "N Gothic Literature", "N Romanticism Movement", "N Realism in Fiction",
            "O Weather Patterns", "O Ocean Currents", "O Mountain Formation",
            "P Database Design", "P Network Protocols", "P Software Engineering",
            "Q Mitochondrial Function", "Q Protein Synthesis", "Q Cellular Respiration",
            "R Chemical Equilibrium", "R Redox Reactions", "R Solution Chemistry",
            "S Relativity Theory", "S Particle Physics", "S Nuclear Energy",
            "T Geometry Theorems", "T Matrix Operations", "T Set Theory",
            "U Medieval History", "U Victorian Era", "U American Revolution",
            "V Modernist Literature", "V Postmodern Themes", "V Literary Criticism",
            "W Plate Tectonics", "W Ecosystems Study", "W Natural Resources",
            "X Machine Learning Basics", "X Artificial Intelligence", "X Cryptography Intro",
            "Y Molecular Biology", "Y Immunology Concepts", "Y Neuroscience Basics",
            "Z Polymer Chemistry", "Z Analytical Methods", "Z Environmental Chemistry"
        ]

        return cardTitles.enumerated().map { index, title in
            let topicIndex = index % topics.count
            let difficultyIndex = index % difficulties.count
            let isPending = index % 5 == 0  // Every 5th card is pending
            let questionCount = Int.random(in: 10...50)
            
            // 70% of cards use photos, 30% use default icon
            let usePhoto = (index % 10) < 7  // 7 out of 10 = 70%
            let imageStyle: CardImageStyle
            
            if usePhoto {
                // Use Unsplash images for demonstration (random seed based on index for variety)
                let imageURL = "https://picsum.photos/seed/study\(index)/144/216"
                imageStyle = .photo(imageURL: imageURL)
            } else {
                imageStyle = .icon(systemName: "book.fill", backgroundColor: .purple)
            }

            return CardStudyData(
                id: "study-\(index)",
                title: title,
                description: "\(topics[topicIndex]) • \(difficulties[difficultyIndex])",
                type: nil,
                imageStyle: imageStyle,
                metadata: [
                    DataItem(icon: "questionmark.circle", value: "\(questionCount)")
                ],
                status: isPending ? .pending : .confirmed,
                onTap: nil
            )
        }
    }()

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            // SearchableList with 120 study cards
            SearchableList(
                items: studyCards,
                filterPredicate: { card, query in
                    let lowercaseQuery = query.lowercased()
                    return card.title.lowercased().contains(lowercaseQuery) ||
                           card.description?.lowercased().contains(lowercaseQuery) ?? false
                },
                placeholder: "Search study cards",
                showAlphabetScrubber: false,
                sectionKeyPath: nil,
                autoFocusSearch: false  // Prevent keyboard from auto-appearing
            ) { card in
                // Wrap CardStudy in SwipeableCard with three action buttons
                SwipeableCard(
                    slideButtons: [
                        SlideButton(icon: "play.fill", style: .skip) {
                            print("Play card: \(card.title)")
                        },
                        SlideButton(icon: "clock", style: .reschedule) {
                            print("Schedule card: \(card.title)")
                        },
                        SlideButton(icon: "trash", style: .delete) {
                            print("Delete card: \(card.title)")
                        }
                    ],
                    isSwipeEnabled: true
                ) {
                    CardStudy(data: card)
                }
            } header: {
                PageTitle.iconTitle(
                    title: "Study Cards Demo",
                    icon: "xmark",
                    onIconTap: { overlayManager.dismiss(.studyCardsDemoPage) }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    StudyCardsDemoPage(overlayManager: OverlayManager())
}
#endif
