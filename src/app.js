const paths = [
  {
    id: 'builder',
    title: 'AI Product Builder',
    icon: '⌘',
    fit: 'You like turning ideas into demos, automations, and internal tools.',
    outcome: 'Ship 3 portfolio-grade AI apps with clear product metrics.',
    skills: ['Prompting systems', 'RAG basics', 'API integration', 'UX prototyping'],
    projects: ['Document Q&A assistant', 'Customer support triage bot', 'Workflow automation dashboard'],
  },
  {
    id: 'analyst',
    title: 'AI Data Analyst',
    icon: '↗',
    fit: 'You enjoy finding patterns, communicating insights, and improving decisions.',
    outcome: 'Build an AI-assisted analytics portfolio with executive-ready narratives.',
    skills: ['SQL + Python', 'Data storytelling', 'LLM-assisted analysis', 'Experiment design'],
    projects: ['Churn insight report', 'Revenue forecast notebook', 'Self-serve KPI explainer'],
  },
  {
    id: 'operator',
    title: 'AI Operations Strategist',
    icon: '▣',
    fit: 'You want to make teams faster by redesigning workflows around AI.',
    outcome: 'Create an AI operating playbook and implementation case study.',
    skills: ['Process mapping', 'Tool selection', 'Change management', 'ROI tracking'],
    projects: ['SOP automation kit', 'AI adoption scorecard', 'Department productivity pilot'],
  },
];

const checklist = [
  'Define target role and salary range',
  'Choose one core AI tool stack',
  'Build a public project every two weeks',
  'Write one case study with quantified impact',
  'Collect feedback from 5 industry practitioners',
  'Apply to 30 aligned roles with tailored proof',
];

let selectedPath = paths[0];
const completed = new Set([0, 1]);

function renderPaths() {
  document.getElementById('path-grid').innerHTML = paths.map((path) => `
    <button class="path-card ${selectedPath.id === path.id ? 'active' : ''}" data-path="${path.id}">
      <span class="path-icon">${path.icon}</span>
      <h3>${path.title}</h3>
      <p>${path.fit}</p>
    </button>
  `).join('');

  document.querySelectorAll('[data-path]').forEach((button) => {
    button.addEventListener('click', () => {
      selectedPath = paths.find((path) => path.id === button.dataset.path);
      renderPaths();
    });
  });

  document.getElementById('detail-panel').innerHTML = `
    <div>
      <h3>${selectedPath.title}</h3>
      <p>${selectedPath.outcome}</p>
    </div>
    <div class="pill-list">${selectedPath.skills.map((skill) => `<span>${skill}</span>`).join('')}</div>
    <ul>${selectedPath.projects.map((project) => `<li>✓ ${project}</li>`).join('')}</ul>
  `;
}

function renderChecklist() {
  document.getElementById('checklist-list').innerHTML = checklist.map((item, index) => `
    <button class="${completed.has(index) ? 'done' : ''}" data-check="${index}">✓ ${item}</button>
  `).join('');

  document.querySelectorAll('[data-check]').forEach((button) => {
    button.addEventListener('click', () => {
      const index = Number(button.dataset.check);
      completed.has(index) ? completed.delete(index) : completed.add(index);
      renderChecklist();
      updateProgress();
    });
  });
}

function updateProgress() {
  const progress = Math.round((completed.size / checklist.length) * 100);
  document.getElementById('progress-number').textContent = `${progress}%`;
  document.getElementById('progress-bar').style.width = `${progress}%`;
}

function saveChecklist() {
  const text = checklist.map((item, index) => `${completed.has(index) ? '[x]' : '[ ]'} ${item}`).join('\n');
  const blob = new Blob([`AI Career Upgrade Checklist\n\n${text}\n`], { type: 'text/plain' });
  const link = document.createElement('a');
  link.href = URL.createObjectURL(blob);
  link.download = 'ai-career-upgrade-checklist.txt';
  link.click();
  URL.revokeObjectURL(link.href);
}

document.getElementById('save-button').addEventListener('click', saveChecklist);
renderPaths();
renderChecklist();
updateProgress();
