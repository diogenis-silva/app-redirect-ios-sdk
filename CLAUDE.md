# SDK iOS — AppRedirect

## O que é este projeto

SDK Swift para integração do App Redirect (Deep Link + Deferred Deep Link) em apps iOS.
Distribuído via Swift Package Manager (source package, sem binário).

## Estrutura do repositório

```
sdk-ios/
├── Package.swift                       ← Manifest SPM (iOS 16+, swift-tools-version 6.2)
├── Sources/AppRedirect/                ← Código-fonte do SDK
│   ├── AppRedirect.swift               ← Ponto de entrada público (orquestração)
│   ├── AppRedirectConfig.swift         ← apiKey, baseURL, logLevel, janelas de retry
│   ├── AppRedirectClient.swift         ← HTTP client (URLSession) + encoder compartilhado
│   ├── AppRedirectStorage.swift        ← UserDefaults: isFirstOpen, attribution, installDate
│   ├── AppRedirectDelegate.swift       ← Protocolo de callback de deep link em runtime
│   ├── EventQueue.swift                ← Fila persistente (retry de app-open/events)
│   ├── DeepLinkResult.swift            ← Tipo público de retorno (decode tolerante)
│   ├── DeviceInfo.swift                ← Coleta de sinais do dispositivo
│   ├── Networking.swift                ← Protocolo (seam) sobre o HTTP, p/ testes
│   ├── Enums/
│   │   ├── LogLevel.swift  · DeepLinkSource.swift · AppRedirectError.swift
│   │   ├── Logger.swift  · JSONValue.swift · DeferredDeepLinkMode.swift
│   │   └── ClipboardChecker.swift      ← Lê UIPasteboard → valida payload appredirect://
│   └── Models/
│       ├── FirstOpenPayload.swift  · FirstOpenResponse.swift
│       ├── AppOpenPayload.swift
│       └── TrackEventPayload.swift
├── Tests/AppRedirectTests/             ← Testes unitários (framework Testing, Swift 6)
│   ├── TestSupport.swift               ← MockNetworking (actor) + fixtures/helpers
│   ├── JSONValueTests.swift            ├ DecodingTests.swift (decode tolerante)
│   ├── AppRedirectStorageTests.swift   ├ ClipboardCheckerTests.swift
│   ├── EventQueueTests.swift           ├ DeferredDeepLinkTests.swift (retry + clipboard)
│   └── AppOpenDedupTests.swift
└── Example/                            ← app de exemplo (ignorado pelo SPM)
    ├── ExampleApp.xcodeproj            ← referencia o pacote em ".." (relativePath)
    └── ExampleApp/                     ← ExampleApp · ContentView · DeepLinkStore
```

> O SPM distribui apenas os targets declarados em `Package.swift` (`Sources/` e `Tests/`).
> O diretório `Example/` fica no disco mas é invisível para quem instala o pacote via SPM.

## App de exemplo (`sdk-ios/Example/`)

App SwiftUI que consome o SDK como **pacote local** (`relativePath ..`). Demonstra
`configure`, `checkDeferredDeepLink`, `handleUserActivity`/`handleOpenURL`, `trackAppOpen` e `track`
(`ExampleApp` · `ContentView` · `DeepLinkStore`). Build/run:

```bash
xcodebuild build -project Example/ExampleApp.xcodeproj \
  -scheme ExampleApp -destination "platform=iOS Simulator,name=iPhone 17" CODE_SIGNING_ALLOWED=NO
```

> Para E2E real falta: Main.API de pé (`localhost:5129`) + migrations aplicadas + uma API key válida
> + exceção de ATS para `http://localhost` (`NSAllowsLocalNetworking`). O app está em
> `.clipboardAndFingerprint` (dispara o prompt de colar) — troque para `.fingerprintOnly` em
> `DeepLinkStore.bootstrap()` para o comportamento sem prompt.

## Como desenvolver

