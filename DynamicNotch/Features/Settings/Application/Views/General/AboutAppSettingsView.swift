//
//  AboutAppSettingsView.swift
//  DynamicNotch
//

import SwiftUI

struct AboutAppSettingsView: View {
    @Environment(\.openURL) private var openURL
    @ObservedObject var applicationSettings: ApplicationSettingsStore
    
    let onRequestInternetAccess: () -> Bool
    
    private func text(_ en: String, _ ko: String) -> String {
        privacyText(en, ko)
    }
    
    private var appVersionText: String {
        if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return "v\(version)"
        }
        return "Notchie"
    }
    
    var body: some View {
        SettingsPageScrollView {
            headerCard
            customFeaturesCard
            openSourceNoticeCard
            buildInfoCard
        }
        .accessibilityIdentifier("settings.about.root")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Text(appVersionText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
            }
        }
    }
    
    private var headerCard: some View {
        VStack(spacing: 16) {
            Image("logo")
                .resizable()
                .interpolation(.high)
                .antialiased(true)
                .scaledToFill()
                .frame(width: 90, height: 90)
                .cornerRadius(20)
                .scaleEffect(0.9)
                .background(LinearGradient.logoGradient.blur(radius: 20))
                .padding(.top, 20)
            
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text("Notchie")
                        .font(.system(size: 22, weight: .bold))
                    Text(text("Custom Edition", "커스텀 에디션"))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(applicationSettings.customAccentColor.opacity(0.18), in: Capsule())
                        .foregroundStyle(applicationSettings.customAccentColor)
                }
                
                Text(text(
                    "Your personalized open-source macOS notch workspace with hover shelf, clipboard search, face unlock, and productivity tools.",
                    "노치 호버 메뉴, 클립보드 히스토리 검색, 카메라 얼굴 잠금 해제 및 생산성 도구를 결합한 나만의 맞춤형 오픈소스 macOS 노치 워크스페이스입니다."
                ))
                .font(.system(size: 13.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            }
        }
    }
    
    private var customFeaturesCard: some View {
        SettingsCard(verbatimTitle: text("What's Customized in Notchie", "Notchie 주요 맞춤 기능"), spacing: 12) {
            featureRow(
                icon: "menubar.dock.rectangle",
                color: .mint,
                title: text("Notch Hover Shelf & Customizable Tabs", "노치 호버 메뉴 & 맞춤 탭 구성"),
                detail: text("Hover over the idle notch to open your shelf and toggle the exact tabs you want.", "유휴 노치에 마우스를 올리면 메뉴가 열리며 원하는 탭만 골라 배치할 수 있습니다.")
            )
            Divider().opacity(0.6)
            featureRow(
                icon: "doc.on.clipboard.fill",
                color: .blue,
                title: text("Clipboard History, Search & One-Click Copy", "클립보드 히스토리 검색 및 원클릭 재복사"),
                detail: text("Search copied items instantly and re-copy with a single click.", "저장된 클립보드 내역을 실시간으로 검색하고 클릭 한 번으로 다시 복사합니다.")
            )
            Divider().opacity(0.6)
            featureRow(
                icon: "faceid",
                color: .green,
                title: text("Camera Face Unlock & Notch Style Preview", "카메라 얼굴 잠금 해제 & 노치 스타일 미리보기"),
                detail: text("Full-badge scan animation (Original) or compact lock bar (Minimal) with live notch preview and app privacy cover.", "전체 배지 스캔(오리지널)과 미니멀 바 스타일을 노치에서 바로 미리보고 사용할 수 있습니다.")
            )
            Divider().opacity(0.6)
            featureRow(
                icon: "paintpalette.fill",
                color: .orange,
                title: text("Custom Accent Color & Hover Sensitivity", "맞춤 강조 색상 및 호버 감도 조절"),
                detail: text("Personalize accent colors with a color picker, hover delay timing, and launch-at-login.", "커스텀 컬러 피커로 강조 색상을 지정하고 호버 반응 속도 및 로그인 시 실행을 제어합니다.")
            )
        }
    }
    
    private func featureRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
    
    private var openSourceNoticeCard: some View {
        SettingsCard(verbatimTitle: text("Open Source & License Notice", "오픈소스 라이선스 및 기반 프로젝트"), spacing: 10) {
            Text(text(
                "Notchie is a customized personal build distributed under GPL-3.0, combining and extending open-source foundations:",
                "Notchie는 오픈소스 프로젝트를 기반으로 다양한 맞춤 기능을 직접 추가·개선하여 제작한 나만의 앱입니다 (GPL-3.0 라이선스 준수):"
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                Button {
                    open("https://github.com/jackson-storm/DynamicNotch")
                } label: {
                    Label("DynamicNotch (GPL-3.0)", systemImage: "link")
                }
                .buttonStyle(.link)
                
                Button {
                    open("https://github.com/iharshitmaurya/HeyMac")
                } label: {
                    Label("HeyMac (MIT)", systemImage: "link")
                }
                .buttonStyle(.link)
            }
            .font(.caption)
        }
    }
    
    private var buildInfoCard: some View {
        SettingsCard(title: "support.build.title") {
            HStack {
                Text(text("Build Revision", "빌드 리비전"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "DynamicNotchLocalRevision") as? String ?? "Notchie-Custom")
                    .font(.system(.caption, design: .monospaced))
            }
            Text(Bundle.main.bundleURL.path)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
    
    private func open(_ value: String) {
        guard let url = URL(string: value), onRequestInternetAccess() else { return }
        openURL(url)
    }
}
