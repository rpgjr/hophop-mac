import SwiftUI

/// Shown until a valid authenticator code is entered, at every launch and after the session ends.
struct LoginView: View {
    @Environment(ApplicationStore.self) private var store

    @State private var code = ""
    @State private var busy = false
    @State private var error: String?

    private var digits: String { code.filter(\.isNumber) }
    private var ready: Bool { digits.count == 6 }

    var body: some View {
        VStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "hare.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(HH.onPrimary)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 10).fill(HH.primary))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sign in to HopHop")
                            .font(HH.display(18))
                            .foregroundStyle(HH.ink)
                        Text("Enter the 6-digit code from Google Authenticator.")
                            .font(HH.font(13))
                            .foregroundStyle(HH.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                HHTextField(
                    label: "Authenticator code",
                    text: $code,
                    prompt: "000000",
                    mono: true,
                    onSubmit: { Task { await submit() } }
                )
                .onChange(of: code) { _, new in
                    let cleaned = String(new.filter { $0.isNumber || $0 == " " }.prefix(7))
                    if cleaned != new { code = cleaned }
                    // a pasted or typed sixth digit signs in without pressing Return
                    if cleaned.filter(\.isNumber).count == 6 { Task { await submit() } }
                }

                if let error {
                    HHNotice(tone: .error, text: error)
                }

                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: 8) {
                        if busy { HHSpinner() }
                        Text("Sign in").frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.hh(.primary))
                .keyboardShortcut(.defaultAction)
                .disabled(!ready || busy)
            }
            .padding(26)
            .frame(width: 400)
            .hhCard(radius: 14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func submit() async {
        guard ready, !busy else { return }
        busy = true
        error = nil
        defer { busy = false }

        if let message = await store.signIn(code: digits) {
            error = message
            code = ""
        }
    }
}
