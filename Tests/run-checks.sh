#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
mkdir -p .checks/cache
SDK=$(xcrun --show-sdk-path)
compile() { swiftc -sdk "$SDK" -module-cache-path "$PWD/.checks/cache" "$@"; }
compile Sources/AIContract.swift Tests/ContractChecks.swift -o .checks/contract
.checks/contract
compile Sources/AIContract.swift Sources/DependencyInstaller.swift Sources/CodeBuddyClient.swift Tests/ProcessChecks.swift -o .checks/process
.checks/process
compile Sources/AIContract.swift Sources/DependencyInstaller.swift Sources/CodeBuddyClient.swift Tests/SetupChecks.swift -o .checks/setup
.checks/setup
compile Sources/AIContract.swift Sources/AppSettings.swift Sources/SelectionReader.swift Tests/WorkflowChecks.swift -framework AppKit -framework ApplicationServices -o .checks/workflow
.checks/workflow
compile Sources/AIContract.swift Sources/AppSettings.swift Sources/Theme.swift Sources/ResultPanel.swift Tests/UIRenderingChecks.swift -framework AppKit -o .checks/ui
.checks/ui "$PWD/.checks/screens"
compile Sources/AIContract.swift Sources/DependencyInstaller.swift Sources/CodeBuddyClient.swift Sources/HotKeyManager.swift Sources/ScreenOCR.swift Tests/InputChecks.swift -framework AppKit -framework Carbon -framework Vision -o .checks/input
.checks/input
if [ "${1:-}" = "--live" ]; then
    compile Sources/AIContract.swift Sources/DependencyInstaller.swift Sources/CodeBuddyClient.swift Sources/Translator.swift Tests/AIIntegrationChecks.swift -framework Translation -framework NaturalLanguage -o .checks/integration
    .checks/integration
    compile Sources/AIContract.swift Sources/DependencyInstaller.swift Sources/CodeBuddyClient.swift Sources/Translator.swift Tests/TranslationMeaningChecks.swift -framework Translation -framework NaturalLanguage -o .checks/meaning
    .checks/meaning
fi
