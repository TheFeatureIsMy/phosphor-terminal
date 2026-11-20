import SwiftUI

struct IOSLoginView: View {
    @Bindable var authState: AuthState
    let client: LiveNetworkClient

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            IOSTheme.backgroundView
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 9)
                            .fill(IOSTheme.accent)
                            .frame(width: 38, height: 38)
                            .overlay(Image(systemName: "arrow.up.right").font(.system(size: 17, weight: .bold)).foregroundStyle(IOSTheme.onAccent))
                        Text("ALPHALOOP").font(.system(size: 18, weight: .heavy, design: .rounded)).tracking(0.5)
                        Spacer()
                    }
                    .padding(.top, 30)

                    VStack(alignment: .leading, spacing: 8) {
                        IOSSectionLabel(text: "Remote terminal")
                        Text("登录交易终端")
                            .font(IOSTheme.title)
                            .foregroundStyle(IOSTheme.text)
                        Text("远程量化交易终端 · 手机端")
                            .font(IOSTheme.mono)
                            .foregroundStyle(IOSTheme.textSecondary)
                    }

                    VStack(spacing: 12) {
                        field("邮箱") {
                            TextField("you@example.com", text: $email)
                                .textContentType(.emailAddress)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                        }
                        field("密码") {
                            SecureField("••••••••", text: $password)
                                .textContentType(.password)
                        }
                    }
                    .iosCard()

                    if let error = authState.errorMessage {
                        Text(error)
                            .font(IOSTheme.mono)
                            .foregroundStyle(IOSTheme.bear)
                    }

                    Button {
                        Task { await authState.login(email: email, password: password, client: client) }
                    } label: {
                        HStack(spacing: 8) {
                            if authState.isLoading { ProgressView().tint(IOSTheme.onAccent) }
                            Text(authState.isLoading ? "登录中…" : "登录")
                                .font(.system(size: 15, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(IOSTheme.accent)
                        .foregroundStyle(IOSTheme.onAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(authState.isLoading || email.isEmpty || password.isEmpty)
                    .opacity(authState.isLoading || email.isEmpty || password.isEmpty ? 0.5 : 1)

                    Text("服务端地址：\(IOSConfig.apiBaseURL.absoluteString)")
                        .font(IOSTheme.monoLabel)
                        .foregroundStyle(IOSTheme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(24)
            }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            IOSSectionLabel(text: label)
            content()
                .font(IOSTheme.mono)
                .foregroundStyle(IOSTheme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(IOSTheme.surface)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(IOSTheme.border, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}