Abrir `Package.swift` diretamente no Xcode. Não há `.xcodeproj` no pacote.
Cmd+B para compilar, Cmd+U para rodar os testes.

```bash
# Build via terminal — UIKit exige target iOS, swift build compila para macOS
xcodebuild build \
  -scheme AppRedirect \
  -destination "generic/platform=iOS Simulator" \
  CODE_SIGNING_ALLOWED=NO

# Testes — exigem um simulador concreto (UIPasteboard/UIScreen)
xcodebuild test \
  -scheme AppRedirect \
  -destination "platform=iOS Simulator,name=iPhone 17" \
  CODE_SIGNING_ALLOWED=NO
```

> Os testes nunca tocam `UIPasteboard.general` (que dispararia o prompt de colar do iOS a
> cada leitura). O `ClipboardChecker` e o `AppRedirect` aceitam um `any Pasteboard` injetado;
> os testes passam `UIPasteboard.withUniqueName()` (privado do app, sem prompt, isolado por
> teste). Em produção o default é `UIPasteboard.general`.

## API pública

### Inicialização — chamar em `application(_:didFinishLaunchingWithOptions:)`

```swift
// Padrão: fingerprint apenas (~80%), sem prompt de colar do iOS
AppRedirect.configure(apiKey: "dlk_...", baseURL: "https://api.seudominio.com")

// Opt-in: clipboard + fingerprint (~95%), com 1 prompt de colar no first-open
AppRedirect.configure(
    apiKey: "dlk_...",
    baseURL: "https://api.seudominio.com",
    deferredDeepLink: .clipboardAndFingerprint
)
```

O modo `.clipboardAndFingerprint` é equivalente ao `checkPasteboardOnInstall` (opt-in) do
Branch. No modo padrão `.fingerprintOnly` o SDK **nunca** lê o `UIPasteboard` — sem prompt,
como AppsFlyer/Singular por padrão. O backend cobre os dois caminhos (a validação server-side
do `clickId` só roda quando o clipboard contribui).

### Deferred Deep Link — chamar na primeira abertura

```swift
// Callback (iOS 14+)
AppRedirect.checkDeferredDeepLink { result in
    guard let result, result.hasDeepLink else { return }
    navigate(to: result.destination!)
}

// async/await (iOS 15+)
let result = await AppRedirect.checkDeferredDeepLink()
```

Idempotente: se já foi chamado antes (UserDefaults flag), retorna `nil` imediatamente.

### Universal Links — chamar em `scene(_:willConnectTo:options:)` e `scene(_:continue:)`

```swift
AppRedirect.handleUserActivity(activity)
```

### Custom URL Scheme — chamar em `application(_:open:options:)`

```swift
AppRedirect.handleOpenURL(url)
```

### Rastrear eventos

```swift
AppRedirect.track("purchase", properties: ["value": 49.90, "currency": "BRL"])
AppRedirect.track("purchase", revenue: 49.90)  // atalho para eventos de receita
```

## Backend consumido

Todos os endpoints pertencem à `AppRedirect.Main.API`.  
Em desenvolvimento: `http://localhost:5129`.

| Endpoint | Quando chamado |
|---|---|
| `POST /mobile/v1/first-open` | Primeira abertura após instalação |
| `POST /mobile/v1/app-open` | Toda abertura subsequente |
| `POST /mobile/v1/events` | Eventos customizados |

Auth: header `X-Api-Key: dlk_...` (gerada no Admin Panel, associada ao App).

## Clipboard — deferred deep link iOS

A página de redirect do backend (`RedirectHtmlBuilder.BuildIosPage`) escreve no clipboard:

```
appredirect://d={destination_url_encoded}&c={clickId_uuid}&t={epoch_ms}
```

O `ClipboardChecker` valida três condições antes de aceitar:
1. String começa com `appredirect://`
2. Timestamp `t` é menor que 5 minutos atrás (`clipboardMaxAge`)
3. Parâmetro `d` não está vazio

