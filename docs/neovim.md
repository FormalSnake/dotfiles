# Neovim Configuration User Guide

This Neovim configuration provides a modern IDE-like experience optimized for speed and productivity. It includes enhanced LSP support, intelligent completion, advanced syntax highlighting, and powerful navigation tools.

## Overview

The configuration is optimized for:
- **Fast LSP integration** with multiple language servers
- **Intelligent completion** with AI assistance (Supermaven)
- **Advanced syntax highlighting** and code navigation (Treesitter)
- **IDE-like features** while maintaining Neovim's speed
- **Modern keybindings** following Neovim conventions

## Essential Keybindings

### File Navigation (Snacks.nvim)
- `<leader>ff` - Find files in current directory
- `<leader>fw` - Live grep search in files
- `<leader>/` - Search current buffer lines
- `<leader>e` - Toggle file explorer

### LSP Navigation
- `gd` - Go to definition
- `gD` - Go to declaration  
- `gr` - Find all references
- `gi` - Go to implementation
- `K` - Show hover documentation
- `<C-k>` - Show signature help
- `<leader>D` - Go to type definition

### LSP Actions
- `<leader>la` - Show code actions
- `<leader>lA` - Show range code actions
- `<leader>lr` - Rename symbol across project
- `<leader>lf` - Format current buffer
- `<leader>ls` - Show signature help

### Diagnostics & Errors (Trouble.nvim)
- `<leader>xx` - Toggle diagnostics panel
- `<leader>xX` - Toggle buffer diagnostics only
- `<leader>cs` - Show document symbols
- `<leader>cl` - Show LSP definitions/references
- `[d` - Go to previous diagnostic
- `]d` - Go to next diagnostic

### Code Completion (CMP)
- `<Tab>` - Next completion item / Jump to next snippet placeholder
- `<S-Tab>` - Previous completion item / Jump to previous placeholder
- `<CR>` - Accept completion / Expand snippet
- `<C-Space>` - Trigger completion manually
- `<C-e>` - Close completion menu
- `<C-b>/<C-f>` - Scroll documentation up/down

### Smart Selection (Treesitter)
- `<C-Space>` - Start/expand incremental selection
- `<BS>` - Shrink selection

### Text Objects (Treesitter)
- `af/if` - Around/inside function
- `ac/ic` - Around/inside class
- `aa/ia` - Around/inside parameter

### Function/Class Navigation
- `]m` - Next function start
- `[m` - Previous function start
- `]]` - Next class start
- `[[` - Previous class start

### Terminal & Utilities
- `<leader>t` - Toggle terminal
- `<Ctrl-_>` - Toggle terminal (alternative)
- `<leader>z` - Enter zen mode (distraction-free)
- `<leader>.` - Open scratch buffer
- `<leader>bd` - Delete current buffer

### Git Integration (Snacks.nvim)
- `<leader>gg` - Open Lazygit
- `<leader>gb` - Git blame current line
- `<leader>gB` - Browse file in GitHub/GitLab
- `<leader>gf` - File history in Lazygit
- `<leader>gl` - Git log

### General Navigation
- `<leader>h` - Clear search highlighting
- `]]` - Next reference (word under cursor)
- `[[` - Previous reference (word under cursor)

### Clipboard Management
- `<leader>y` - Copy to system clipboard (normal/visual mode)
- `<leader>Y` - Copy whole line to system clipboard
- `<leader>p` - Paste from system clipboard
- `<leader>P` - Paste from system clipboard before cursor
- `y`, `p`, `d` - Use vim's internal clipboard (separate from system)

## Language Support

### Supported Languages
| Language | LSP Server | Features |
|----------|------------|----------|
| **Lua** | lua_ls | Full completion, diagnostics, Neovim integration |
| **Nix** | nil_ls | Syntax, completion, formatting |
| **TypeScript/JavaScript** | ts_ls | Inlay hints, completion, refactoring |
| **Astro** | astro | Framework-specific features |
| **HTML** | html | Tag completion, validation |
| **CSS** | cssls | Property completion, validation |
| **JSON** | jsonls | Schema validation, completion |

