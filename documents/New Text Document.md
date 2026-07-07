<div>
<h2 class="sr-only">Demo of the Crux plugin installed inside Redmine, showing the administration screen and a project's Crux workspace, populated with sample data</h2>

<div style="border:0.5px solid var(--border); border-radius:12px; overflow:hidden;">

  <div style="display:flex; align-items:center; justify-content:space-between; background:var(--surface-1); padding:10px 16px; gap:16px; flex-wrap:wrap;">
    <div style="display:flex; align-items:center; gap:20px; flex-wrap:wrap;">
      <div style="display:flex; align-items:center; gap:8px;">
        <div style="width:22px; height:22px; border-radius:5px; background:var(--fill-accent); display:flex; align-items:center; justify-content:center; font-size:12px; font-weight:500; color:var(--on-accent);">R</div>
        <span style="font-size:14px; font-weight:500;">Redmine</span>
      </div>
      <div style="display:flex; gap:14px; font-size:13px;">
        <a href="#" data-scene="mypage" class="nav-link">My page</a>
        <a href="#" data-scene="project" class="nav-link">Projects</a>
        <a href="#" data-scene="admin" class="nav-link">Administration</a>
        <a href="#" data-scene="help" class="nav-link">Help</a>
      </div>
    </div>
    <div style="display:flex; align-items:center; gap:12px;">
      <input type="text" placeholder="Search" style="width:120px; height:28px; font-size:12px;">
      <span style="font-size:12px; color:var(--text-secondary);">M. Patidar</span>
    </div>
  </div>

  <div id="scene-admin" class="topscene">
    <div style="padding:10px 16px; font-size:12px; color:var(--text-secondary); border-top:0.5px solid var(--border); border-bottom:0.5px solid var(--border);">
      Home &rsaquo; Administration &rsaquo; Plugins &rsaquo; Crux
    </div>
    <div style="display:flex;">
      <div style="width:150px; flex-shrink:0; padding:14px 8px; border-right:0.5px solid var(--border); font-size:13px; display:flex; flex-direction:column; gap:2px;">
        <span style="padding:6px 8px; color:var(--text-secondary);">Users</span>
        <span style="padding:6px 8px; color:var(--text-secondary);">Groups</span>
        <span style="padding:6px 8px; color:var(--text-secondary);">Roles and permissions</span>
        <span style="padding:6px 8px; color:var(--text-secondary);">Trackers</span>
        <span style="padding:6px 8px; color:var(--text-secondary);">Custom fields</span>
        <span style="padding:6px 8px; color:var(--text-secondary);">Settings</span>
        <span style="padding:6px 8px; background:var(--surface-1); border-radius:var(--radius); font-weight:500;">Plugins</span>
        <span style="padding:6px 8px; color:var(--text-secondary);">Info</span>
      </div>
      <div style="flex:1; padding:16px; min-width:0;">
        <div style="display:flex; gap:6px; margin-bottom:14px; border-bottom:0.5px solid var(--border); padding-bottom:10px; flex-wrap:wrap;">
          <button class="tab-btn" data-group="admin" data-tab="dashboard">Dashboard</button>
          <button class="tab-btn" data-group="admin" data-tab="agents">Agents</button>
          <button class="tab-btn" data-group="admin" data-tab="providers">Providers</button>
          <button class="tab-btn" data-group="admin" data-tab="audit">Audit log</button>
          <button class="tab-btn" data-group="admin" data-tab="billing">Billing</button>
          <button class="tab-btn" data-group="admin" data-tab="settings">Settings</button>
        </div>

        <div id="admin-dashboard" class="p-admin">
          <div style="display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; margin-bottom:16px;">
            <div style="background:var(--surface-1); border-radius:var(--radius); padding:12px;"><p style="font-size:12px; color:var(--text-secondary); margin:0 0 4px;">Projects with Crux</p><p style="font-size:20px; font-weight:500; margin:0;">14</p></div>
            <div style="background:var(--surface-1); border-radius:var(--radius); padding:12px;"><p style="font-size:12px; color:var(--text-secondary); margin:0 0 4px;">AI runs (30d)</p><p style="font-size:20px; font-weight:500; margin:0;">1,842</p></div>
            <div style="background:var(--surface-1); border-radius:var(--radius); padding:12px;"><p style="font-size:12px; color:var(--text-secondary); margin:0 0 4px;">Outcomes (30d)</p><p style="font-size:20px; font-weight:500; margin:0;">241</p></div>
            <div style="background:var(--surface-1); border-radius:var(--radius); padding:12px;"><p style="font-size:12px; color:var(--text-secondary); margin:0 0 4px;">Est. spend</p><p style="font-size:20px; font-weight:500; margin:0;">$482</p></div>
          </div>
          <p style="font-size:12px; color:var(--text-secondary); margin:0 0 6px;">Top projects by AI activity</p>
          <table style="width:100%; font-size:13px; border-collapse:collapse; margin-bottom:16px;">
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px; color:var(--text-secondary);">Project</td><td style="padding:6px 4px; color:var(--text-secondary);">Runs</td><td style="padding:6px 4px; color:var(--text-secondary);">Outcomes</td><td style="padding:6px 4px; color:var(--text-secondary); text-align:right;">Tokens</td></tr>
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">CRM platform</td><td style="padding:6px 4px;">34</td><td style="padding:6px 4px;">19</td><td style="padding:6px 4px; text-align:right;">1.1M</td></tr>
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">Hospital mgmt system</td><td style="padding:6px 4px;">28</td><td style="padding:6px 4px;">15</td><td style="padding:6px 4px; text-align:right;">860K</td></tr>
            <tr><td style="padding:6px 4px;">Dictio (internal)</td><td style="padding:6px 4px;">24</td><td style="padding:6px 4px;">11</td><td style="padding:6px 4px; text-align:right;">520K</td></tr>
          </table>
          <p style="font-size:12px; color:var(--text-secondary); margin:0 0 6px;">Top agents by usage</p>
          <div style="display:flex; flex-direction:column; gap:6px; font-size:13px;">
            <div style="display:flex; justify-content:space-between;"><span>Planner</span><span style="color:var(--text-secondary);">38%</span></div>
            <div style="display:flex; justify-content:space-between;"><span>QA agent</span><span style="color:var(--text-secondary);">24%</span></div>
            <div style="display:flex; justify-content:space-between;"><span>Reporter</span><span style="color:var(--text-secondary);">19%</span></div>
            <div style="display:flex; justify-content:space-between;"><span>Documentation agent</span><span style="color:var(--text-secondary);">12%</span></div>
          </div>
        </div>

        <div id="admin-agents" class="p-admin">
          <div style="display:flex; flex-direction:column; gap:6px;">
            <div class="row-card"><div class="row-left"><i class="ti ti-route" aria-hidden="true"></i><div><p class="row-title">Planner</p><p class="row-sub">Claude Sonnet 4.6 &middot; roadmap and work breakdown</p></div></div><input type="checkbox" checked aria-label="Enable Planner globally"></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-file-description" aria-hidden="true"></i><div><p class="row-title">Requirement analyst</p><p class="row-sub">Claude Sonnet 4.6 &middot; specs from ideas</p></div></div><input type="checkbox" checked aria-label="Enable Requirement analyst globally"></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-code" aria-hidden="true"></i><div><p class="row-title">Developer</p><p class="row-sub">Claude Sonnet 4.6 &middot; implementation guidance</p></div></div><input type="checkbox" checked aria-label="Enable Developer globally"></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-bug" aria-hidden="true"></i><div><p class="row-title">QA agent</p><p class="row-sub">Claude Haiku 4.5 &middot; test cases and gaps</p></div></div><input type="checkbox" checked aria-label="Enable QA agent globally"></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-notebook" aria-hidden="true"></i><div><p class="row-title">Documentation agent</p><p class="row-sub">Claude Haiku 4.5 &middot; wiki and release notes</p></div></div><input type="checkbox" checked aria-label="Enable Documentation agent globally"></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-chart-bar" aria-hidden="true"></i><div><p class="row-title">Reporter</p><p class="row-sub">Claude Haiku 4.5 &middot; standups and status</p></div></div><input type="checkbox" checked aria-label="Enable Reporter globally"></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-server-2" aria-hidden="true"></i><div><p class="row-title">DevOps agent</p><p class="row-sub">Claude Sonnet 4.6 &middot; deploy and CI/CD guidance</p></div></div><input type="checkbox" aria-label="Enable DevOps agent globally"></div>
          </div>
        </div>

        <div id="admin-providers" class="p-admin">
          <div style="display:flex; flex-direction:column; gap:6px;">
            <div class="row-card"><div class="row-left"><i class="ti ti-brain" aria-hidden="true"></i><div><p class="row-title">Anthropic</p><p class="row-sub">Default provider</p></div></div><span class="badge-success">Connected</span></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-brain" aria-hidden="true"></i><div><p class="row-title">OpenAI</p><p class="row-sub">Fallback provider</p></div></div><span class="badge-success">Connected</span></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-brain" aria-hidden="true"></i><div><p class="row-title">Gemini</p><p class="row-sub">Not configured</p></div></div><button style="font-size:12px; padding:4px 10px;">Connect</button></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-brain" aria-hidden="true"></i><div><p class="row-title">Azure OpenAI</p><p class="row-sub">Not configured</p></div></div><button style="font-size:12px; padding:4px 10px;">Connect</button></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-cpu" aria-hidden="true"></i><div><p class="row-title">Ollama</p><p class="row-sub">Local models, not configured</p></div></div><button style="font-size:12px; padding:4px 10px;">Connect</button></div>
            <div class="row-card"><div class="row-left"><i class="ti ti-flask" aria-hidden="true"></i><div><p class="row-title">Mock provider</p><p class="row-sub">Testing only, no real calls</p></div></div><span class="badge-warning">Dev only</span></div>
          </div>
        </div>

        <div id="admin-audit" class="p-admin">
          <div style="display:flex; gap:8px; margin-bottom:10px; flex-wrap:wrap;">
            <select style="font-size:12px; height:28px;"><option>All projects</option></select>
            <select style="font-size:12px; height:28px;"><option>All agents</option></select>
            <select style="font-size:12px; height:28px;"><option>All statuses</option></select>
          </div>
          <table style="width:100%; font-size:12px; border-collapse:collapse; table-layout:fixed;">
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px; color:var(--text-secondary); width:16%;">User</td><td style="padding:6px 4px; color:var(--text-secondary); width:18%;">Agent</td><td style="padding:6px 4px; color:var(--text-secondary); width:36%;">Action</td><td style="padding:6px 4px; color:var(--text-secondary); width:16%;">Status</td><td style="padding:6px 4px; color:var(--text-secondary); width:14%; text-align:right;">Time</td></tr>
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">M. Patidar</td><td style="padding:6px 4px;">Planner</td><td style="padding:6px 4px;">Create 42 issues</td><td style="padding:6px 4px;"><span class="badge-success">Approved</span></td><td style="padding:6px 4px; text-align:right; color:var(--text-secondary);">2m ago</td></tr>
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">R. Shah</td><td style="padding:6px 4px;">QA agent</td><td style="padding:6px 4px;">Generate test suite</td><td style="padding:6px 4px;"><span class="badge-warning">Pending</span></td><td style="padding:6px 4px; text-align:right; color:var(--text-secondary);">14m ago</td></tr>
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">M. Patidar</td><td style="padding:6px 4px;">DevOps agent</td><td style="padding:6px 4px;">Delete milestone v0.9</td><td style="padding:6px 4px;"><span class="badge-danger">Rejected</span></td><td style="padding:6px 4px; text-align:right; color:var(--text-secondary);">1h ago</td></tr>
            <tr><td style="padding:6px 4px;">A. Verma</td><td style="padding:6px 4px;">Reporter</td><td style="padding:6px 4px;">Weekly status digest</td><td style="padding:6px 4px;"><span class="badge-success">Approved</span></td><td style="padding:6px 4px; text-align:right; color:var(--text-secondary);">3h ago</td></tr>
          </table>
        </div>

        <div id="admin-billing" class="p-admin">
          <div style="background:var(--surface-2); border:0.5px solid var(--border); border-radius:12px; padding:14px 16px; margin-bottom:14px;">
            <div style="display:flex; justify-content:space-between; align-items:baseline; margin-bottom:10px;"><p style="margin:0; font-size:14px; font-weight:500;">Team plan</p><p style="margin:0; font-size:14px; font-weight:500;">$199/mo</p></div>
            <p style="margin:0 0 6px; font-size:12px; color:var(--text-secondary);">Outcomes used this cycle</p>
            <div style="background:var(--surface-1); border-radius:var(--radius); height:8px; overflow:hidden; margin-bottom:4px;"><div style="background:var(--fill-accent); height:100%; width:72%;"></div></div>
            <p style="margin:0; font-size:12px; color:var(--text-muted);">72 of 100 included outcomes</p>
          </div>
          <p style="font-size:12px; color:var(--text-secondary); margin:0 0 6px;">Last 3 months</p>
          <table style="width:100%; font-size:13px; border-collapse:collapse;">
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px; color:var(--text-secondary);">Month</td><td style="padding:6px 4px; color:var(--text-secondary);">Outcomes</td><td style="padding:6px 4px; color:var(--text-secondary); text-align:right;">Billed</td></tr>
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">May 2026</td><td style="padding:6px 4px;">88</td><td style="padding:6px 4px; text-align:right;">$199</td></tr>
            <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">June 2026</td><td style="padding:6px 4px;">96</td><td style="padding:6px 4px; text-align:right;">$199</td></tr>
            <tr><td style="padding:6px 4px;">July 2026 (to date)</td><td style="padding:6px 4px;">72</td><td style="padding:6px 4px; text-align:right; color:var(--text-secondary);">in progress</td></tr>
          </table>
        </div>

        <div id="admin-settings" class="p-admin">
          <div style="display:flex; flex-direction:column; gap:12px; max-width:340px;">
            <label style="font-size:13px;">Default model<select style="width:100%; margin-top:4px;"><option>Claude Sonnet 4.6</option><option>Claude Haiku 4.5</option></select></label>
            <label style="font-size:13px;">Default approval policy<select style="width:100%; margin-top:4px;"><option>Require approval for all actions</option><option>Auto-approve reads, gate writes</option></select></label>
            <label style="font-size:13px;">Max runs per hour, per project<input type="number" value="60" style="width:100%; margin-top:4px;"></label>
            <label style="font-size:13px;">Audit log retention, days<input type="number" value="365" style="width:100%; margin-top:4px;"></label>
          </div>
        </div>
      </div>
    </div>
  </div>

  <div id="scene-project" class="topscene">
    <div style="padding:10px 16px; font-size:12px; color:var(--text-secondary); border-top:0.5px solid var(--border); border-bottom:0.5px solid var(--border);">
      Home &rsaquo; Projects &rsaquo; CRM platform &rsaquo; Crux
    </div>
    <div style="display:flex; gap:14px; padding:10px 16px; border-bottom:0.5px solid var(--border); font-size:13px; flex-wrap:wrap;">
      <span style="color:var(--text-secondary);">Overview</span>
      <span style="color:var(--text-secondary);">Activity</span>
      <span style="color:var(--text-secondary);">Roadmap</span>
      <span style="color:var(--text-secondary);">Issues</span>
      <span style="color:var(--text-secondary);">Wiki</span>
      <span style="color:var(--text-secondary);">Files</span>
      <span style="font-weight:500; border-bottom:2px solid var(--border-accent); padding-bottom:2px;">Crux</span>
      <span style="color:var(--text-secondary);">Settings</span>
    </div>
    <div style="padding:16px;">
      <div style="display:flex; gap:6px; margin-bottom:14px; border-bottom:0.5px solid var(--border); padding-bottom:10px; flex-wrap:wrap;">
        <button class="tab-btn" data-group="project" data-tab="overview">Overview</button>
        <button class="tab-btn" data-group="project" data-tab="chat">Chat</button>
        <button class="tab-btn" data-group="project" data-tab="agents">Agents</button>
        <button class="tab-btn" data-group="project" data-tab="runs">Runs</button>
        <button class="tab-btn" data-group="project" data-tab="knowledge">Knowledge</button>
        <button class="tab-btn" data-group="project" data-tab="automations">Automations</button>
        <button class="tab-btn" data-group="project" data-tab="settings">Settings</button>
      </div>

      <div id="project-overview" class="p-project">
        <div style="display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:10px; margin-bottom:16px;">
          <div style="background:var(--surface-1); border-radius:var(--radius); padding:12px;"><p style="font-size:12px; color:var(--text-secondary); margin:0 0 4px;">AI runs</p><p style="font-size:20px; font-weight:500; margin:0;">128</p></div>
          <div style="background:var(--surface-1); border-radius:var(--radius); padding:12px;"><p style="font-size:12px; color:var(--text-secondary); margin:0 0 4px;">Outcomes</p><p style="font-size:20px; font-weight:500; margin:0;">34</p></div>
          <div style="background:var(--surface-1); border-radius:var(--radius); padding:12px;"><p style="font-size:12px; color:var(--text-secondary); margin:0 0 4px;">Success rate</p><p style="font-size:20px; font-weight:500; margin:0;">91%</p></div>
          <div style="background:var(--surface-1); border-radius:var(--radius); padding:12px;"><p style="font-size:12px; color:var(--text-secondary); margin:0 0 4px;">Pending approvals</p><p style="font-size:20px; font-weight:500; margin:0;">2</p></div>
        </div>
        <p style="font-size:12px; color:var(--text-secondary); margin:0 0 8px;">Recent activity</p>
        <div style="display:flex; flex-direction:column; gap:8px; font-size:13px;">
          <div style="border-bottom:0.5px solid var(--border); padding-bottom:8px;">Planner created an execution plan for the CRM data model — approved by M. Patidar <span style="color:var(--text-muted); font-size:12px;">&middot; 2m ago</span></div>
          <div style="border-bottom:0.5px solid var(--border); padding-bottom:8px;">QA agent drafted a test suite for the Invoice module — awaiting approval <span style="color:var(--text-muted); font-size:12px;">&middot; 14m ago</span></div>
          <div style="padding-bottom:8px;">Reporter posted the weekly status digest <span style="color:var(--text-muted); font-size:12px;">&middot; 3h ago</span></div>
        </div>
      </div>

      <div id="project-chat" class="p-project">
        <div style="background:var(--surface-1); border-radius:12px; padding:14px 16px; margin-bottom:12px;">
          <p style="font-size:12px; color:var(--text-secondary); margin:0 0 8px;">Last conversation</p>
          <p style="font-size:13px; margin:0 0 6px;"><span style="color:var(--text-secondary);">You:</span> Create a CRM system with Customer, Leads, and Invoice modules.</p>
          <p style="font-size:13px; margin:0;"><span style="color:var(--text-secondary);">Requirement analyst:</span> Plan approved and executed — 42 issues created, wiki generated.</p>
        </div>
        <button style="font-size:13px; padding:6px 14px;">Open chat</button>
      </div>

      <div id="project-agents" class="p-project">
        <div style="display:flex; flex-direction:column; gap:6px;">
          <div class="row-card"><div class="row-left"><i class="ti ti-route" aria-hidden="true"></i><p class="row-title">Planner</p></div><input type="checkbox" checked aria-label="Enable Planner for this project"></div>
          <div class="row-card"><div class="row-left"><i class="ti ti-file-description" aria-hidden="true"></i><p class="row-title">Requirement analyst</p></div><input type="checkbox" checked aria-label="Enable Requirement analyst for this project"></div>
          <div class="row-card"><div class="row-left"><i class="ti ti-bug" aria-hidden="true"></i><p class="row-title">QA agent</p></div><input type="checkbox" checked aria-label="Enable QA agent for this project"></div>
          <div class="row-card"><div class="row-left"><i class="ti ti-notebook" aria-hidden="true"></i><p class="row-title">Documentation agent</p></div><input type="checkbox" aria-label="Enable Documentation agent for this project"></div>
        </div>
      </div>

      <div id="project-runs" class="p-project">
        <table style="width:100%; font-size:12px; border-collapse:collapse; table-layout:fixed;">
          <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px; color:var(--text-secondary); width:22%;">Agent</td><td style="padding:6px 4px; color:var(--text-secondary); width:26%;">Model</td><td style="padding:6px 4px; color:var(--text-secondary); width:16%;">Tokens</td><td style="padding:6px 4px; color:var(--text-secondary); width:14%;">Cost</td><td style="padding:6px 4px; color:var(--text-secondary); width:22%; text-align:right;">Status</td></tr>
          <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">Planner</td><td style="padding:6px 4px;">Sonnet 4.6</td><td style="padding:6px 4px;">18.2K</td><td style="padding:6px 4px;">$0.31</td><td style="padding:6px 4px; text-align:right;"><span class="badge-success">Completed</span></td></tr>
          <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">QA agent</td><td style="padding:6px 4px;">Haiku 4.5</td><td style="padding:6px 4px;">9.4K</td><td style="padding:6px 4px;">$0.08</td><td style="padding:6px 4px; text-align:right;"><span class="badge-warning">Pending</span></td></tr>
          <tr style="border-bottom:0.5px solid var(--border);"><td style="padding:6px 4px;">Reporter</td><td style="padding:6px 4px;">Haiku 4.5</td><td style="padding:6px 4px;">3.1K</td><td style="padding:6px 4px;">$0.03</td><td style="padding:6px 4px; text-align:right;"><span class="badge-success">Completed</span></td></tr>
          <tr><td style="padding:6px 4px;">Requirement analyst</td><td style="padding:6px 4px;">Sonnet 4.6</td><td style="padding:6px 4px;">22.7K</td><td style="padding:6px 4px;">$0.39</td><td style="padding:6px 4px; text-align:right;"><span class="badge-success">Completed</span></td></tr>
        </table>
      </div>

      <div id="project-knowledge" class="p-project">
        <p style="font-size:12px; color:var(--text-secondary); margin:0 0 6px;">Coverage score</p>
        <div style="background:var(--surface-1); border-radius:var(--radius); height:8px; overflow:hidden; margin-bottom:4px;"><div style="background:var(--fill-accent); height:100%; width:61%;"></div></div>
        <p style="margin:0 0 14px; font-size:12px; color:var(--text-muted);">Your agents can see 61% of this project's delivery work</p>
        <div style="display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:8px; font-size:13px;">
          <label style="display:flex; align-items:center; gap:8px;"><input type="checkbox" checked>Issues</label>
          <label style="display:flex; align-items:center; gap:8px;"><input type="checkbox" checked>Wiki</label>
          <label style="display:flex; align-items:center; gap:8px;"><input type="checkbox" checked>Documents</label>
          <label style="display:flex; align-items:center; gap:8px;"><input type="checkbox">Repository</label>
          <label style="display:flex; align-items:center; gap:8px;"><input type="checkbox">Files</label>
          <label style="display:flex; align-items:center; gap:8px;"><input type="checkbox">Time entries</label>
          <label style="display:flex; align-items:center; gap:8px;"><input type="checkbox">Helpdesk</label>
          <label style="display:flex; align-items:center; gap:8px;"><input type="checkbox">CRM</label>
        </div>
      </div>

      <div id="project-automations" class="p-project">
        <div style="display:flex; flex-direction:column; gap:6px;">
          <div class="row-card"><div><p class="row-title">Auto-draft release notes when a version closes</p><p class="row-sub">Documentation agent</p></div><input type="checkbox" checked aria-label="Enable release notes automation"></div>
          <div class="row-card"><div><p class="row-title">Auto-triage new issues into the backlog</p><p class="row-sub">Planner</p></div><input type="checkbox" checked aria-label="Enable auto-triage automation"></div>
          <div class="row-card"><div><p class="row-title">Weekly status digest to project members</p><p class="row-sub">Reporter, every Monday 9am</p></div><input type="checkbox" checked aria-label="Enable weekly digest automation"></div>
          <div class="row-card"><div><p class="row-title">Flag stale issues with no activity for 14 days</p><p class="row-sub">Reporter</p></div><input type="checkbox" aria-label="Enable stale issue automation"></div>
        </div>
      </div>

      <div id="project-settings" class="p-project">
        <p style="font-size:12px; color:var(--text-secondary); margin:0 0 8px;">Integrations</p>
        <div style="display:flex; flex-direction:column; gap:6px; margin-bottom:16px;">
          <div class="row-card"><div class="row-left"><i class="ti ti-brand-github" aria-hidden="true"></i><span style="font-size:13px;">GitHub repository</span></div><button style="font-size:12px; padding:4px 10px;">Connect</button></div>
          <div class="row-card"><div class="row-left"><i class="ti ti-brand-slack" aria-hidden="true"></i><span style="font-size:13px;">Slack channel</span></div><span class="badge-success">Connected</span></div>
          <div class="row-card"><div class="row-left"><i class="ti ti-brand-teams" aria-hidden="true"></i><span style="font-size:13px;">Microsoft Teams</span></div><button style="font-size:12px; padding:4px 10px;">Connect</button></div>
        </div>
        <p style="font-size:12px; color:var(--text-secondary); margin:0 0 8px;">Project defaults</p>
        <div style="display:flex; flex-direction:column; gap:10px; max-width:320px;">
          <label style="font-size:13px;">Default agent for new conversations<select style="width:100%; margin-top:4px;"><option>Requirement analyst</option><option>Planner</option></select></label>
          <label style="font-size:13px;">Approval policy<select style="width:100%; margin-top:4px;"><option>Require approval for all actions</option><option>Auto-approve reads, gate writes</option></select></label>
        </div>
      </div>
    </div>
  </div>

  <div id="scene-mypage" class="topscene" style="padding:24px 16px; font-size:13px; color:var(--text-secondary);">My page is unmodified by Crux — nothing to show here.</div>
  <div id="scene-help" class="topscene" style="padding:24px 16px; font-size:13px; color:var(--text-secondary);">Help is unmodified by Crux — nothing to show here.</div>
