import SwiftUI

struct IOSLoginView: View {
    @Bindable var authState: AuthState
    let client: LiveNetworkClient

    @State private var email = ""
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("AlphaLoop")
                    .font(.largeTitle.bold())
                Text("远程量化交易终端")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            TextField("邮箱", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)

            SecureField("密码", text: $password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)

            if let error = authState.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await authState.login(email: email, password: password, client: client) }
            } label: {
                HStack {
                    if authState.isLoading { ProgressView() }
                    Text(authState.isLoading ? "登录中…" : "登录")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(authState.isLoading || email.isEmpty || password.isEmpty)

            Text("服务端地址：\(IOSConfig.apiBaseURL.absoluteString)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(24)
    }
}