### AI Completion (Supermaven)
- **Highest priority** completion source
- **Context-aware** suggestions
- **Multi-line** completions
- **Automatic** trigger based on context

## Advanced Features

### Inlay Hints (TypeScript/JavaScript)
- **Parameter names** shown inline
- **Type information** for variables
- **Return types** for functions
- **Enum values** displayed

### Ghost Text
- **Preview completions** as you type
- **Non-intrusive** gray text
- **Real-time updates** with context

### Document Highlighting
- **Automatic highlighting** of symbol under cursor
- **References highlighted** throughout document
- **Updates on cursor movement**

### Smart Diagnostics
- **Rounded borders** for better visibility
- **Source information** when multiple LSPs
- **Severity sorting** for prioritization
- **Custom icons** for different error types

## Treesitter Features

### Syntax Highlighting
- **Accurate highlighting** for all supported languages
- **Incremental parsing** for performance
- **Context-aware** color schemes

### Code Folding
- **Treesitter-based** folding expressions
- **Smart folding** of functions and classes
- **Visual fold indicators**

### Language Parsers
- Nix, Lua, TypeScript, JavaScript, Astro
- HTML, CSS, JSON, Markdown, YAML
- Bash, Python, Vim script

## Performance Optimizations

### CMP Performance
- **60ms debouncing** for smooth typing
- **30ms throttling** for responsiveness
- **Limited items** per completion source
- **Async processing** with budget management

### LSP Optimizations
- **Enhanced capabilities** for better completion
- **Document highlighting** only on cursor hold
- **Lazy loading** of language servers
- **Efficient diagnostic updates**

### Editor Performance
- **250ms update time** for real-time feedback
- **No swap files** for better performance
- **300 column limit** for syntax highlighting
- **Optimized undo** with 10,000 levels

## Workflow Examples

### Daily Development
1. **Open project**: `<leader>ff` to find files
2. **Navigate code**: `gd` to go to definitions, `gr` for references
3. **Edit efficiently**: Use text objects (`af`, `if`) for quick selections
4. **Copy/paste**: `<leader>y` to copy to system clipboard, `y` for vim clipboard
5. **Check errors**: `<leader>xx` to see all diagnostics
6. **Format code**: `<leader>lf` before committing

### Debugging Issues
1. **Check diagnostics**: `<leader>xx` for overview
2. **Navigate errors**: `]d` and `[d` to jump between issues
3. **Get help**: `K` for documentation, `<leader>la` for code actions
4. **Rename symbols**: `<leader>lr` for safe refactoring

### File Management
1. **Find files**: `<leader>ff` for fuzzy finding
2. **Search content**: `<leader>fw` for project-wide search
3. **Browse structure**: `<leader>e` for file explorer
4. **Quick buffers**: `<leader>bd` to close, `<leader>.` for scratch

## Troubleshooting

### LSP Not Working
1. Check `:LspInfo` for server status
2. Verify language server is installed in Nix config
3. Check `:messages` for error logs
4. Try restarting Neovim

### Completions Missing
1. Ensure LSP server is running (`:LspInfo`)
2. Try manual trigger with `<C-Space>`
3. Check filetype is supported
4. Verify CMP sources in configuration

### Performance Issues
1. Check syntax highlighting limit (`:set synmaxcol?`)
2. Disable unused language servers
3. Reduce completion item limits
4. Check for conflicting plugins

## Customization

The configuration is modular and stored in:
- `modules/home-manager/programs/neovim/default.nix` - Plugin management
- `modules/home-manager/programs/neovim/options.lua` - Editor settings
- `modules/home-manager/programs/neovim/plugins/` - Individual plugin configs

### Adding Languages
1. Add language server to `extraPackages` in `default.nix`
2. Configure server in `plugins/lsp.lua`
3. Add Treesitter parser to parser list
4. Rebuild Nix configuration

### Modifying Keybindings
- **LSP keys**: Edit `plugins/lsp.lua` and `options.lua`
- **Completion**: Edit `plugins/cmp.lua`
- **General navigation**: Edit `options.lua`

This configuration provides a powerful, fast, and modern editing experience while maintaining Neovim's philosophy of efficiency and extensibility.