</div>

<p style="font-size:12px; color:var(--text-muted); margin-top:10px;">Click "Projects" or "Administration" above to switch views. Sub-tabs inside each are clickable too.</p>
</div>

<script>
(function(){
  var links = document.querySelectorAll('.nav-link');
  var scenes = document.querySelectorAll('.topscene');

  function showScene(name){
    scenes.forEach(function(s){ s.style.display = (s.id === 'scene-' + name) ? '' : 'none'; });
    links.forEach(function(l){
      var on = l.getAttribute('data-scene') === name;
      l.style.fontWeight = on ? '500' : '400';
      l.style.color = on ? 'var(--text-primary)' : 'var(--text-accent)';
    });
  }
  links.forEach(function(l){
    l.addEventListener('click', function(e){ e.preventDefault(); showScene(l.getAttribute('data-scene')); });
  });
  showScene('admin');

  function wireTabs(group, prefix, defaultTab){
    var btns = document.querySelectorAll('.tab-btn[data-group="' + group + '"]');
    var panels = document.querySelectorAll('.p-' + group);
    function showTab(tab){
      panels.forEach(function(p){ p.style.display = (p.id === prefix + '-' + tab) ? '' : 'none'; });
      btns.forEach(function(b){
        var on = b.getAttribute('data-tab') === tab;
        b.style.background = on ? 'var(--surface-1)' : '';
        b.style.borderColor = on ? 'var(--border-strong)' : '';
      });
    }
    btns.forEach(function(b){ b.addEventListener('click', function(){ showTab(b.getAttribute('data-tab')); }); });
    showTab(defaultTab);
  }
  wireTabs('admin', 'admin', 'dashboard');
  wireTabs('project', 'project', 'overview');
})();
</script>

<style>
.row-card{display:flex; align-items:center; justify-content:space-between; border:0.5px solid var(--border); border-radius:var(--radius); padding:8px 10px;}
.row-left{display:flex; align-items:center; gap:10px;}
.row-title{margin:0; font-size:13px; font-weight:500;}
.row-sub{margin:0; font-size:12px; color:var(--text-secondary);}
.badge-success{background:var(--bg-success); color:var(--text-success); font-size:12px; padding:2px 8px; border-radius:var(--radius);}
.badge-warning{background:var(--bg-warning); color:var(--text-warning); font-size:12px; padding:2px 8px; border-radius:var(--radius);}
.badge-danger{background:var(--bg-danger); color:var(--text-danger); font-size:12px; padding:2px 8px; border-radius:var(--radius);}
</style>
</div>