**O destino do clipboard NUNCA é confiado para navegação.** O clipboard é fonte de um
único sinal de alta confiança: o `clickId`. Esse `clickId` é enviado ao `first-open`, e o
backend valida que o clique existe e retorna o **destino autoritativo**. Isso fecha o vetor
de spoofing (qualquer app/web pode escrever no clipboard geral).

O clipboard só é limpo **após** o `clickId` ser consumido com sucesso (`first-open` 200), e
apenas se o payload `appredirect://` ainda estiver lá — nunca apaga conteúdo copiado pelo
usuário (`ClipboardChecker.clear()`).

> Ler `UIPasteboard.general.string` dispara o aviso de privacidade do iOS 16 ("colou de…").
> Aceito por ocorrer uma única vez, no first-open.

## Confiabilidade da atribuição

| Mecanismo | Comportamento |
|---|---|
| `first-open` | `isFirstOpenDone` só é marcado **após** resolução real (clipboard validado ou API 200). Falha de rede **não** marca como feito → retry transparente no próximo cold start, dentro de `firstOpenRetryWindow` (24h). Após a janela, desiste para não tentar para sempre. |
| `app-open` / `events` | Fila persistente em disco (`EventQueue`, Application Support). Em falha de rede, o request é enfileirado e reenviado no próximo `trackAppOpen`/`configure`. At-least-once, FIFO, cap de 200 (descarta os mais antigos). `first-open` **não** entra na fila (tem retry próprio). |
| Cliques diretos (Universal Link / URL scheme) | `handleIncoming` extrai `clickId`/`deepLinkId` da URL (`clickId`/`c`, `deepLinkId`/`dl`), reporta o `app-open` com o link clicado e persiste como atribuição de re-engajamento. |
| Dedup de `app-open` | Debounce de 2s em memória evita contagem dupla quando Universal Link + `sceneDidBecomeActive` disparam juntos; um open com `clickId` sempre passa. |
| Modo de atribuição | `deferredDeepLink`: `.fingerprintOnly` (padrão, sem prompt) ou `.clipboardAndFingerprint` (opt-in, ~95%, 1 prompt). O clipboard só é lido no modo opt-in. |
| `confidence` | Escala **0–100**, vinda do backend (sem valor hardcoded no SDK). |
| `reset()` | Limpa `isFirstOpenDone` e atribuição (logout); preserva `installDate`. |

## Decisões de design

| Decisão | Escolha | Motivo |
|---|---|---|
| Dependências externas | Nenhuma | Foundation + UIKit são suficientes |
| iOS mínimo | 16 | Cobre >98% dos dispositivos em 2026, URLSession async nativo |
| Thread safety | `@MainActor` na fachada `AppRedirect` | Estado mutável (singleton, dedup) confinado a um ator |
| Callbacks | Completion + async/await wrapper | Conveniência; ambos finalizam na main thread |
| Falha de rede | Silenciosa ao app + fila/retry | SDK nunca deve crashar o app; eventos não se perdem offline |
| Destino do clipboard | Validado server-side | Clipboard é spoofável; só o `clickId` é sinal, o backend dá o destino |
| `@objc` | Não (por ora) | Suporte Objective-C pode ser adicionado sob demanda |
| Decodificação de respostas | Tolerante (`decodeIfPresent` + defaults) | Drift de contrato não pode zerar atribuição |
| Testabilidade | Protocolos `Networking` + `Pasteboard` injetáveis | Orquestração testada sem rede real nem prompt de colar do iOS |

## Convenções de código

- Código em inglês
- `public` apenas nas declarações de surface: `AppRedirect.swift`, `DeepLinkResult.swift`, `AppRedirectConfig.swift`
- Tudo mais é `internal` (default Swift)
- Sem comentários explicando o que o código faz — apenas o *porquê* quando não óbvio
- Testes usam o framework `Testing` (Swift 6)
