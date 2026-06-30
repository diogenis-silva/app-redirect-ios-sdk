# AppRedirect iOS SDK

SDK Swift para **Deep Link** e **Deferred Deep Link** da plataforma App Redirect. Abre o app
diretamente quando instalado (Universal Links), redireciona para a App Store quando não, e
recupera os parâmetros do clique original após a instalação (deferred deep link).

- Sem dependências externas — apenas `Foundation` + `UIKit`
- Atribuição por **fingerprint** (padrão, sem prompt) ou **clipboard + fingerprint** (opt-in, ~95%)
- Fila persistente de eventos com retry: nunca perde um evento offline e nunca crasha o app

## Requisitos

- iOS 16+
- Swift 6.2 / Xcode 26+

## Instalação (Swift Package Manager)

### Xcode

**File → Add Package Dependencies…** e cole a URL:

```
https://github.com/diogenis-silva/app-redirect-ios-sdk.git
```

Regra de dependência: **Up to Next Major Version**, a partir de `1.0.0`.

### Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/diogenis-silva/app-redirect-ios-sdk.git", from: "1.0.0")
],
targets: [
    .target(
        name: "SeuApp",
        dependencies: [
            .product(name: "AppRedirect", package: "app-redirect-ios-sdk")
        ]
    )
]
```

## Uso

### 1. Inicialização

Chame em `application(_:didFinishLaunchingWithOptions:)`:

```swift
import AppRedirect

// Padrão: fingerprint apenas (~80%), sem prompt de colar do iOS
AppRedirect.configure(
    apiKey: "dlk_...",
    baseURL: URL(string: "https://api.seudominio.com")!
)

// Opt-in: clipboard + fingerprint (~95%), 1 prompt de colar no first-open
AppRedirect.configure(
    apiKey: "dlk_...",
    baseURL: URL(string: "https://api.seudominio.com")!,
    deferredDeepLink: .clipboardAndFingerprint
)
```

### 2. Deferred Deep Link

Na primeira abertura. É idempotente — chamadas subsequentes retornam `nil`:

```swift
// async/await (iOS 15+)
if let result = await AppRedirect.checkDeferredDeepLink(), result.hasDeepLink {
    navigate(to: result.destination!)
}

// callback (iOS 14+)
AppRedirect.checkDeferredDeepLink { result in
    guard let result, result.hasDeepLink else { return }
    navigate(to: result.destination!)
}
```

### 3. Universal Links

```swift
func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    _ = AppRedirect.handleUserActivity(userActivity)
}
```

### 4. Custom URL Scheme

```swift
func application(_ app: UIApplication, open url: URL,
                 options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
    AppRedirect.handleOpenURL(url)
}
```

### 5. Eventos

```swift
AppRedirect.track("purchase", properties: ["value": 49.90, "currency": "BRL"])
AppRedirect.track("purchase", revenue: 49.90)   // atalho para eventos de receita
```

## Configuração necessária no app

Para que os **Universal Links** abram o app (e não a loja), habilite **Associated Domains**
no target e adicione a entrada `applinks:` apontando para o seu domínio de redirect:

```
applinks:links.seudominio.com
```

## Licença

[MIT](LICENSE)
