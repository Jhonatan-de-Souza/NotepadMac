# NotepadMac

A small native macOS notepad with tabs and automatic session recovery. Built with Swift and AppKit.

Um bloco de notas nativo para macOS, com abas e recuperação automática da sessão. Feito com Swift e AppKit.

[English](#english) · [Português](#português)

## English

### Screenshots

**Light theme**

![NotepadMac in light mode, showing three tabs and a sample welcome note](docs/screenshots/light.png)

**Dark theme**

![NotepadMac in dark mode, showing three tabs and a sample welcome note](docs/screenshots/dark.png)

Screenshots use sample notes rendered by the app; no personal notes are included.

### Features

- Plain text editing in multiple tabs.
- Automatic recovery of open notes, tab order, and the selected tab after closing or quitting.
- Explicit file saving with Command+S. New notes open a save dialog; existing files save to their current location. Use Save As to choose a different location.
- Empty tabs close immediately. Closing a tab with unsaved text asks whether to save or discard it.
- Tabs sit flush together; the close button appears on hover and stays visible on the selected tab.
- Light and dark themes under **View → Theme**.
- Word wrap, adjustable font size, undo/redo, and find within a note.

Closing the window with its red button, or quitting with Command+Q, preserves all open notes without asking you to save each one. Closing an individual tab removes it from the session. Closing the last tab leaves a fresh empty note.

### Build and install

Requirements: macOS 11 or later, Xcode Command Line Tools, and Python 3 for the development scripts that run tests or capture screenshots. The build targets the current Mac's architecture.

From the project directory:

```sh
./install.sh
```

This builds the app, installs or updates `/Applications/NotepadMac.app`, registers it with macOS, and requests Spotlight indexing. If the installed app is running, the script asks it to quit normally before updating.

Press **Command+Space**, type **Notepad**, and select **NotepadMac**. Spotlight may need a moment to refresh after installation. You can also open it directly:

```sh
open /Applications/NotepadMac.app
```

For future source changes, run `./install.sh` again to update the installed copy. To build without installing:

```sh
./build.sh
open build/NotepadMac.app
```

### Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| Command+T / Command+N | New tab |
| Command+O | Open files |
| Command+S | Save the current note |
| Command+Shift+S | Save As |
| Command+W / Control+W | Close the current tab |
| Command+1–9 | Select tab 1–9 |
| Command+0 | Select the last tab, even with more than ten tabs |
| Command+F | Find in the current note |
| Command++ / Command+- | Increase / decrease font size |
| Command+Q | Quit and preserve the session |

### Where notes are stored

Recovery data stays on your Mac at:

```text
~/Library/Application Support/NotepadMac/session.json
```

The session contains the open notes' text and file paths. Recovery does not overwrite your saved files. Use Command+S to write changes to a file you choose. Deleting the recovery folder removes the recoverable session; include it in your backups if you rely on unsaved notes.

### Development

```sh
Tests/session-tests.sh
```

Runs checks for empty-tab closing, numbered tab selection, session restoration, and protection of saved files, using temporary data separate from your notes.

To regenerate the example screenshots from the current AppKit views:

```sh
docs/capture-screenshots.sh
```

## Português

### Capturas de tela

As imagens acima mostram o app nos temas [claro](docs/screenshots/light.png) e [escuro](docs/screenshots/dark.png). Elas usam notas de exemplo renderizadas pelo próprio app, sem conteúdo pessoal.

### Recursos

- Edição de texto simples em várias abas.
- Recuperação automática das notas abertas, da ordem das abas e da aba selecionada após fechar ou sair do app.
- Salvamento de arquivos com Command+S. Notas novas abrem uma janela para escolher o destino; arquivos existentes são salvos no mesmo local. Use **Save As** para escolher outro destino.
- Abas vazias fecham imediatamente. Ao fechar uma aba com texto não salvo, o app pergunta se você quer salvar ou descartar as alterações.
- Abas sem espaçamento entre si; o botão de fechar aparece ao passar o mouse e fica visível na aba selecionada.
- Temas claro e escuro em **View → Theme**.
- Quebra automática de linha, ajuste do tamanho da fonte, desfazer/refazer e busca na nota.

Fechar a janela pelo botão vermelho ou sair com Command+Q preserva todas as notas abertas, sem pedir para salvar cada uma. Fechar uma aba individual remove essa nota da sessão. Ao fechar a última aba, uma nota vazia é criada.

### Compilar e instalar

Requisitos: macOS 11 ou posterior, ferramentas de linha de comando do Xcode e Python 3 para os scripts de desenvolvimento que executam testes ou capturam imagens. A compilação usa a arquitetura do Mac atual.

No diretório do projeto, execute:

```sh
./install.sh
```

O script compila o app, instala ou atualiza `/Applications/NotepadMac.app`, registra o app no macOS e solicita a indexação pelo Spotlight. Se a versão instalada estiver aberta, o script solicita o encerramento normal antes de atualizar.

Pressione **Command+Espaço**, digite **Notepad** e selecione **NotepadMac**. O Spotlight pode levar alguns instantes para atualizar após a instalação. Você também pode abrir o app diretamente:

```sh
open /Applications/NotepadMac.app
```

Depois de alterar o código, execute `./install.sh` novamente para atualizar a cópia instalada. Para compilar sem instalar:

```sh
./build.sh
open build/NotepadMac.app
```

### Atalhos de teclado

| Atalho | Ação |
| --- | --- |
| Command+T / Command+N | Nova aba |
| Command+O | Abrir arquivos |
| Command+S | Salvar a nota atual |
| Command+Shift+S | Salvar como |
| Command+W / Control+W | Fechar a aba atual |
| Command+1–9 | Selecionar a aba de 1 a 9 |
| Command+0 | Selecionar a última aba, mesmo com mais de dez abas |
| Command+F | Buscar na nota atual |
| Command++ / Command+- | Aumentar / diminuir o tamanho da fonte |
| Command+Q | Sair e preservar a sessão |

### Onde as notas ficam armazenadas

Os dados de recuperação ficam no seu Mac, em:

```text
~/Library/Application Support/NotepadMac/session.json
```

A sessão contém o texto das notas abertas e os caminhos dos arquivos. A recuperação não sobrescreve os arquivos que você salvou. Use Command+S para gravar as alterações em um arquivo no local escolhido. Excluir a pasta de recuperação apaga a sessão recuperável; inclua essa pasta nos seus backups se você depende de notas ainda não salvas em arquivos.

### Desenvolvimento

```sh
Tests/session-tests.sh
```

Verifica o fechamento de abas vazias, a seleção de abas por número, a restauração da sessão e a proteção dos arquivos salvos. Os testes usam dados temporários separados das suas notas.

Para gerar novamente as capturas de exemplo a partir das telas atuais do AppKit:

```sh
docs/capture-screenshots.sh
```
