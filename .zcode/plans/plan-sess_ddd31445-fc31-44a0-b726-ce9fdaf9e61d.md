## Context

Redesign the Flutter app UI (lib/) to match the web_app website's design language. Currently in **visual exploration phase**: launch the web app locally, screenshot every page (dashboard, budget, goals, net worth, insights, calendar, transactions, settings, auth, onboarding) in dark and light mode, then map those visuals onto the Flutter app's screens.

## What's known so far

**Website design system** (web_app/src/css/variables.css): "Pure Single-Tone Minimalist" — dark-first (#090A0C bg, #111215 surfaces, white primary accent, slate-gray secondaries #94A3B8/#64748B), light mode (#FFFFFF bg, #0F172A primary), Outfit headings + Plus Jakarta Sans body, subtle grid-line background, glass cards with 1px micro-borders and top-glow line, radius scale 6/8/12/18/24px, pill nav + KPI stat cards + segmented switches.

**Flutter app** (lib/): Riverpod + Navigator 1.0, 14 screens, currently orange "Naruto" glassmorphism theme in core/theme/app_theme.dart + core/presentation/glass_widgets.dart, floating glass bottom nav with 4 tabs + center FAB in core/navigation/app_shell.dart, fl_chart charts, ~25 hardcoded hex colors drifted outside the theme.

## Next steps (exploration, still no code changes)

1. Run `npm run dev` in web_app, screenshot all pages in both themes
2. Compare against Flutter screens; produce the task-breakdown plan document per the planning skill
3. Present plan for approval before any implementation