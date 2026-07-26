// Curriculum source of truth for the multi-track study planner.
// Each track -> modules -> topics. A topic has estHours + typed reference links.
// Seeded into the DB by scripts/gen-tracks-seed.mjs. Links are official docs
// / well-known free resources. Edit here, regenerate, re-seed.

const R = (kind, title, url) => ({ kind, title, url });

export const tracks = [
  // =====================================================================
  // FRONTEND
  // =====================================================================
  {
    slug: 'frontend',
    title: 'Frontend Developer',
    subtitle: 'HTML, CSS, JavaScript → React & TypeScript',
    description:
      'Become a job-ready frontend engineer: semantic HTML, modern CSS, JavaScript, TypeScript, React, tooling, testing, and performance.',
    icon: '🎨',
    color: '#0ea5e9',
    difficulty: 'Beginner → Advanced',
    sortOrder: 1,
    modules: [
      {
        slug: 'internet-web',
        title: 'How the Web Works',
        goal: 'Understand the browser, HTTP, and how pages are delivered.',
        topics: [
          { slug: 'how-web-works', title: 'How the internet & browsers work', estHours: 2,
            description: 'Clients, servers, DNS, the request/response cycle, and how a browser renders a page.',
            resources: [ R('article','MDN: How the web works','https://developer.mozilla.org/en-US/docs/Learn/Getting_started_with_the_web/How_the_Web_works'), R('article','MDN: What is HTTP','https://developer.mozilla.org/en-US/docs/Web/HTTP/Overview') ] },
          { slug: 'dev-setup', title: 'Editor, terminal & Git basics', estHours: 3,
            description: 'Set up VS Code, the command line, and Git/GitHub for version control.',
            resources: [ R('doc','Git documentation','https://git-scm.com/doc'), R('course','freeCodeCamp: Git & GitHub','https://www.freecodecamp.org/news/git-and-github-for-beginners/') ] },
        ],
      },
      {
        slug: 'html-css',
        title: 'HTML & CSS',
        goal: 'Build accessible, responsive page structure and styling.',
        topics: [
          { slug: 'semantic-html', title: 'Semantic HTML & forms', estHours: 4,
            description: 'Document structure, semantic elements, forms, and accessibility basics.',
            resources: [ R('doc','MDN: HTML','https://developer.mozilla.org/en-US/docs/Web/HTML'), R('article','MDN: HTML forms','https://developer.mozilla.org/en-US/docs/Learn/Forms') ] },
          { slug: 'css-fundamentals', title: 'CSS fundamentals & the box model', estHours: 4,
            description: 'Selectors, specificity, the box model, units, and colors.',
            resources: [ R('doc','MDN: CSS','https://developer.mozilla.org/en-US/docs/Web/CSS'), R('course','web.dev: Learn CSS','https://web.dev/learn/css') ] },
          { slug: 'flexbox-grid', title: 'Flexbox & Grid layout', estHours: 5,
            description: 'Modern layout with Flexbox and CSS Grid; responsive design with media queries.',
            resources: [ R('article','CSS-Tricks: A Guide to Flexbox','https://css-tricks.com/snippets/css/a-guide-to-flexbox/'), R('article','CSS-Tricks: A Guide to Grid','https://css-tricks.com/snippets/css/complete-guide-grid/') ] },
          { slug: 'responsive', title: 'Responsive & accessible design', estHours: 4,
            description: 'Mobile-first design, media queries, and accessibility (a11y) fundamentals.',
            resources: [ R('course','web.dev: Learn Responsive Design','https://web.dev/learn/design'), R('doc','MDN: Accessibility','https://developer.mozilla.org/en-US/docs/Web/Accessibility') ] },
        ],
      },
      {
        slug: 'javascript',
        title: 'JavaScript',
        goal: 'Master the language that powers the web.',
        topics: [
          { slug: 'js-basics', title: 'JS fundamentals', estHours: 6,
            description: 'Variables, types, operators, control flow, and functions.',
            resources: [ R('course','javascript.info: The Modern JavaScript Tutorial','https://javascript.info/'), R('doc','MDN: JavaScript Guide','https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide') ] },
          { slug: 'dom', title: 'The DOM & events', estHours: 4,
            description: 'Select and manipulate elements, handle events, and update the page.',
            resources: [ R('doc','MDN: Document Object Model','https://developer.mozilla.org/en-US/docs/Web/API/Document_Object_Model'), R('article','MDN: Introduction to events','https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Building_blocks/Events') ] },
          { slug: 'async-js', title: 'Async JS, promises & fetch', estHours: 5,
            description: 'Callbacks, promises, async/await, and calling APIs with fetch.',
            resources: [ R('article','MDN: Asynchronous JavaScript','https://developer.mozilla.org/en-US/docs/Learn/JavaScript/Asynchronous'), R('doc','MDN: Using the Fetch API','https://developer.mozilla.org/en-US/docs/Web/API/Fetch_API/Using_Fetch') ] },
          { slug: 'es-modules', title: 'Modules, tooling & npm', estHours: 3,
            description: 'ES modules, package management with npm, and bundling with Vite.',
            resources: [ R('doc','MDN: JavaScript modules','https://developer.mozilla.org/en-US/docs/Web/JavaScript/Guide/Modules'), R('doc','Vite Guide','https://vitejs.dev/guide/') ] },
        ],
      },
      {
        slug: 'typescript',
        title: 'TypeScript',
        goal: 'Add static types for safer, larger apps.',
        topics: [
          { slug: 'ts-basics', title: 'TypeScript fundamentals', estHours: 5,
            description: 'Types, interfaces, generics, and typing functions and objects.',
            resources: [ R('doc','TypeScript Handbook','https://www.typescriptlang.org/docs/handbook/intro.html'), R('practice','TypeScript Playground','https://www.typescriptlang.org/play') ] },
        ],
      },
      {
        slug: 'react',
        title: 'React',
        goal: 'Build component-based UIs with React and TypeScript.',
        topics: [
          { slug: 'react-basics', title: 'Components, JSX & props', estHours: 5,
            description: 'Thinking in components, JSX, props, and rendering lists.',
            resources: [ R('doc','react.dev: Learn React','https://react.dev/learn'), R('doc','react.dev: Describing the UI','https://react.dev/learn/describing-the-ui') ] },
          { slug: 'react-state', title: 'State & hooks', estHours: 6,
            description: 'useState, useEffect, controlled inputs, and the rules of hooks.',
            resources: [ R('doc','react.dev: State','https://react.dev/learn/state-a-components-memory'), R('doc','react.dev: Reference for Hooks','https://react.dev/reference/react/hooks') ] },
          { slug: 'react-data', title: 'Data fetching & routing', estHours: 5,
            description: 'Fetch data, manage loading/error states, and add client-side routing.',
            resources: [ R('doc','react.dev: Synchronizing with Effects','https://react.dev/learn/synchronizing-with-effects'), R('doc','React Router','https://reactrouter.com/en/main/start/tutorial') ] },
          { slug: 'react-testing', title: 'Testing & performance', estHours: 4,
            description: 'Test components with Testing Library and optimize render performance.',
            resources: [ R('doc','Testing Library docs','https://testing-library.com/docs/'), R('doc','react.dev: Render and Commit','https://react.dev/learn/render-and-commit') ] },
        ],
      },
    ],
  },

  // =====================================================================
  // BACKEND
  // =====================================================================
  {
    slug: 'backend',
    title: 'Backend Developer',
    subtitle: 'APIs, databases, auth, caching & queues',
    description:
      'Design and build production backends: HTTP & REST, Node.js/Express, SQL with PostgreSQL, authentication, caching with Redis, and containerized deploys.',
    icon: '🛠️',
    color: '#22c55e',
    difficulty: 'Beginner → Advanced',
    sortOrder: 2,
    modules: [
      {
        slug: 'foundations',
        title: 'Backend Foundations',
        goal: 'Understand HTTP, REST, and how servers work.',
        topics: [
          { slug: 'http-rest', title: 'HTTP & REST fundamentals', estHours: 3,
            description: 'HTTP methods, status codes, headers, and RESTful API design.',
            resources: [ R('doc','MDN: HTTP','https://developer.mozilla.org/en-US/docs/Web/HTTP'), R('article','MDN: REST glossary','https://developer.mozilla.org/en-US/docs/Glossary/REST') ] },
          { slug: 'cli-git', title: 'Command line & Git', estHours: 3,
            description: 'Work confidently in the terminal and version code with Git.',
            resources: [ R('doc','Git documentation','https://git-scm.com/doc'), R('doc','Ubuntu: The Linux command line','https://ubuntu.com/tutorials/command-line-for-beginners') ] },
        ],
      },
      {
        slug: 'node-express',
        title: 'Node.js & Express',
        goal: 'Build HTTP APIs with Node.js and Express.',
        topics: [
          { slug: 'node-basics', title: 'Node.js fundamentals', estHours: 5,
            description: 'The event loop, modules, npm, and the standard library.',
            resources: [ R('doc','Node.js: Learn','https://nodejs.org/en/learn/getting-started/introduction-to-nodejs'), R('doc','Node.js API docs','https://nodejs.org/docs/latest/api/') ] },
          { slug: 'express-api', title: 'Building REST APIs with Express', estHours: 6,
            description: 'Routing, middleware, request/response handling, and error handling.',
            resources: [ R('doc','Express: Getting started','https://expressjs.com/en/starter/installing.html'), R('doc','Express: Routing','https://expressjs.com/en/guide/routing.html') ] },
          { slug: 'validation', title: 'Validation & error handling', estHours: 3,
            description: 'Validate input, structure errors, and return correct status codes.',
            resources: [ R('doc','Express: Error handling','https://expressjs.com/en/guide/error-handling.html'), R('doc','Zod (schema validation)','https://zod.dev/') ] },
        ],
      },
      {
        slug: 'databases',
        title: 'Databases & SQL',
        goal: 'Model data and query it with PostgreSQL.',
        topics: [
          { slug: 'sql-basics', title: 'SQL & relational modeling', estHours: 6,
            description: 'Tables, keys, joins, constraints, and normalization.',
            resources: [ R('doc','PostgreSQL Tutorial','https://www.postgresqltutorial.com/'), R('doc','PostgreSQL documentation','https://www.postgresql.org/docs/current/') ] },
          { slug: 'indexes-tx', title: 'Indexes & transactions', estHours: 4,
            description: 'Speed up queries with indexes; group operations with transactions.',
            resources: [ R('doc','PostgreSQL: Indexes','https://www.postgresql.org/docs/current/indexes.html'), R('doc','PostgreSQL: Transactions','https://www.postgresql.org/docs/current/tutorial-transactions.html') ] },
          { slug: 'orm', title: 'ORMs & migrations', estHours: 4,
            description: 'Query from code with an ORM and version your schema with migrations.',
            resources: [ R('doc','Prisma: Getting started','https://www.prisma.io/docs/getting-started'), R('doc','node-postgres (pg)','https://node-postgres.com/') ] },
        ],
      },
      {
        slug: 'auth-security',
        title: 'Auth & Security',
        goal: 'Authenticate users and secure your API.',
        topics: [
          { slug: 'auth', title: 'Authentication & JWT', estHours: 5,
            description: 'Password hashing, sessions vs tokens, and JSON Web Tokens.',
            resources: [ R('article','JWT: Introduction','https://jwt.io/introduction'), R('doc','OWASP: Authentication Cheat Sheet','https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html') ] },
          { slug: 'security', title: 'API security basics', estHours: 3,
            description: 'Common vulnerabilities and how to defend against them.',
            resources: [ R('doc','OWASP Top 10','https://owasp.org/www-project-top-ten/'), R('doc','MDN: Web security','https://developer.mozilla.org/en-US/docs/Web/Security') ] },
        ],
      },
      {
        slug: 'scaling-deploy',
        title: 'Caching, Queues & Deploy',
        goal: 'Make the backend fast and shippable.',
        topics: [
          { slug: 'redis', title: 'Caching with Redis', estHours: 4,
            description: 'Cache expensive results, use TTLs, and rate-limit requests.',
            resources: [ R('doc','Redis documentation','https://redis.io/docs/latest/'), R('doc','Redis: Data types','https://redis.io/docs/latest/develop/data-types/') ] },
          { slug: 'docker-deploy', title: 'Containerize & deploy', estHours: 5,
            description: 'Package the app with Docker and deploy it.',
            resources: [ R('doc','Docker: Get started','https://docs.docker.com/get-started/'), R('doc','12-Factor App','https://12factor.net/') ] },
        ],
      },
    ],
  },

  // =====================================================================
  // DEVOPS
  // =====================================================================
  {
    slug: 'devops',
    title: 'DevOps Engineer',
    subtitle: 'Linux, Docker, Kubernetes, CI/CD & cloud',
    description:
      'Operate and ship software reliably: Linux and networking, Docker, Kubernetes, infrastructure as code, CI/CD pipelines, and observability.',
    icon: '⚙️',
    color: '#f59e0b',
    difficulty: 'Intermediate → Advanced',
    sortOrder: 3,
    modules: [
      {
        slug: 'linux-net',
        title: 'Linux & Networking',
        goal: 'Be fluent on the command line and understand networking.',
        topics: [
          { slug: 'linux', title: 'Linux command line', estHours: 5,
            description: 'Filesystem, permissions, processes, and shell scripting.',
            resources: [ R('course','Linux Journey','https://linuxjourney.com/'), R('doc','Ubuntu: Command line for beginners','https://ubuntu.com/tutorials/command-line-for-beginners') ] },
          { slug: 'networking', title: 'Networking basics', estHours: 3,
            description: 'IP, DNS, TCP/HTTP, ports, and load balancing.',
            resources: [ R('article','Cloudflare: What is DNS?','https://www.cloudflare.com/learning/dns/what-is-dns/'), R('doc','MDN: HTTP','https://developer.mozilla.org/en-US/docs/Web/HTTP') ] },
        ],
      },
      {
        slug: 'version-scm',
        title: 'Git & Automation',
        goal: 'Version control and scripting for automation.',
        topics: [
          { slug: 'git', title: 'Git & GitHub workflows', estHours: 3,
            description: 'Branching, pull requests, and collaboration workflows.',
            resources: [ R('doc','Git documentation','https://git-scm.com/doc'), R('doc','GitHub: Git guides','https://github.com/git-guides') ] },
          { slug: 'bash', title: 'Bash scripting', estHours: 3,
            description: 'Automate repetitive tasks with shell scripts.',
            resources: [ R('doc','GNU Bash manual','https://www.gnu.org/software/bash/manual/bash.html'), R('article','Bash scripting cheatsheet','https://devhints.io/bash') ] },
        ],
      },
      {
        slug: 'containers',
        title: 'Containers',
        goal: 'Package and run apps with Docker.',
        topics: [
          { slug: 'docker', title: 'Docker fundamentals', estHours: 5,
            description: 'Images, containers, Dockerfiles, volumes, and networking.',
            resources: [ R('doc','Docker: Get started','https://docs.docker.com/get-started/'), R('doc','Dockerfile reference','https://docs.docker.com/reference/dockerfile/') ] },
          { slug: 'compose', title: 'Docker Compose', estHours: 3,
            description: 'Define and run multi-container apps for local development.',
            resources: [ R('doc','Docker Compose overview','https://docs.docker.com/compose/') ] },
        ],
      },
      {
        slug: 'orchestration',
        title: 'Kubernetes',
        goal: 'Orchestrate containers at scale.',
        topics: [
          { slug: 'k8s-basics', title: 'Kubernetes basics', estHours: 6,
            description: 'Pods, Deployments, Services, and the control plane.',
            resources: [ R('doc','Kubernetes basics tutorial','https://kubernetes.io/docs/tutorials/kubernetes-basics/'), R('doc','Kubernetes concepts','https://kubernetes.io/docs/concepts/') ] },
          { slug: 'k8s-config', title: 'Config, secrets & scaling', estHours: 4,
            description: 'ConfigMaps, Secrets, health checks, and autoscaling.',
            resources: [ R('doc','Kubernetes: ConfigMaps','https://kubernetes.io/docs/concepts/configuration/configmap/'), R('doc','Kubernetes: HPA','https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/') ] },
        ],
      },
      {
        slug: 'cicd-iac-obs',
        title: 'CI/CD, IaC & Observability',
        goal: 'Automate delivery and observe production.',
        topics: [
          { slug: 'cicd', title: 'CI/CD with GitHub Actions', estHours: 4,
            description: 'Build, test, and deploy automatically on every push.',
            resources: [ R('doc','GitHub Actions documentation','https://docs.github.com/en/actions'), R('doc','GitHub Actions: Quickstart','https://docs.github.com/en/actions/quickstart') ] },
          { slug: 'iac', title: 'Infrastructure as Code (Terraform)', estHours: 5,
            description: 'Provision cloud infrastructure declaratively and reproducibly.',
            resources: [ R('doc','Terraform tutorials','https://developer.hashicorp.com/terraform/tutorials'), R('doc','Terraform documentation','https://developer.hashicorp.com/terraform/docs') ] },
          { slug: 'observability', title: 'Monitoring & observability', estHours: 4,
            description: 'Metrics, logs, and traces with Prometheus and Grafana.',
            resources: [ R('doc','Prometheus: Overview','https://prometheus.io/docs/introduction/overview/'), R('doc','Grafana documentation','https://grafana.com/docs/grafana/latest/') ] },
        ],
      },
    ],
  },

  // =====================================================================
  // AI ENGINEER
  // =====================================================================
  {
    slug: 'ai-engineer',
    title: 'AI Engineer',
    subtitle: 'Python, LLMs, RAG & agents',
    description:
      'Build AI-powered applications: Python foundations, working with LLMs and the Claude API, prompt engineering, retrieval-augmented generation, and agents.',
    icon: '🤖',
    color: '#8b5cf6',
    difficulty: 'Intermediate → Advanced',
    sortOrder: 4,
    modules: [
      {
        slug: 'python',
        title: 'Python for AI',
        goal: 'Get fluent in Python and the data stack.',
        topics: [
          { slug: 'python-basics', title: 'Python fundamentals', estHours: 6,
            description: 'Syntax, data structures, functions, and modules.',
            resources: [ R('doc','Python: The Python Tutorial','https://docs.python.org/3/tutorial/'), R('course','Real Python: Learning path','https://realpython.com/learning-paths/python-basics/') ] },
          { slug: 'numpy-pandas', title: 'NumPy & pandas', estHours: 5,
            description: 'Vectorized arrays with NumPy and tabular data with pandas.',
            resources: [ R('doc','NumPy: Absolute beginners','https://numpy.org/doc/stable/user/absolute_beginners.html'), R('doc','pandas: User guide','https://pandas.pydata.org/docs/user_guide/index.html') ] },
        ],
      },
      {
        slug: 'llm-foundations',
        title: 'LLM Foundations',
        goal: 'Understand LLMs and call them via the Claude API.',
        topics: [
          { slug: 'what-are-llms', title: 'How LLMs work', estHours: 3,
            description: 'Tokens, context windows, and what models can and cannot do.',
            resources: [ R('doc','Anthropic: Intro to Claude','https://docs.claude.com/en/docs/intro-to-claude'), R('article','Anthropic: Models overview','https://docs.claude.com/en/docs/about-claude/models') ] },
          { slug: 'claude-api', title: 'Calling the Claude API', estHours: 4,
            description: 'The Messages API, roles, streaming, and parameters.',
            resources: [ R('doc','Claude API: Get started','https://docs.claude.com/en/docs/get-started'), R('doc','Claude API: Messages','https://docs.claude.com/en/api/messages') ] },
        ],
      },
      {
        slug: 'prompting',
        title: 'Prompt Engineering',
        goal: 'Get reliable results from LLMs.',
        topics: [
          { slug: 'prompt-basics', title: 'Prompt engineering', estHours: 4,
            description: 'Clear instructions, examples, system prompts, and chain-of-thought.',
            resources: [ R('doc','Anthropic: Prompt engineering overview','https://docs.claude.com/en/docs/build-with-claude/prompt-engineering/overview'), R('practice','Anthropic prompting tutorial','https://github.com/anthropics/prompt-eng-interactive-tutorial') ] },
          { slug: 'structured-tools', title: 'Structured output & tool use', estHours: 4,
            description: 'Force JSON output and let the model call your tools.',
            resources: [ R('doc','Claude API: Tool use','https://docs.claude.com/en/docs/build-with-claude/tool-use'), R('doc','Claude API: Streaming','https://docs.claude.com/en/docs/build-with-claude/streaming') ] },
        ],
      },
      {
        slug: 'rag',
        title: 'RAG & Vector Search',
        goal: 'Ground LLMs in your own documents.',
        topics: [
          { slug: 'embeddings', title: 'Embeddings & vector search', estHours: 4,
            description: 'Represent meaning as vectors and search by similarity.',
            resources: [ R('doc','pgvector','https://github.com/pgvector/pgvector'), R('article','Anthropic: Embeddings','https://docs.claude.com/en/docs/build-with-claude/embeddings') ] },
          { slug: 'rag-pipeline', title: 'Building a RAG pipeline', estHours: 6,
            description: 'Chunk, embed, retrieve, and generate grounded answers with citations.',
            resources: [ R('doc','Anthropic: RAG guide','https://docs.claude.com/en/docs/build-with-claude/search-and-retrieval'), R('doc','FastAPI','https://fastapi.tiangolo.com/') ] },
        ],
      },
      {
        slug: 'agents',
        title: 'Agents',
        goal: 'Build multi-step, tool-using agents.',
        topics: [
          { slug: 'agent-basics', title: 'Agent loops & tools', estHours: 5,
            description: 'The reason-act-observe loop, tool schemas, and stopping conditions.',
            resources: [ R('doc','Anthropic: Building effective agents','https://www.anthropic.com/research/building-effective-agents'), R('doc','LangGraph','https://langchain-ai.github.io/langgraph/') ] },
          { slug: 'agent-eval', title: 'Evaluating & shipping agents', estHours: 4,
            description: 'Guardrails, cost control, evaluation, and deployment.',
            resources: [ R('doc','Anthropic: Reduce hallucinations','https://docs.claude.com/en/docs/test-and-evaluate/strengthen-guardrails/reduce-hallucinations'), R('doc','Anthropic: Define success criteria','https://docs.claude.com/en/docs/test-and-evaluate/define-success') ] },
        ],
      },
    ],
  },
];
