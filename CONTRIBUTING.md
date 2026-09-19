# Contributing to Quantro

Thank you for contributing to Quantro. This document outlines the development workflow, coding standards, and submission guidelines.

## Code of Conduct

All contributors are expected to uphold a professional, welcoming, and collaborative environment. Be respectful, constructive, and focused on building secure, high-quality software.

## Development Workflow

1. Fork the repository and clone your fork locally:
   ```bash
   git clone https://github.com/<your-username>/money_manager.git
   cd money_manager
   ```
2. Create a feature branch with a descriptive name:
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bugfix-name
   ```
3. Set up your development environment:
   - For Flutter: Flutter SDK >= 3.24.0, Dart SDK >= 3.5.0
   - For Web App: Node.js >= 18.0.0, npm >= 9.0.0
4. Make your modifications following our code style.
5. Verify all tests pass locally before committing.
6. Commit with clear, conventional messages (`feat: ...`, `fix: ...`, `docs: ...`, `test: ...`).
7. Push to your fork and submit a Pull Request targeting `main`.

## Coding Standards

### Dart & Flutter
- Adhere to effective Dart guidelines and rules defined in `analysis_options.yaml`.
- Use self-documenting naming conventions. Do not append data types to variable names.
- Prefer `const` constructors wherever possible.
- Avoid deprecated methods (for example, use `.withValues(alpha: ...)` instead of `.withOpacity(...)`).
- Properly guard async gaps with `context.mounted` when using `BuildContext`.
- Keep widgets modular, focused, and decoupled from state storage.

### Web Client (`web_app/`)
- Write standard ES modules without heavy external framework bloat.
- Keep CSS organized, modular, and scoped to components or pages.
- Handle edge cases, errors, and empty states explicitly in DOM rendering.

### General Guidelines
- Zero emojis in source code, comments, commit messages, or pull requests.
- Self-documenting code over line-by-line narration. Write comments only to explain complex business logic, cryptographic edge cases, or non-obvious workarounds.

## Verification & Testing

Before submitting your changes, run the following verification steps:

### Flutter Checks
```bash
# Run unit and widget tests
flutter test

# Run static analysis
flutter analyze

# Verify code formatting
dart format --output=none --set-exit-if-changed .
```

### Web Client Checks
```bash
cd web_app

# Install dependencies if needed
npm install

# Run tests
npm test

# Verify production build
npm run build
```

## Pull Request Guidelines

- Provide a concise description of what the PR addresses and why.
- Link any related issue numbers (e.g., `Closes #12`).
- Ensure CI checks pass on GitHub Actions.
- Keep pull requests focused on a single change or cohesive feature. Avoid bundling unrelated refactors into a single PR.
