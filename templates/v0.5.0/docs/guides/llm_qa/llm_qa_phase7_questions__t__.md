# Phase 7: User Interface Questions

## Overview

**Phase:** 7 (User Interface)  
**When:** When designing frontend/UI  
**Duration:** 15-20 minutes  
**Questions:** 6 total  
**Outcome:** UI architecture and approach defined

**Before starting:** Read `llm_qa_principles__t__.md` to understand Q&A methodology.

**Note:** This phase is optional and can be skipped for CLI-only or API-only projects.

## Topics Covered

- Frontend framework selection
- Component architecture
- State management
- Accessibility
- Responsive design
- UI performance

## Question Templates

### Question 1: Frontend Framework (Required if building a UI)

**Context:** Framework choice affects development speed, performance, and maintainability.

```
What frontend framework will you use?

Options:
- **React**: Most popular, large ecosystem, component-based
- **Vue**: Progressive, easier learning curve, flexible
- **Svelte**: Compiled, no virtual DOM, fast and small
- **Angular**: Full-featured, opinionated, TypeScript-first
- **Vanilla JS**: No framework, maximum control, more work
- **Server-side**: HTMX, Hotwire, server-rendered HTML

For React/Vue/Svelte, will you use a meta-framework?
- **Next.js** (React): SSR, routing, API routes
- **Nuxt** (Vue): SSR, routing, modules
- **SvelteKit** (Svelte): SSR, routing, adapters

Example: "React with Next.js for SSR and routing"

Frontend framework: ___________
```

**Fills:** `docs/specs/implementation_options_spec.md` (Frameworks section), `docs/specs/codebase_spec.md` (Components section)

---

### Question 2: Component Architecture (Required if building a UI)

**Context:** Component organization affects code reusability and maintainability.

```
How will you organize your UI components?

Component strategy:
- **Component library**: Use existing library (Material-UI, Chakra, shadcn/ui, Ant Design)
- **Design system**: Build custom design system
- **Atomic design**: Atoms, molecules, organisms, templates, pages
- **Feature-based**: Components organized by feature

Component types:
- **Presentational**: Pure UI components (buttons, cards, inputs)
- **Container**: Components with logic and state
- **Layout**: Page layouts and structure
- **Page**: Top-level route components

Example: "Use shadcn/ui for base components, organize by feature, separate presentational and container components"

Component architecture: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Components section), `docs/specs/codebase_spec.md` (Components section)

---

### Question 3: State Management (Required if building a UI)

**Context:** State management affects data flow and component communication.

```
How will you manage application state?

State management options:
- **Local state**: Component state only (useState, Vue reactive)
- **Context API**: React Context for shared state
- **Redux/Zustand**: Global state management (React)
- **Pinia**: State management for Vue
- **Svelte stores**: Built-in state management
- **TanStack Query**: Server state management (React Query, Vue Query)

State categories:
- **UI state**: Modal open, selected tab, form inputs
- **Server state**: Data from API (use React Query/SWR)
- **Global state**: User session, theme, language

Example: "Local state for UI, TanStack Query for server state, Zustand for global state (user, theme)"

State management: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Components section)

---

### Question 4: Accessibility (Required for production/secure)

**Context:** Accessibility ensures your app is usable by everyone, including people with disabilities.

```
How will you ensure your UI is accessible?

Accessibility requirements:
- **WCAG level**: A (minimum), AA (recommended), AAA (highest)
- **Keyboard navigation**: All interactive elements keyboard-accessible
- **Screen readers**: Semantic HTML, ARIA labels, alt text
- **Color contrast**: Sufficient contrast ratios (4.5:1 for text)
- **Focus indicators**: Visible focus states
- **Testing**: Automated (axe, Lighthouse) and manual testing

Example: "Target WCAG 2.1 AA, keyboard navigation for all features, semantic HTML, test with axe-core and manual screen reader testing"

Accessibility: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Interfaces section)

---

### Question 5: Responsive Design (Required for production/secure)

**Context:** Responsive design ensures your app works on all device sizes.

```
How will you handle different screen sizes?

Responsive strategy:
- **Mobile-first**: Design for mobile, enhance for desktop
- **Desktop-first**: Design for desktop, adapt for mobile
- **Adaptive**: Different layouts for different devices

Breakpoints:
- **Mobile**: < 640px
- **Tablet**: 640px - 1024px
- **Desktop**: > 1024px

Tools:
- **CSS**: Media queries, flexbox, grid
- **Framework**: Tailwind CSS, Bootstrap, custom CSS
- **Testing**: Browser DevTools, real devices, BrowserStack

Example: "Mobile-first approach, Tailwind CSS for responsive utilities, test on mobile/tablet/desktop"

Responsive design: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Interfaces section)

---

### Question 6: UI Performance (Required for production/secure)

**Context:** UI performance affects user experience and SEO.

```
How will you optimize UI performance?

Performance strategies:
- **Code splitting**: Load code on demand (React.lazy, dynamic imports)
- **Lazy loading**: Load images and components as needed
- **Bundle optimization**: Tree shaking, minification, compression
- **Caching**: Service workers, HTTP caching
- **Image optimization**: WebP, responsive images, lazy loading
- **Metrics**: Core Web Vitals (LCP, FID, CLS)

Tools:
- **Bundler**: Vite, Webpack, Turbopack
- **Optimization**: Next.js Image, Partytown (3rd party scripts)
- **Monitoring**: Lighthouse, WebPageTest, Real User Monitoring

Example: "Vite for fast builds, code splitting by route, lazy load images, optimize with Next.js Image, monitor Core Web Vitals"

UI performance: ___________
```

**Fills:** `docs/specs/technical_design_spec.md` (Performance & Scalability section)

---

## Summary: What Gets Filled Out

After Phase 7 Q&A, the following spec sections should be populated:

### `docs/specs/codebase_spec.md`
- Components (frontend components, framework, paths)

### `docs/specs/technical_design_spec.md`
- Components (component architecture, state management)
- Interfaces (UI design, accessibility, responsive design)
- Performance & Scalability (UI performance optimization)

### `docs/specs/implementation_options_spec.md`
- Frameworks (frontend framework selection)

## Next Steps

After completing Phase 7 Q&A:

1. **Review UI architecture with developer** - Confirm framework and approach
2. **Proceed to other feature-specific phases** (optional):
   - Phase 8: API Design (read `llm_qa_phase8_questions__t__.md`)
   - Phase 9: Background Jobs (read `llm_qa_phase9_questions__t__.md`)
   - Phase 10: Analytics & Observability (read `llm_qa_phase10_questions__t__.md`)
3. **Or implement UI** - Set up frontend framework, component library, state management

**Note:** Phase 7 is optional and can be skipped for CLI-only or API-only projects. It can be done at any point when you need to design your user interface.
