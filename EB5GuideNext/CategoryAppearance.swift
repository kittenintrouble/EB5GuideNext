import SwiftUI

struct CategoryAppearance {
    let iconName: String
    let gradient: LinearGradient
    let primaryColor: Color

    static func forCategory(_ name: String) -> CategoryAppearance {
        switch name {
        case "Compliance":
            return CategoryAppearance(
                iconName: "book.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.36, green: 0.63, blue: 0.99), Color(red: 0.11, green: 0.32, blue: 0.85)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.22, green: 0.42, blue: 0.87)
            )
        case "EB-5 Basics":
            return CategoryAppearance(
                iconName: "graduationcap.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.73, green: 0.55, blue: 0.99), Color(red: 0.49, green: 0.28, blue: 0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.54, green: 0.32, blue: 0.93)
            )
        case "Foundations":
            return CategoryAppearance(
                iconName: "chart.bar.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.96, green: 0.54, blue: 0.83), Color(red: 0.74, green: 0.24, blue: 0.58)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.74, green: 0.24, blue: 0.58)
            )
        case "Immigration & Legal Process":
            return CategoryAppearance(
                iconName: "doc.richtext.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.34, green: 0.79, blue: 0.86), Color(red: 0.13, green: 0.53, blue: 0.67)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.16, green: 0.56, blue: 0.69)
            )
        case "Investment":
            return CategoryAppearance(
                iconName: "dollarsign.circle.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.46, green: 0.85, blue: 0.49), Color(red: 0.14, green: 0.59, blue: 0.36)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.17, green: 0.60, blue: 0.38)
            )
        case "Real Estate & Business":
            return CategoryAppearance(
                iconName: "building.2.fill",
                gradient: LinearGradient(
                    colors: [Color(red: 0.99, green: 0.64, blue: 0.40), Color(red: 0.83, green: 0.39, blue: 0.19)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.84, green: 0.40, blue: 0.20)
            )
        case "Risk Management":
            return CategoryAppearance(
                iconName: "shield.checkerboard",
                gradient: LinearGradient(
                    colors: [Color(red: 0.98, green: 0.45, blue: 0.50), Color(red: 0.78, green: 0.12, blue: 0.25)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color(red: 0.81, green: 0.21, blue: 0.30)
            )
        default:
            return CategoryAppearance(
                iconName: "square.grid.2x2.fill",
                gradient: LinearGradient(
                    colors: [Color.accentColor.opacity(0.9), Color.accentColor],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                primaryColor: Color.accentColor
            )
        }
    }

    func withIcon(_ icon: String) -> CategoryAppearance {
        CategoryAppearance(iconName: icon, gradient: gradient, primaryColor: primaryColor)
    }

    static func iconName(forSubcategory name: String) -> String? {
        let mapping: [String: String] = [
            "Program Basics": "book.closed",
            "Investment Models": "chart.pie.fill",
            "USCIS Criteria": "checkmark.seal",
            "Eligibility Requirements": "clipboard",
            "Benefits of EB-5": "star.circle.fill",
            "History of EB-5": "clock.arrow.circlepath",
            "EB-5 Visa Types": "doc.text",
            "Direct Investment": "briefcase.fill",
            "Regional Centers": "globe",
            "Targeted Employment Areas": "mappin.circle",
            "At-Risk Investments": "exclamationmark.triangle.fill",
            "Investment Amounts": "dollarsign.circle",
            "Investment Projects Types": "cube.box.fill",
            "Funding Sources": "creditcard",
            "Selecting Real Estate Projects": "building.2.crop.circle",
            "Types of Real Estate Investments": "building.2",
            "Market Analysis": "chart.line.uptrend.xyaxis",
            "Project Development Cycle": "arrow.triangle.2.circlepath",
            "Commercial vs Residential": "building.columns",
            "EB-5 Business Plan": "doc.text.magnifyingglass",
            "Case Studies": "doc.text.image",
            "EB-5 Petition Process": "doc.append",
            "EB-5 Application Forms": "doc.on.doc",
            "Green Card Process": "person.crop.circle.badge.checkmark",
            "Adjustment of Status vs Consular Processing": "airplane.departure",
            "Immigration Attorneys & Consultants": "questionmark.circle",
            "Common EB-5 Issues & Denials": "xmark.octagon",
            "Family Immigration through EB-5": "person.2",
            "EB-5 Investment Risks": "shield.slash",
            "Due Diligence Process": "magnifyingglass.circle",
            "Fraud Prevention": "hand.raised",
            "EB-5 Project Exit Strategies": "arrow.uturn.right.circle",
            "Legal and Financial Safeguards": "shield.lefthalf.filled"
        ]
        return mapping[name]
    }
}

struct GradientIcon: View {
    let appearance: CategoryAppearance
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(appearance.gradient)
                .frame(width: size, height: size)

            Image(systemName: appearance.iconName)
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
        }
    }
}
